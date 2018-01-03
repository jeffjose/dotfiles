#!/usr/bin/tcsh -fb

# Setting up some directories
#
#
  mkdir -p $HOME/scripts
  mkdir -p $HOME/Downloads
  mkdir -p $HOME/.config/nvim
  mkdir -p $HOME/.screen

# Ensure that the .aliases.sensitive.sh file exists
#
#
  touch $HOME/.aliases.sensitive.sh

# Setup the essential vim plugins
#
#
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  mkdir -p ~/.vim/autoload ~/.vim/bundle && curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Link dotfiles
#
#
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

# Ignore
#
#ccsm.profile
#ccsm.with.defaults.profile
#gradle.properties
#lxrandr-autostart.desktop
