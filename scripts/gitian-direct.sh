#!/bin/bash
# gitian-direct.sh — LXC-based gitian build for zcash
# Runs on EC2 (or any Linux host with LXC support). No QEMU/nested virtualization needed.
#
# Required env vars (injected by CI or set manually):
#   OWNER       — GitHub org/user (default: zcash)
#   REPO        — GitHub repo     (default: zcash)
#   TAG         — Git tag         (e.g. v6.13.0)
#   BUNNY_KEY   — BunnyCDN API key
#   BUNNY_ZONE  — BunnyCDN pull zone ID (e.g. 5435099)
#
# Credentials are pulled from AWS Secrets Manager via the instance IAM role.
# No AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY needed on EC2.
# zcash/zcash is public — no GH token needed for cloning.

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export HOME=/root
exec > >(tee /root/gitian-direct2.log) 2>&1
trap 'aws s3 cp /root/gitian-direct2.log "s3://zodl-public-download/gitian-debug/$(hostname)-$(date +%Y%m%dT%H%M%S).log" 2>/dev/null || true' EXIT

OWNER="${OWNER:-zcash}"
REPO="${REPO:-zcash}"
: "${TAG:?TAG is required}"
: "${BUNNY_KEY:?BUNNY_KEY is required}"
: "${BUNNY_ZONE:?BUNNY_ZONE is required}"

export AWS_DEFAULT_REGION="us-east-1"

# LXC env vars (run as root)
export USE_LXC=1
export LXC_BRIDGE=lxcbr0
export GITIAN_HOST_IP=10.0.3.1
export LXC_GUEST_IP=10.0.3.5
export MIRROR_HOST=10.0.3.1
export DISTRO=debian
export ARCH=amd64

# GPG fingerprints
GPG_ECC_FPR="B1C9095EAA1848DBB54D9DDA1D05FDC66B372CFE"   # sysadmin@z.cash (ECC key)
GPG_ZODL_FPR="033834DD49DECF9DBB9934BC6C93CA8E58E26AB1"  # sysadmin@zodl.com (ZODL key)

echo "[0] Installing dependencies..."
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  lxc debootstrap bridge-utils apt-cacher-ng python3-cheetah qemu-utils kpartx \
  git python3-yaml curl unzip make ruby 2>&1 | tail -5

# Install AWS CLI v2 (not in Debian repos; install from official binary)
if ! command -v aws &>/dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
  rm -rf /tmp/awscliv2.zip /tmp/aws
fi
aws --version

echo "[1] LXC network..."
ip addr show lxcbr0 2>/dev/null && echo "lxcbr0 already up" || {
    service lxc-net start 2>/dev/null || systemctl start lxc-net || true
    sleep 2
}
ip addr show lxcbr0

echo "[2] Kernel settings..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w kernel.unprivileged_userns_clone=1 || true

echo "[3] GPG keys from Secrets Manager..."
aws secretsmanager get-secret-value \
    --secret-id /release/gpg-signing-key-zcash \
    --query SecretString --output text > /tmp/ecc-private.pgp
aws secretsmanager get-secret-value \
    --secret-id /release/gpg-signing-key \
    --query SecretString --output text > /tmp/zodl-private.pgp
gpg --batch --import /tmp/ecc-private.pgp
gpg --batch --import /tmp/zodl-private.pgp
rm -f /tmp/ecc-private.pgp /tmp/zodl-private.pgp

gpg --list-secret-keys sysadmin@z.cash
gpg --list-secret-keys sysadmin@zodl.com

git config --global user.name "sysadmin"
git config --global user.email "sysadmin@zodl.com"

echo "[4] Setting up repos in /root..."
BHOME=/root/build
mkdir -p $BHOME

# gitian-builder
[ -d $BHOME/gitian-builder ] || git clone https://github.com/devrandom/gitian-builder.git $BHOME/gitian-builder

# zcash source
if [ -d $BHOME/zcash ]; then
    cd $BHOME/zcash && git fetch && git checkout ${TAG}
else
    git clone "https://github.com/${OWNER}/${REPO}.git" --branch ${TAG} $BHOME/zcash
fi

# BDB pthread_yield fix for bookworm (glibc 2.34+ removed unversioned symbol).
# Two-part fix:
# 1. Add sed to preprocess_cmds to replace pthread_yield→sched_yield in source
# 2. Create a dummy patch file that changes the package hash, forcing BDB rebuild
#    (gbuild cache keys on tarball hash + patches list, ignores preprocess_cmds)
echo "[4.5] Patching BDB for pthread_yield fix..."
BDB_MK=$BHOME/zcash/depends/packages/bdb.mk
BDB_PATCH_DIR=$BHOME/zcash/depends/patches/bdb

if ! grep -q "sched_yield" "$BDB_MK"; then
    # Add sed to preprocess_cmds (does the actual fix)
    sed -i '/winioctl-and-atomic_init_db.patch/s/$/ \&\& \\\n  sed -i "s\/pthread_yield()\/sched_yield()\/" src\/os\/os_yield.c/' "$BDB_MK"

    # Add a no-op patch file to invalidate the cache hash
    echo "--- /dev/null" > "$BDB_PATCH_DIR/pthread_yield_fix.patch"
    echo "+++ /dev/null" >> "$BDB_PATCH_DIR/pthread_yield_fix.patch"
    sed -i 's/\($(package)_patches=.*\)/\1 pthread_yield_fix.patch/' "$BDB_MK"

    echo "  Applied: preprocess sed + cache-invalidating patch"
    grep -A5 "preprocess_cmds" "$BDB_MK"
fi

# gitian.sigs (local — push happens in CI)
[ -d $BHOME/gitian.sigs ] || git clone https://github.com/zcash/gitian.sigs.git $BHOME/gitian.sigs

mkdir -p $BHOME/zcash-binaries

GITIAN_DESC=$BHOME/zcash/contrib/gitian-descriptors/gitian-linux-parallel.yml

echo "[5] Determining suites from gitian descriptor..."
SUITES=$(python3 -c "
import yaml
with open('$GITIAN_DESC') as f:
    d = yaml.safe_load(f)
suites = d.get('suites', [d.get('suite', 'bullseye')])
print(' '.join(suites) if isinstance(suites, list) else suites)
" 2>/dev/null || echo "bullseye")

# Force bullseye before bookworm
if echo "$SUITES" | grep -q "bullseye" && echo "$SUITES" | grep -q "bookworm"; then
    SUITES="bullseye bookworm"
    echo "Suite order forced: bullseye first (GLIBC/ABI compatibility)"
fi

# Multi-suite descriptor with cache enabled.
# bullseye builds BDB + cxxbridge, cache carries them to bookworm.
# The March 28 build proved this works — BDB's pthread_yield is resolved
# by GNU ld (used in configure) even on bookworm. lld only fails when
# BDB is recompiled fresh inside a bookworm-only container.
echo "[5.5] Patching descriptor: bullseye first, cache enabled..."
python3 -c "
import yaml
with open('$GITIAN_DESC') as f:
    d = yaml.safe_load(f)
d['suites'] = '$SUITES'.split()
d['enable_cache'] = True
with open('$GITIAN_DESC', 'w') as f:
    yaml.dump(d, f, default_flow_style=False, sort_keys=False)
print('Descriptor: suites=%s, cache=%s' % (d['suites'], d['enable_cache']))
"

PROC=$(nproc)
MEM=$(free -m | awk 'FNR==2 { print int($2 * 0.85)}')
echo "Using $PROC cores, ${MEM}M RAM"

cd $BHOME/gitian-builder

echo "[6] Downloading dependencies..."
make -C $BHOME/zcash/depends download SOURCES_PATH=$BHOME/gitian-builder/cache/common 2>&1 | \
    grep -v "^make\[" | tail -5 || echo "Some downloads failed (macOS), continuing"

echo "[7] Building base LXC images..."
for suite in $SUITES; do
    base_img=$BHOME/gitian-builder/base-${suite}-amd64
    if [ ! -f $base_img ]; then
        echo "Building base LXC image for $suite (~10 min)..."
        ./bin/make-base-vm --lxc --arch amd64 --distro debian --suite $suite
    else
        echo "Base image exists: $base_img"
    fi
done

echo "[8] Running gbuild (multi-suite, cache enabled, bullseye first)..."
if ! ./bin/gbuild --fetch-tags -j "$PROC" -m "$MEM" \
        --commit zcash="${TAG}" \
        --url zcash="https://github.com/${OWNER}/${REPO}" \
        "$GITIAN_DESC"; then
    echo "Build failed"
    echo "=== var/build.log (last 100 lines) ==="
    tail -100 $BHOME/gitian-builder/var/build.log 2>/dev/null || echo "(no build.log)"
    echo "=== end var/build.log ==="
    exit 1
fi

echo "[8.5] Signing per suite..."
for suite in $SUITES; do
    echo ""
    echo "=== Signing: $suite ==="

    # Sign assert with ECC key (sysadmin directory — legacy zcash key)
    ./bin/gsign -p "gpg --batch --detach-sign" \
        --signer sysadmin \
        --release ${TAG#v}_${suite} \
        --destination $BHOME/gitian.sigs/ \
        "$GITIAN_DESC"

    # Re-sign the same assert with ZODL key (sysadmin-zodl directory)
    ASSERT_SRC="$BHOME/gitian.sigs/${TAG#v}_${suite}/sysadmin"
    ASSERT_DST="$BHOME/gitian.sigs/${TAG#v}_${suite}/sysadmin-zodl"
    mkdir -p "$ASSERT_DST"
    ASSERT_FILE=$(ls "$ASSERT_SRC"/*.assert 2>/dev/null | head -1)
    if [ -n "$ASSERT_FILE" ]; then
        ASSERT_NAME=$(basename "$ASSERT_FILE")
        cp "$ASSERT_FILE" "$ASSERT_DST/$ASSERT_NAME"
        gpg --batch --no-tty -u sysadmin@zodl.com \
            --detach-sign \
            --output "$ASSERT_DST/${ASSERT_NAME}.sig" \
            "$ASSERT_DST/$ASSERT_NAME"
        echo "  ZODL sig: $ASSERT_DST/${ASSERT_NAME}.sig"
    fi

    suite_out=$BHOME/zcash-binaries/${TAG#v}/${suite}
    mkdir -p $suite_out
    cp $BHOME/gitian-builder/build/out/zcash-*.tar.gz \
       $suite_out/ 2>/dev/null || true
    cp $BHOME/gitian-builder/build/out/src/zcash-*.tar.gz \
       $suite_out/ 2>/dev/null || true
    echo "Suite $suite artifacts: $(ls $suite_out 2>/dev/null || echo '(none)')"
done

echo "[9] Assert files:"
find $BHOME/gitian.sigs/${TAG#v}* -name "*.assert" 2>/dev/null | sort
head -8 $BHOME/gitian.sigs/${TAG#v}*/sysadmin/*.assert 2>/dev/null | head -30

echo "[10] Sign + upload tarballs..."
for suite in $(ls $BHOME/zcash-binaries/${TAG#v}/); do
    cd $BHOME/zcash-binaries/${TAG#v}/$suite
    # Rename: zcash-VERSION-linux64.tar.gz → zcash-VERSION-linux64-debian-SUITE.tar.gz
    for j in $(ls *linux64.tar.gz 2>/dev/null); do
        mv "$j" "$(echo $j | sed "s/\.tar\.gz/-debian-${suite}.tar.gz/")"
    done
    for j in $(ls *debug.tar.gz 2>/dev/null); do
        mv "$j" "$(echo $j | sed "s/\.tar\.gz/-debian-${suite}.tar.gz/")"
    done
    # Sign with both keys
    for f in *.tar.gz; do
        gpg -u sysadmin@z.cash   --batch --armor --digest-algo SHA256 --detach-sign "$f"
        echo "  ECC signed: $f"
    done
    aws s3 sync ./ "s3://zodl-public-download/${TAG#v}/$suite/" --no-progress
    echo "  -> s3://zodl-public-download/${TAG#v}/$suite/"
done

# Copy to downloads/ with expected naming: zcash-VERSION-linux64-debian-SUITE.tar.gz
VERSION="${TAG#v}"
for suite in $(ls $BHOME/zcash-binaries/${VERSION}/); do
    cd $BHOME/zcash-binaries/${VERSION}/${suite}
    for f in *.tar.gz *.tar.gz.asc; do
        [ -f "$f" ] || continue
        aws s3 cp "$f" "s3://zodl-public-download/downloads/$f" --no-progress 2>/dev/null || true
    done
done

echo "[11] Purge BunnyCDN..."
curl -s -X POST "https://api.bunny.net/pullzone/${BUNNY_ZONE}/purgeCache" \
    -H "content-type: application/json" -H "AccessKey: ${BUNNY_KEY}"

# Push gitian.sigs for non-RC releases only
if [[ "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[12] Pushing gitian.sigs..."
    GH_TOKEN=$(aws secretsmanager get-secret-value \
        --secret-id /infra/gitian/gitian_sigs_deploy_key \
        --query SecretString --output text)

    git clone "https://x-access-token:${GH_TOKEN}@github.com/zcash/gitian.sigs.git" /root/build/gitian.sigs-push
    cp -a $BHOME/gitian.sigs/. /root/build/gitian.sigs-push/
    cd /root/build/gitian.sigs-push
    git config user.name  "sysadmin"
    git config user.email "sysadmin@zodl.com"
    git add .
    git diff --cached --stat
    git commit -m "${TAG}" || echo "Nothing to commit"
    git push
    unset GH_TOKEN
    echo "gitian.sigs pushed for ${TAG}"
else
    echo "[12] Skipping gitian.sigs push (RC or pre-release tag: ${TAG})"
fi

echo ""
echo "=============================="
echo " BUILD COMPLETE: ${TAG}"
echo " Binaries: s3://zodl-public-download/${TAG#v}/"
echo " Sigs ECC:  sysadmin/      (B1C9...2CFE, sysadmin@z.cash)"
echo " Sigs ZODL: sysadmin-zodl/ (0338...6AB1, sysadmin@zodl.com)"
echo "=============================="
