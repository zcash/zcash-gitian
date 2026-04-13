#!/bin/bash
# gitian-apt-build.sh — Update APT repository metadata (incremental)
#
# Updates the APT repository metadata without needing to download all existing .deb files.
# Uses an incremental approach: download current Packages file, update entry for new version,
# regenerate Release/InRelease files, sign with GPG, and upload only the metadata files.
#
# Required env vars:
#   VERSION  — Version number without 'v' prefix (e.g. 6.13.0)
#   SUITES   — Space-separated list of Debian suites (e.g. "bullseye bookworm")
#
# Prerequisites:
#   - .deb files already uploaded to s3://zodl-apt-server-zcash/pool/main/z/zcash/
#   - GPG key imported for signing (sysadmin@z.cash)
#   - AWS credentials available

set -euo pipefail

: "${VERSION:?VERSION is required (e.g. 6.13.0)}"
: "${SUITES:?SUITES is required (e.g. bullseye bookworm)}"

BUCKET="zodl-apt-server-zcash"
WORKDIR="/root/apt-build"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo "[1] Import GPG key from Secrets Manager..."
aws secretsmanager get-secret-value \
    --secret-id /release/gpg-signing-key-zcash \
    --query SecretString --output text > /tmp/ecc-private.pgp
gpg --batch --import /tmp/ecc-private.pgp
rm -f /tmp/ecc-private.pgp

echo "[2] Process each suite..."
for suite in $SUITES; do
    echo ""
    echo "=== Updating APT metadata for $suite ==="

    DIST_DIR="dists/${suite}"
    BINARY_DIR="${DIST_DIR}/main/binary-amd64"
    mkdir -p "$BINARY_DIR"

    DEB_NAME="zcash-${VERSION}-amd64-${suite}.deb"
    DEB_PATH="pool/main/z/zcash/${DEB_NAME}"

    # Download current Packages.gz (if exists)
    if aws s3 cp "s3://${BUCKET}/${BINARY_DIR}/Packages.gz" Packages.gz 2>/dev/null; then
        echo "Downloaded existing Packages.gz"
        gunzip -f Packages.gz
    else
        echo "No existing Packages file — creating new one"
        touch Packages
    fi

    # Download the new .deb to extract metadata
    aws s3 cp "s3://${BUCKET}/${DEB_PATH}" "${DEB_NAME}"

    # Extract metadata from .deb
    DEB_SIZE=$(stat -c%s "${DEB_NAME}")
    DEB_MD5=$(md5sum "${DEB_NAME}" | awk '{print $1}')
    DEB_SHA1=$(sha1sum "${DEB_NAME}" | awk '{print $1}')
    DEB_SHA256=$(sha256sum "${DEB_NAME}" | awk '{print $1}')

    # Get control fields from .deb
    DEB_PACKAGE=$(dpkg-deb -f "${DEB_NAME}" Package)
    DEB_VERSION_FULL=$(dpkg-deb -f "${DEB_NAME}" Version)
    DEB_ARCH=$(dpkg-deb -f "${DEB_NAME}" Architecture)
    DEB_MAINTAINER=$(dpkg-deb -f "${DEB_NAME}" Maintainer)
    DEB_DESCRIPTION=$(dpkg-deb -f "${DEB_NAME}" Description)

    # Update Packages file (remove old entry for this version, add new one)
    python3 <<EOF
import sys

# Read current Packages file
with open('Packages', 'r') as f:
    content = f.read()

# Split into package stanzas
stanzas = content.split('\n\n')
new_stanzas = []

# Filter out existing entry for this version
for stanza in stanzas:
    if not stanza.strip():
        continue
    # Skip if this is the same package/version
    lines = stanza.split('\n')
    pkg_name = None
    pkg_ver = None
    for line in lines:
        if line.startswith('Package: '):
            pkg_name = line.split(': ', 1)[1]
        if line.startswith('Version: '):
            pkg_ver = line.split(': ', 1)[1]

    # Keep stanza only if it's a different version or different package
    if pkg_name != '${DEB_PACKAGE}' or pkg_ver != '${DEB_VERSION_FULL}':
        new_stanzas.append(stanza)

# Add new entry
new_entry = f"""Package: ${DEB_PACKAGE}
Version: ${DEB_VERSION_FULL}
Architecture: ${DEB_ARCH}
Maintainer: ${DEB_MAINTAINER}
Filename: ${DEB_PATH}
Size: ${DEB_SIZE}
MD5sum: ${DEB_MD5}
SHA1: ${DEB_SHA1}
SHA256: ${DEB_SHA256}
Description: ${DEB_DESCRIPTION}"""

new_stanzas.append(new_entry)

# Write updated Packages file
with open('Packages', 'w') as f:
    f.write('\n\n'.join(new_stanzas))
    f.write('\n')

print(f"Updated Packages file: added {pkg_name} {pkg_ver}")
EOF

    # Compress Packages
    gzip -9 -k -f Packages
    echo "Compressed Packages → Packages.gz"

    # Generate Release file
    cat > "${DIST_DIR}/Release" <<EOF
Origin: Zcash
Label: Zcash
Suite: ${suite}
Codename: ${suite}
Date: $(date -R -u)
Architectures: amd64
Components: main
Description: Zcash APT Repository
EOF

    # Add checksums to Release
    cd "${DIST_DIR}"
    echo "MD5Sum:" >> Release
    for f in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
        echo " $(md5sum $f | awk '{print $1}') $(stat -c%s $f) $f" >> Release
    done
    echo "SHA256:" >> Release
    for f in main/binary-amd64/Packages main/binary-amd64/Packages.gz; do
        echo " $(sha256sum $f | awk '{print $1}') $(stat -c%s $f) $f" >> Release
    done
    cd "$WORKDIR"

    # Sign Release → InRelease (clearsigned)
    gpg --batch --clearsign --armor \
        -u sysadmin@z.cash \
        --output "${DIST_DIR}/InRelease" \
        "${DIST_DIR}/Release"

    # Sign Release → Release.gpg (detached signature)
    gpg --batch --detach-sign --armor \
        -u sysadmin@z.cash \
        --output "${DIST_DIR}/Release.gpg" \
        "${DIST_DIR}/Release"

    echo "Signed Release → InRelease + Release.gpg"

    # Upload metadata files to S3
    for f in Release InRelease Release.gpg; do
        aws s3 cp "${DIST_DIR}/$f" "s3://${BUCKET}/${DIST_DIR}/"
        echo "  Uploaded: ${DIST_DIR}/$f"
    done

    for f in Packages Packages.gz; do
        aws s3 cp "${BINARY_DIR}/$f" "s3://${BUCKET}/${BINARY_DIR}/"
        echo "  Uploaded: ${BINARY_DIR}/$f"
    done

    echo "✓ APT metadata updated for $suite"
done

echo ""
echo "=== APT REPO UPDATE COMPLETE ==="
echo ""
echo "Verify:"
for suite in $SUITES; do
    echo "  curl -sI https://apt.z.cash/dists/${suite}/InRelease"
    echo "  curl -sI https://apt.z.cash/pool/main/z/zcash/zcash-${VERSION}-amd64-${suite}.deb"
done
