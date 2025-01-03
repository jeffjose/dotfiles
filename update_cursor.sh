#!/bin/env bash
#
# Jeffrey Jose | Aug 11, 2024
#
set -e # Exit on error

# Constants
API_URL="https://www.cursor.com/api/dashboard/get-download-link"
CURSOR_PATH="$HOME/bin/cursor"
TEMP_PATH="/tmp/cursor"
USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

# Ensure script is run with sudo privileges
if ! sudo true; then
  echo "Error: This script requires sudo privileges"
  exit 1
fi

echo "🔄 Updating Cursor IDE..."

# Print current MD5
if [ -f "$CURSOR_PATH" ]; then
  echo -n "Current MD5: "
  md5sum "$CURSOR_PATH" | cut -d' ' -f1
fi

# Get download URL from API
echo "📡 Fetching download URL..."
DOWNLOAD_URL=$(curl -s "$API_URL" \
  -H 'accept: */*' \
  -H 'accept-language: en-US,en;q=0.9' \
  -H 'cache-control: no-cache' \
  -H 'content-type: application/json' \
  -H 'cookie: PPA_CI=b43852880117b3e250f73fbe2aa9af26' \
  -H 'origin: https://www.cursor.com' \
  -H 'pragma: no-cache' \
  -H 'priority: u=1, i' \
  -H 'referer: https://www.cursor.com/' \
  -H 'sec-ch-ua: "Google Chrome";v="131", "Chromium";v="131", "Not_A Brand";v="24"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Linux"' \
  -H 'sec-fetch-dest: empty' \
  -H 'sec-fetch-mode: cors' \
  -H 'sec-fetch-site: same-origin' \
  -H "user-agent: $USER_AGENT" \
  --data-raw '{"platform":5}' |
  jq -r '.cachedDownloadLink')

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
  echo "Error: Failed to get download URL from API"
  exit 1
fi

# Download new version
echo "📥 Downloading latest stable build..."
if ! wget -q -O "$TEMP_PATH" \
  --header="user-agent: $USER_AGENT" \
  "$DOWNLOAD_URL"; then
  echo "Error: Failed to download Cursor"
  exit 1
fi

# Install new version
echo "📦 Installing Cursor..."
mkdir -p "$(dirname "$CURSOR_PATH")"
sudo mv "$TEMP_PATH" "$CURSOR_PATH"
sudo chmod a+rwx "$CURSOR_PATH"

# Print new MD5
echo -n "Updated MD5: "
md5sum "$CURSOR_PATH" | cut -d' ' -f1

echo "✅ Cursor IDE update complete!"
