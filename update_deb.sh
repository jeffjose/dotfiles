#!/usr/bin/env -S bash --noprofile
#
# Update deb packages using deb-downloader
# Downloads happen in parallel, but progress is shown sequentially
#
# Usage: update_deb.sh [--sequential]
#   --sequential, -s    Disable parallel downloads (for debugging)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/package.toml"
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

# Parse package.toml and output package info as JSON lines
parse_packages() {
    python3 -c "
import sys
try:
    import tomllib
except ImportError:
    import tomli as tomllib

with open('$CONFIG_FILE', 'rb') as f:
    config = tomllib.load(f)

for pkg in config.get('packages', []):
    name = pkg.get('name', '')
    pkg_type = pkg.get('type', 'apt')
    url = pkg.get('url', '')
    dist = pkg.get('distribution', '')
    print(f'{name}|{pkg_type}|{url}|{dist}')
"
}

# Build deb-downloader command for a package
build_command() {
    local name="$1"
    local pkg_type="$2"
    local url="$3"
    local dist="$4"

    if [[ "$pkg_type" == "deb" ]]; then
        echo "~/scripts/deb-downloader/deb-downloader --deb \"$url\" --install"
    else
        echo "~/scripts/deb-downloader/deb-downloader --url \"$url\" --dist \"$dist\" --install"
    fi
}

echo "Updating deb packages..."
echo ""

# Read packages into arrays
declare -a pkg_names=()
declare -a pkg_types=()
declare -a pkg_urls=()
declare -a pkg_dists=()

while IFS='|' read -r name pkg_type url dist; do
    pkg_names+=("$name")
    pkg_types+=("$pkg_type")
    pkg_urls+=("$url")
    pkg_dists+=("$dist")
done < <(parse_packages)

num_packages=${#pkg_names[@]}

# Cleanup function - will be updated after we know temp files
declare -a temp_files=()
cleanup() {
    for f in "${temp_files[@]}"; do
        rm -f "$f"
    done
}
trap cleanup EXIT

# Function to show output of a background job, following until done
show_progress() {
    local pid=$1
    local outfile=$2
    local name=$3

    echo "=== $name ==="

    # Tail the output file, following new content
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
    local exit_code=0
    for i in "${!pkg_names[@]}"; do
        local name="${pkg_names[$i]}"
        local pkg_type="${pkg_types[$i]}"
        local url="${pkg_urls[$i]}"
        local dist="${pkg_dists[$i]}"

        echo "=== $name ==="
        local cmd
        cmd=$(build_command "$name" "$pkg_type" "$url" "$dist")
        eval "$cmd" || exit_code=1
        echo ""
    done
    return $exit_code
}

# Parallel mode - download in parallel, show progress sequentially
run_parallel() {
    declare -a pids=()
    declare -a outfiles=()

    # Start all downloads in parallel
    for i in "${!pkg_names[@]}"; do
        local name="${pkg_names[$i]}"
        local pkg_type="${pkg_types[$i]}"
        local url="${pkg_urls[$i]}"
        local dist="${pkg_dists[$i]}"

        local outfile="$TMPDIR/deb-dl-${name//[^a-zA-Z0-9]/_}.$$"
        outfiles+=("$outfile")
        temp_files+=("$outfile")

        local cmd
        cmd=$(build_command "$name" "$pkg_type" "$url" "$dist")
        eval "$cmd" > "$outfile" 2>&1 &
        pids+=($!)
    done

    # Show progress sequentially
    local exit_code=0
    for i in "${!pkg_names[@]}"; do
        show_progress "${pids[$i]}" "${outfiles[$i]}" "${pkg_names[$i]}" || exit_code=1
    done
    return $exit_code
}

if [[ "$PARALLEL" == "true" ]]; then
    run_parallel
else
    run_sequential
fi
