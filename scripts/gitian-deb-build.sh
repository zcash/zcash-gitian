#!/bin/bash
# gitian-deb-build.sh — Build Debian packages from Gitian tarballs
#
# Runs on any machine with Docker. Extracts pre-built binaries from the Gitian
# tarballs and packages them using zcash/zcash's build-debian-package.sh script.
#
# Required env vars:
#   TAG      — Git tag (e.g. v6.13.0)
#   SUITES   — Space-separated list of Debian suites (e.g. "bullseye bookworm")
#
# AWS credentials must be available (IAM role or env vars).

set -euo pipefail

: "${TAG:?TAG is required (e.g. v6.13.0)}"
: "${SUITES:?SUITES is required (e.g. bullseye bookworm)}"

VERSION="${TAG#v}"
WORKDIR="/root/deb-build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[1] Import GPG keys from Secrets Manager..."
aws secretsmanager get-secret-value \
    --secret-id /release/gpg-signing-key-zcash \
    --query SecretString --output text > /tmp/ecc-private.pgp
aws secretsmanager get-secret-value \
    --secret-id /release/gpg-signing-key \
    --query SecretString --output text > /tmp/zodl-private.pgp
gpg --batch --import /tmp/ecc-private.pgp
gpg --batch --import /tmp/zodl-private.pgp
rm -f /tmp/ecc-private.pgp /tmp/zodl-private.pgp

echo "[2] Download tarballs from S3..."
mkdir -p tarballs debs
for suite in $SUITES; do
    echo "Downloading $suite tarball..."
    aws s3 cp "s3://zodl-public-download/${VERSION}/${suite}/zcash-${VERSION}-debian-${suite}-linux64.tar.gz" \
        "tarballs/zcash-${VERSION}-${suite}.tar.gz"
done

echo "[3] Build .deb packages for each suite..."
for suite in $SUITES; do
    echo ""
    echo "=== Building .deb for $suite ==="

    # Extract binaries from tarball
    mkdir -p "extract-${suite}"
    tar -xzf "tarballs/zcash-${VERSION}-${suite}.tar.gz" -C "extract-${suite}" --strip-components=1

    # Start Debian container
    docker rm -f "${suite}-build" 2>/dev/null || true
    docker run -d --name "${suite}-build" "debian:${suite}" bash -c "while true; do sleep 2; done"

    # Clone zcash repo (for build-debian-package.sh)
    docker exec "${suite}-build" bash -c "
        apt-get update -qq
        apt-get install -y -qq git build-essential debhelper lintian
    "
    docker exec "${suite}-build" git clone -b "${TAG}" https://github.com/zcash/zcash.git /home/build

    # Copy pre-built binaries into the container
    docker cp "extract-${suite}/bin/." "${suite}-build:/home/build/${suite}-extract/"

    # Run the Debian packaging script
    docker exec -w /home/build "${suite}-build" bash -c "
        rm -rf src
        mv ${suite}-extract src
        bash ./zcutil/build-debian-package.sh || true
    "

    # Copy .deb out (even if lintian failed)
    mkdir -p "debs/${suite}"
    docker cp "${suite}-build:/tmp/zcbuild/." "debs/${suite}/" || echo "Warning: no .deb found"

    # Clean up container
    docker rm -f "${suite}-build"

    # Rename .deb to expected format: zcash-VERSION-amd64-SUITE.deb
    if ls debs/${suite}/zcash_*.deb 1>/dev/null 2>&1; then
        for deb in debs/${suite}/zcash_*.deb; do
            NEW_NAME="debs/${suite}/zcash-${VERSION}-amd64-${suite}.deb"
            mv "$deb" "$NEW_NAME"
            echo "Built: $NEW_NAME"
            dpkg-deb -I "$NEW_NAME" | head -20
        done
    else
        echo "ERROR: No .deb found for $suite"
        exit 1
    fi
done

echo ""
echo "=== BUILD COMPLETE ==="
ls -lh debs/*/*.deb

echo ""
echo "Next steps:"
echo "  1. Upload .deb files to S3 pool: aws s3 cp debs/SUITE/*.deb s3://zodl-apt-server-zcash/pool/main/z/zcash/"
echo "  2. Update APT metadata: run gitian-apt-build.sh"
