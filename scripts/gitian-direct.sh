#!/bin/bash
# gitian-direct.sh — LXC-based gitian build for zcash (single suite)
#
# Required env vars:
#   OWNER       — GitHub org/user (default: zcash)
#   REPO        — GitHub repo     (default: zcash)
#   TAG         — Git tag         (e.g. v6.13.0)
#   SUITE       — Debian suite    (e.g. bullseye or bookworm)
#   BUNNY_KEY   — BunnyCDN API key
#   BUNNY_ZONE  — BunnyCDN pull zone ID

set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export HOME=/root
exec > >(tee /root/gitian-direct2.log) 2>&1
trap 'aws s3 cp /root/gitian-direct2.log "s3://zodl-public-download/gitian-debug/$(hostname)-$(date +%Y%m%dT%H%M%S).log" 2>/dev/null || true' EXIT

OWNER="${OWNER:-zcash}"
REPO="${REPO:-zcash}"
: "${TAG:?TAG is required}"
: "${SUITE:?SUITE is required (bullseye or bookworm)}"
: "${BUNNY_KEY:?BUNNY_KEY is required}"
: "${BUNNY_ZONE:?BUNNY_ZONE is required}"

export AWS_DEFAULT_REGION="us-east-1"

export USE_LXC=1
export LXC_BRIDGE=lxcbr0
export GITIAN_HOST_IP=10.0.3.1
export LXC_GUEST_IP=10.0.3.5
export MIRROR_HOST=10.0.3.1
export DISTRO=debian
export ARCH=amd64

echo "=== Gitian build: ${TAG} / ${SUITE} ==="

echo "[0] Installing dependencies..."
apt-get update -q
DEBIAN_FRONTEND=noninteractive apt-get install -y -q \
  lxc debootstrap bridge-utils apt-cacher-ng python3-cheetah qemu-utils kpartx \
  git python3-yaml curl unzip make ruby 2>&1 | tail -5

if ! command -v aws &>/dev/null; then
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q /tmp/awscliv2.zip -d /tmp
  /tmp/aws/install --update
  rm -rf /tmp/awscliv2.zip /tmp/aws
fi

echo "[1] LXC network..."
ip addr show lxcbr0 2>/dev/null && echo "lxcbr0 already up" || {
    service lxc-net start 2>/dev/null || systemctl start lxc-net || true
    sleep 2
}

echo "[2] Kernel settings..."
sysctl -w net.ipv4.ip_forward=1
sysctl -w kernel.unprivileged_userns_clone=1 || true

echo "[3] GPG keys..."
aws secretsmanager get-secret-value --secret-id /release/gpg-signing-key-zcash \
    --query SecretString --output text | gpg --batch --import
aws secretsmanager get-secret-value --secret-id /release/gpg-signing-key \
    --query SecretString --output text | gpg --batch --import

git config --global user.name "sysadmin"
git config --global user.email "sysadmin@zodl.com"

echo "[4] Setting up repos..."
BHOME=/root/build
mkdir -p $BHOME

[ -d $BHOME/gitian-builder ] || git clone https://github.com/devrandom/gitian-builder.git $BHOME/gitian-builder

if [ -d $BHOME/zcash ]; then
    cd $BHOME/zcash && git fetch && git checkout ${TAG}
else
    git clone "https://github.com/${OWNER}/${REPO}.git" --branch ${TAG} $BHOME/zcash
fi

# BDB pthread_yield fix: glibc 2.34+ removed the unversioned symbol.
# Add sed to preprocess_cmds + dummy patch to invalidate depends cache.
echo "[4.5] Patching BDB for pthread_yield fix..."
BDB_MK=$BHOME/zcash/depends/packages/bdb.mk
BDB_PATCH_DIR=$BHOME/zcash/depends/patches/bdb
if ! grep -q "sched_yield" "$BDB_MK"; then
    sed -i '/winioctl-and-atomic_init_db.patch/s/$/ \&\& \\\n  sed -i "s\/pthread_yield()\/sched_yield()\/" src\/os\/os_yield.c/' "$BDB_MK"
    echo "--- /dev/null" > "$BDB_PATCH_DIR/pthread_yield_fix.patch"
    echo "+++ /dev/null" >> "$BDB_PATCH_DIR/pthread_yield_fix.patch"
    sed -i 's/\($(package)_patches=.*\)/\1 pthread_yield_fix.patch/' "$BDB_MK"
    echo "  Applied BDB pthread_yield fix"
fi

[ -d $BHOME/gitian.sigs ] || git clone https://github.com/zcash/gitian.sigs.git $BHOME/gitian.sigs
mkdir -p $BHOME/zcash-binaries

GITIAN_DESC=$BHOME/zcash/contrib/gitian-descriptors/gitian-linux-parallel.yml

# Create single-suite descriptor with cache disabled
echo "[5] Creating descriptor for ${SUITE}..."
python3 -c "
import yaml
with open('$GITIAN_DESC') as f:
    d = yaml.safe_load(f)
d['suites'] = ['$SUITE']
d['enable_cache'] = False
with open('$GITIAN_DESC', 'w') as f:
    yaml.dump(d, f, default_flow_style=False, sort_keys=False)
print('Suite: $SUITE, cache: disabled')
"

PROC=$(nproc)
MEM=$(free -m | awk 'FNR==2 { print int($2 * 0.85)}')
echo "Using $PROC cores, ${MEM}M RAM"

cd $BHOME/gitian-builder

echo "[6] Downloading dependencies..."
make -C $BHOME/zcash/depends download SOURCES_PATH=$BHOME/gitian-builder/cache/common 2>&1 | \
    grep -v "^make\[" | tail -5 || echo "Some downloads failed, continuing"

echo "[7] Building base LXC image for ${SUITE}..."
base_img=$BHOME/gitian-builder/base-${SUITE}-amd64
if [ ! -f $base_img ]; then
    ./bin/make-base-vm --lxc --arch amd64 --distro debian --suite $SUITE
else
    echo "Base image exists"
fi

echo "[8] Running gbuild for ${SUITE}..."
if ! ./bin/gbuild --fetch-tags -j "$PROC" -m "$MEM" \
        --commit zcash="${TAG}" \
        --url zcash="https://github.com/${OWNER}/${REPO}" \
        "$GITIAN_DESC"; then
    echo "Build FAILED for ${SUITE}"
    tail -100 $BHOME/gitian-builder/var/build.log 2>/dev/null || true
    exit 1
fi

echo "[9] Signing ${SUITE}..."
./bin/gsign -p "gpg --batch --detach-sign" \
    --signer sysadmin \
    --release ${TAG#v}_${SUITE} \
    --destination $BHOME/gitian.sigs/ \
    "$GITIAN_DESC"

ASSERT_SRC="$BHOME/gitian.sigs/${TAG#v}_${SUITE}/sysadmin"
ASSERT_DST="$BHOME/gitian.sigs/${TAG#v}_${SUITE}/sysadmin-zodl"
mkdir -p "$ASSERT_DST"
ASSERT_FILE=$(ls "$ASSERT_SRC"/*.assert 2>/dev/null | head -1)
if [ -n "$ASSERT_FILE" ]; then
    ASSERT_NAME=$(basename "$ASSERT_FILE")
    cp "$ASSERT_FILE" "$ASSERT_DST/$ASSERT_NAME"
    gpg --batch --no-tty -u sysadmin@zodl.com \
        --detach-sign \
        --output "$ASSERT_DST/${ASSERT_NAME}.sig" \
        "$ASSERT_DST/$ASSERT_NAME"
fi

echo "[10] Collecting + renaming artifacts..."
suite_out=$BHOME/zcash-binaries/${TAG#v}/${SUITE}
mkdir -p $suite_out
mv $BHOME/gitian-builder/build/out/zcash-*.tar.gz $suite_out/ 2>/dev/null || true
mv $BHOME/gitian-builder/build/out/src/zcash-*.tar.gz $suite_out/ 2>/dev/null || true

cd $suite_out
for j in $(ls *linux64.tar.gz 2>/dev/null); do
    mv "$j" "$(echo $j | sed "s/\.tar\.gz/-debian-${SUITE}.tar.gz/")"
done
for j in $(ls *debug.tar.gz 2>/dev/null); do
    mv "$j" "$(echo $j | sed "s/\.tar\.gz/-debian-${SUITE}.tar.gz/")"
done

echo "[11] Signing + uploading tarballs..."
for f in *.tar.gz; do
    gpg -u sysadmin@z.cash --batch --armor --digest-algo SHA256 --detach-sign "$f"
done
aws s3 sync ./ "s3://zodl-public-download/${TAG#v}/${SUITE}/" --no-progress
for f in *.tar.gz *.tar.gz.asc; do
    [ -f "$f" ] || continue
    aws s3 cp "$f" "s3://zodl-public-download/downloads/$f" --no-progress 2>/dev/null || true
done

echo "[12] Purge BunnyCDN..."
curl -s -X POST "https://api.bunny.net/pullzone/${BUNNY_ZONE}/purgeCache" \
    -H "content-type: application/json" -H "AccessKey: ${BUNNY_KEY}"

# Push gitian.sigs for non-RC releases only
if [[ "${TAG}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[13] Pushing gitian.sigs..."
    GH_TOKEN=$(aws secretsmanager get-secret-value \
        --secret-id /infra/gitian/gitian_sigs_deploy_key \
        --query SecretString --output text)
    PUSH_DIR=/root/build/gitian.sigs-push-${SUITE}
    git clone "https://x-access-token:${GH_TOKEN}@github.com/zcash/gitian.sigs.git" "$PUSH_DIR"
    cp -a $BHOME/gitian.sigs/. "$PUSH_DIR/"
    cd "$PUSH_DIR"
    git config user.name "sysadmin"
    git config user.email "sysadmin@zodl.com"
    git add .
    git diff --cached --stat
    git commit -m "${TAG} ${SUITE}" || echo "Nothing to commit"
    # Retry push in case the other suite pushed first
    for i in 1 2 3; do
        git pull --rebase origin master 2>/dev/null || true
        git push && break
        sleep 5
    done
    unset GH_TOKEN
fi

echo ""
echo "=============================="
echo " BUILD COMPLETE: ${TAG} / ${SUITE}"
echo "=============================="
