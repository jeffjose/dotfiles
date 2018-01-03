#!/usr/bin/tcsh -fb

mkdir -p $HOME/scripts
mkdir -p $HOME/Downloads
mkdir -p $HOME/.config/nvim
mkdir -p $HOME/.screen

touch $HOME/.aliases.sensitive.sh

ln .aliases                    $HOME/.aliases
ln .aliases.bash               $HOME/.aliases.bash
ln .aliases.google.sh          $HOME/.aliases.google.sh
ln .colordiffrc                $HOME/.colordiffrc
ln .cshrc                      $HOME/.cshrc
ln .cwdcmd                     $HOME/.cwdcmd
ln .gitconfig                  $HOME/.gitconfig
ln .pdbrc                      $HOME/.pdbrc
ln .precmd                     $HOME/.precmd
ln .prompt                     $HOME/.prompt
ln .screen/default             $HOME/.screen/default
ln .screenrc                   $HOME/.screenrc
ln .tabletaliases              $HOME/.tabletaliases
ln .vimrc                      $HOME/.vimrc
ln .XResources                 $HOME/.XResources

ln updateall.sh $HOME/scripts/updateall.sh

ln init.vim $HOME/.config/nvim/init.vim

#ccsm.profile
#ccsm.with.defaults.profile
#gradle.properties
#lxrandr-autostart.desktop
