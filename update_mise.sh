#!/bin/bash
#
# Update mise tools
set -e


echo "Updating mise..."
mise self-update --yes

echo "Upgrading mise tools..."
mise upgrade --bump

mise install

exit 0
