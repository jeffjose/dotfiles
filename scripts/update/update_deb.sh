#!/usr/bin/env -S bash --noprofile
#
# Update deb packages using deb-downloader
# Downloads happen in parallel, but progress is shown sequentially
#
# Usage: update_deb.sh [--sequential]
#   --sequential, -s    Disable parallel downloads (for debugging)

set -euo pipefail

source "$HOME/dotfiles/scripts/lib/ui.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$SCRIPT_DIR/../.."
CONFIG_FILE="$DOTFILES_DIR/misc/package.toml"
TMPDIR="${TMPDIR:-/tmp}"
# Keep downloaded .debs and their ETag metadata somewhere that survives a
# reboot. deb-downloader defaults to /tmp, so every boot wiped the cache and the
# next run re-downloaded everything (135 MB for Chrome alone).
CACHE_DIR="$HOME/.cache/deb-downloader"
PARALLEL=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --sequential|-s)
            PARALLEL=false
            shift
            ;;
        *)
            err "unknown option: $1"
            detail "usage: update_deb.sh [--sequential|-s]" >&2
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
# Usage: build_command name type url dist [--install]
build_command() {
    local name="$1"
    local pkg_type="$2"
    local url="$3"
    local dist="$4"
    local install_flag="${5:-}"

    if [[ "$pkg_type" == "deb" ]]; then
        echo "~/scripts/deb-downloader/deb-downloader --deb \"$url\" --output-dir \"$CACHE_DIR\" $install_flag"
    else
        echo "~/scripts/deb-downloader/deb-downloader --url \"$url\" --dist \"$dist\" --output-dir \"$CACHE_DIR\" $install_flag"
    fi
}


# Reword deb-downloader's output to match the rest of uq.
#
# For a package that is already current it prints three lines — the URL, then
# "→ name version", then "✓ Already installed" — which become the single
#        Fresh name version
# Anything else it says is passed through as it is. Read a byte at a time so
# that a download's progress bar, which redraws with \r and no newline, still
# moves instead of sitting in a line buffer until the download is over.
deb_lines() {
    DIM="$DIM" RESET="$RESET" perl -e '
        $| = 1; $/ = \1;
        my ($line, $pending) = ("", "");
        sub flush_pending { print $pending if length $pending; $pending = ""; }
        while (my $c = <STDIN>) {
            if ($c eq "\r") { flush_pending(); print "$line\r"; $line = ""; next; }
            if ($c ne "\n") { $line .= $c; next; }
            (my $plain = $line) =~ s/\e\[[0-9;]*m//g;
            if ($plain =~ m{^https?://\S+$}) {
                # the URL being checked: nothing the "Checking" line did not say
            } elsif ($plain =~ /^→ (.+)$/) {
                flush_pending(); $pending = "$line\n"; $name = $1;
            } elsif ($plain =~ /Already installed$/ && length $pending) {
                printf "%s%12s%s %s%s%s\n", $ENV{DIM}, "Fresh", $ENV{RESET}, $ENV{DIM}, $name, $ENV{RESET};
                $pending = "";
            } else {
                flush_pending(); print "$line\n";
            }
            $line = "";
        }
        flush_pending(); print $line;
    '
}

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

    say "$CYAN" "Checking" "$name"

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

        say "$CYAN" "Checking" "$name"
        local cmd
        cmd=$(build_command "$name" "$pkg_type" "$url" "$dist" "--install")
        eval "$cmd" | deb_lines || exit_code=1
    done
    return $exit_code
}

# Parallel mode - first package in foreground, others download in background
run_parallel() {
    declare -a pids=()
    declare -a outfiles=()
    local exit_code=0

    # Start background downloads for packages 2+ (download only, no install)
    for i in "${!pkg_names[@]}"; do
        if [[ $i -eq 0 ]]; then
            continue  # Skip first package, will run in foreground
        fi

        local name="${pkg_names[$i]}"
        local pkg_type="${pkg_types[$i]}"
        local url="${pkg_urls[$i]}"
        local dist="${pkg_dists[$i]}"

        local outfile="$TMPDIR/deb-dl-${name//[^a-zA-Z0-9]/_}.$$"
        outfiles[$i]="$outfile"
        temp_files+=("$outfile")

        local cmd
        # No --install flag - just download in background
        cmd=$(build_command "$name" "$pkg_type" "$url" "$dist")
        eval "$cmd" < /dev/null > "$outfile" 2>&1 &
        pids[$i]=$!
    done

    # Run first package in foreground with install (real TTY = progress bars + sudo)
    say "$CYAN" "Checking" "${pkg_names[0]}"
    local cmd
    cmd=$(build_command "${pkg_names[0]}" "${pkg_types[0]}" "${pkg_urls[0]}" "${pkg_dists[0]}" "--install")
    eval "$cmd" | deb_lines || exit_code=1

    # Show remaining packages' download output, then install in foreground
    for i in "${!pkg_names[@]}"; do
        if [[ $i -eq 0 ]]; then
            continue  # Already ran first package
        fi

        local name="${pkg_names[$i]}"
        local pkg_type="${pkg_types[$i]}"
        local url="${pkg_urls[$i]}"
        local dist="${pkg_dists[$i]}"

        # Wait for the download to finish. Its output is only worth showing if it
        # failed: the install below reports on the same package again.
        say "$CYAN" "Checking" "$name"
        wait "${pids[$i]}" 2>/dev/null || cat "${outfiles[$i]}"

        # Now run install in foreground (can prompt for sudo)
        cmd=$(build_command "$name" "$pkg_type" "$url" "$dist" "--install")
        eval "$cmd" | deb_lines || exit_code=1
    done
    return $exit_code
}

if [[ "$PARALLEL" == "true" ]]; then
    run_parallel
else
    run_sequential
fi
