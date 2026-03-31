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

# gitian.sigs (local — push happens in CI)
[ -d $BHOME/gitian.sigs ] || git clone https://github.com/zcash/gitian.sigs.git $BHOME/gitian.sigs

mkdir -p $BHOME/zcash-binaries

echo "[6] Determining suites from gitian descriptor..."
GITIAN_DESC=$BHOME/zcash/contrib/gitian-descriptors/gitian-linux-parallel.yml
SUITES=$(python3 -c "
import yaml
with open('$GITIAN_DESC') as f:
    d = yaml.safe_load(f)
suites = d.get('suites', [d.get('suite', 'bullseye')])
print(' '.join(suites) if isinstance(suites, list) else suites)
" 2>/dev/null || echo "bullseye")
echo "Suites: $SUITES"

PROC=$(nproc)
MEM=$(free -m | awk 'FNR==2 { print int($2 * 0.85)}')
echo "Using $PROC cores, ${MEM}M RAM"

cd $BHOME/gitian-builder

echo "[7] Building suites: $SUITES"
for suite in $SUITES; do
    echo ""
    echo "=== Suite: $suite ==="

    suite_dir=$BHOME/gitian-builder/suites/${suite}
    mkdir -p $suite_dir
    cp $GITIAN_DESC $suite_dir/gitian-linux-parallel.yml

    # Pre-download Linux deps (macOS optional, failures are non-fatal)
    echo "Downloading Linux dependencies..."
    make -C $BHOME/zcash/depends download SOURCES_PATH=$BHOME/gitian-builder/cache/common 2>&1 | \
        grep -v "^make\[" | tail -5 || echo "Some downloads failed (macOS), continuing"

    # Build base LXC image if not present
    base_img=$BHOME/gitian-builder/base-${suite}-amd64
    if [ ! -f $base_img ]; then
        echo "Building base LXC image for $suite (~10 min)..."
        ./bin/make-base-vm --lxc --arch amd64 --distro debian --suite $suite
    else
        echo "Base image exists: $base_img"
    fi

    echo "Running gbuild for $suite (~60-90 min)..."
    if ! ./bin/gbuild --fetch-tags -j "$PROC" -m "$MEM" \
            --commit zcash="${TAG}" \
            --url zcash="https://github.com/${OWNER}/${REPO}" \
            "$suite_dir/gitian-linux-parallel.yml"; then
        echo "First attempt failed, retrying in 60s..."
        sleep 60
        ./bin/gbuild --fetch-tags -j "$PROC" -m "$MEM" \
            --commit zcash="${TAG}" \
            --url zcash="https://github.com/${OWNER}/${REPO}" \
            "$suite_dir/gitian-linux-parallel.yml"
    fi

    # Sign assert with ECC key (sysadmin directory — legacy zcash key)
    ./bin/gsign -p "gpg --batch --detach-sign" \
        --signer sysadmin \
        --release ${TAG#v}_${suite} \
        --destination $BHOME/gitian.sigs/ \
        $suite_dir/gitian-linux-parallel.yml

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
    mv $BHOME/gitian-builder/build/out/zcash-*.tar.gz \
       $suite_out/ 2>/dev/null || true
    mv $BHOME/gitian-builder/build/out/src/zcash-*.tar.gz \
       $suite_out/ 2>/dev/null || true
    echo "Suite $suite artifacts: $(ls $suite_out)"
done

echo "[8] Assert files:"
find $BHOME/gitian.sigs/${TAG#v}* -name "*.assert" 2>/dev/null | sort
head -8 $BHOME/gitian.sigs/${TAG#v}*/sysadmin/*.assert 2>/dev/null | head -30

echo "[9] Sign + upload tarballs..."
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

# Copy to downloads/ with CI naming convention (linux64 before debian-suite)
VERSION="${TAG#v}"
for suite in $(ls $BHOME/zcash-binaries/${VERSION}/); do
    for SUFFIX in "linux64.tar.gz" "linux64.tar.gz.asc" "linux64-debug.tar.gz" "linux64-debug.tar.gz.asc"; do
        SRC="s3://zodl-public-download/${VERSION}/${suite}/zcash-${VERSION}-${SUFFIX%-debian*}-debian-${suite}-${SUFFIX#*linux64}"
        # Reconstruct: zcash-VERSION-linux64-debian-SUITE.tar.gz
        NEWNAME="zcash-${VERSION}-linux64-debian-${suite}-$(echo $SUFFIX | sed 's/linux64[-.]*//')"
        DST="s3://zodl-public-download/downloads/$NEWNAME"
        aws s3 cp "s3://zodl-public-download/${VERSION}/${suite}/zcash-${VERSION}-debian-${suite}-${SUFFIX}" "$DST" 2>/dev/null || true
    done
done

echo "[10] Purge BunnyCDN..."
curl -s -X POST "https://api.bunny.net/pullzone/${BUNNY_ZONE}/purgeCache" \
    -H "content-type: application/json" -H "AccessKey: ${BUNNY_KEY}"

# Push gitian.sigs for non-RC releases only
if [[ "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[11] Pushing gitian.sigs..."
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
    echo "[11] Skipping gitian.sigs push (RC or pre-release tag: ${TAG})"
fi

echo ""
echo "=============================="
echo " BUILD COMPLETE: ${TAG}"
echo " Binaries: s3://zodl-public-download/${TAG#v}/"
echo " Sigs ECC:  sysadmin/      (B1C9...2CFE, sysadmin@z.cash)"
echo " Sigs ZODL: sysadmin-zodl/ (0338...6AB1, sysadmin@zodl.com)"
echo "=============================="
