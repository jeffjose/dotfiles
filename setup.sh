#!/bin/bash

# Setting up some directories
#
#

echo "-----------------"
echo "Setting up $HOME"
echo "-----------------"

mkdir -p $HOME/bin
mkdir -p $HOME/scripts
mkdir -p $HOME/Downloads
mkdir -p $HOME/.config/nvim
mkdir -p $HOME/.screen
mkdir -p $HOME/.config/Code/User/
mkdir -p $HOME/.config/catt/
#mkdir -p $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/
mkdir -p $HOME/.ipython/profile_default/
mkdir -p $HOME/.screenlayout
mkdir -p $HOME/.jupyter/custom/

touch /tmp/cwdcmd_recent_dirs

# Ensure that the .aliases.sensitive.sh file exists
#
#
touch $HOME/.aliases.sensitive.sh

rm $HOME/bin/scrn
ln /usr/bin/screen $HOME/bin/scrn -s

# Link dotfiles
#
#
rm $HOME/.aliases
ln .aliases $HOME/.aliases
rm $HOME/.aliases.bash
ln .aliases.bash $HOME/.aliases.bash
rm $HOME/.colordiffrc
ln .colordiffrc $HOME/.colordiffrc
rm $HOME/.cshrc
ln .cshrc $HOME/.cshrc
rm $HOME/.cwdcmd
ln .cwdcmd $HOME/.cwdcmd
rm $HOME/.gitconfig
ln .gitconfig $HOME/.gitconfig
rm $HOME/.pdbrc
ln .pdbrc $HOME/.pdbrc
rm $HOME/.precmd
ln .precmd $HOME/.precmd
rm $HOME/.prompt
ln .prompt $HOME/.prompt
rm $HOME/.screen/default
ln .screen/default $HOME/.screen/default
rm $HOME/.screenrc
ln .screenrc $HOME/.screenrc
rm $HOME/.tabletaliases
ln .tabletaliases $HOME/.tabletaliases
rm $HOME/.vimrc
ln .vimrc $HOME/.vimrc
rm $HOME/.XResources
ln .XResources $HOME/.XResources
rm $HOME/.xmodmap
ln .xmodmap $HOME/.xmodmap
rm $HOME/.xsession
ln .xsession $HOME/.xsession
rm $HOME/.config/Code/User/settings.json
ln settings.json $HOME/.config/Code/User/settings.json
rm $HOME/.config/Code/User/keybindings.json
ln keybindings.json $HOME/.config/Code/User/keybindings.json
rm $HOME/.config/catt/catt.cfg
ln catt.cfg $HOME/.config/catt/catt.cfg
rm $HOME/.ipython/profile_default/ipython_config.py
ln ipython_config.py $HOME/.ipython/profile_default/ipython_config.py
rm $HOME/.jupyter/custom/custom.js
ln custom.js $HOME/.jupyter/custom/custom.js

#rm $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml ; ln xfce4-panel.xml $HOME/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml

rm $HOME/.config/nvim/init.vim
ln init.vim $HOME/.config/nvim/init.vim
rm $HOME/.screenlayout/3monitor.sh
ln 3monitor.sh $HOME/.screenlayout/3monitor.sh

# VS Code
rm $HOME/.vscode/extensions/material-theme-jeffjose -r
mkdir -p $HOME/.vscode/extensions
cp -r material-theme-jeffjose $HOME/.vscode/extensions/material-theme-jeffjose

# Tilix
dconf load /com/gexperts/Tilix/ < tilix.dconf

# Install Python packages
./pip.sh

# Yarn packages
./yarn.sh

# VIM Plugins
./vim.sh

# Ignore
#
#ccsm.profile
#ccsm.with.defaults.profile
#gradle.properties
#lxrandr-autostart.desktop
