#!/bin/bash
#
# Jeffrey Jose | Jan 10, 2016
#
#setenv DEBIAN_FRONTEND noninteractive

# Update packages
echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating apt packages'
echo -e '---------------------------------------------------------'
echo -e ''
sudo apt -y autoclean
sudo apt -y clean
sudo apt -y update
sudo apt -y upgrade
sudo apt -y autoremove


#
# Find all out of date packages
#   npm outdated -g --depth=0
# And update using
#   npm update -g <name>
#

# Update npm packages
echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating npm packages'
echo -e '---------------------------------------------------------'
echo -e ''
# Update node itself
sudo npm install n -g
sudo n stable

sudo npm update -g

#npm outdated -g --depth=0 | cut -d " " -f 1 | grep -v pack | xargs -n 1 npm update -g

#echo -e ''
#echo -e '---------------------------------------------------------'
#echo -e 'Patching tcsh for ubuntu 16.10'
#echo -e '---------------------------------------------------------'
#echo -e ''
## patched tcsh for ubuntu 16.10
#sudo gdebi -n ~/dotfiles/tcsh_6.18.01-5_amd64.bugfix.deb

echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating python3 conda packages'
echo -e '---------------------------------------------------------'
echo -e ''

source activate root
# Update conda itself
conda update -n base conda --yes

# Update conda
conda update --all --yes

# Cleanup conda
conda clean --all --yes

echo -e ''
echo -e '---------------------------------------------------------'
echo -e 'Updating python2 conda packages'
echo -e '---------------------------------------------------------'
echo -e ''
source activate ipykernel_py2
# Update conda
conda update --all --yes

# Cleanup conda
conda clean --all --yes
