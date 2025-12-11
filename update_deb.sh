#!/usr/bin/env -S bash --noprofile
#
# Update deb packages using deb-downloader

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Updating deb packages..."
~/scripts/deb-downloader/deb-downloader --config "$SCRIPT_DIR/package.toml"

exit 0
