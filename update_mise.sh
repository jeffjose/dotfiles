#!/bin/bash
#
# Update mise tools
set -e

echo "Upgrading mise tools..."
mise upgrade --bump

exit 0
