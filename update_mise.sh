#!/usr/bin/env -S bash --noprofile
#
# Update mise tools

echo "Updating mise..."
mise self-update --yes

echo "Upgrading mise tools..."
mise upgrade --bump

which mise
rm -rf /home/jeffjose/.local/share/mise/shims
mise reshim
mise install
mise reshim

exit 0
