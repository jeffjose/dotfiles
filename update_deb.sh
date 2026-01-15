#!/usr/bin/env -S bash --noprofile
#
# Update deb packages using deb-downloader
# Downloads happen in parallel, but progress is shown sequentially
#
# Usage: update_deb.sh [--sequential]
#   --sequential, -s    Disable parallel downloads (for debugging)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMPDIR="${TMPDIR:-/tmp}"
PARALLEL=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sequential|-s)
            PARALLEL=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: update_deb.sh [--sequential|-s]"
            exit 1
            ;;
    esac
done

# Create temp files for output
out_antigravity="$TMPDIR/deb-dl-antigravity.$$"
out_chrome="$TMPDIR/deb-dl-chrome.$$"
out_code="$TMPDIR/deb-dl-code.$$"

# Cleanup on exit
cleanup() {
    rm -f "$out_antigravity" "$out_chrome" "$out_code"
}
trap cleanup EXIT

echo "Updating deb packages..."
echo ""

# Function to show output of a background job, following until done
show_progress() {
    local pid=$1
    local outfile=$2
    local name=$3

    echo "=== $name ==="

    # Tail the output file, following new content
    # Stop when the process exits
    tail -f "$outfile" 2>/dev/null &
    local tail_pid=$!

    # Wait for the download process to finish
    wait "$pid" 2>/dev/null
    local exit_code=$?

    # Give tail a moment to catch up, then kill it
    sleep 0.2
    kill "$tail_pid" 2>/dev/null || true
    wait "$tail_pid" 2>/dev/null || true

    echo ""
    return $exit_code
}

# Sequential mode - run one at a time with direct output
run_sequential() {
    echo "=== antigravity ==="
    ~/scripts/deb-downloader/deb-downloader \
        --url "https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev" \
        --dist "antigravity-debian" \
        --install || return 1
    echo ""

    echo "=== google-chrome-stable ==="
    ~/scripts/deb-downloader/deb-downloader \
        --deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
        --install || return 1
    echo ""

    echo "=== code (VS Code) ==="
    ~/scripts/deb-downloader/deb-downloader \
        --deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" \
        --install || return 1
    echo ""
}

# Parallel mode - download in parallel, show progress sequentially
run_parallel() {
    # Start all downloads in parallel, capturing output to temp files
    ~/scripts/deb-downloader/deb-downloader \
        --url "https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev" \
        --dist "antigravity-debian" \
        --install \
        > "$out_antigravity" 2>&1 &
    pid_antigravity=$!

    ~/scripts/deb-downloader/deb-downloader \
        --deb "https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb" \
        --install \
        > "$out_chrome" 2>&1 &
    pid_chrome=$!

    ~/scripts/deb-downloader/deb-downloader \
        --deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64" \
        --install \
        > "$out_code" 2>&1 &
    pid_code=$!

    # Show progress sequentially
    # By the time we show each one, it may already be done (which is fine)
    local exit_code=0
    show_progress "$pid_antigravity" "$out_antigravity" "antigravity" || exit_code=1
    show_progress "$pid_chrome" "$out_chrome" "google-chrome-stable" || exit_code=1
    show_progress "$pid_code" "$out_code" "code (VS Code)" || exit_code=1
    return $exit_code
}

if [[ "$PARALLEL" == "true" ]]; then
    run_parallel
else
    run_sequential
fi
