#!/usr/bin/tcsh -fb

# Setting up some directories
#
#
  mkdir -p $HOME/scripts
  mkdir -p $HOME/Downloads
  mkdir -p $HOME/.config/nvim
  mkdir -p $HOME/.screen
  mkdir -p $HOME/.config/Code/User/

  touch /tmp/cwdcmd_recent_dirs

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
  rm $HOME/.aliases                             ; ln .aliases                    $HOME/.aliases
  rm $HOME/.aliases.bash                        ; ln .aliases.bash               $HOME/.aliases.bash
  rm $HOME/.colordiffrc                         ; ln .colordiffrc                $HOME/.colordiffrc
  rm $HOME/.cshrc                               ; ln .cshrc                      $HOME/.cshrc
  rm $HOME/.cwdcmd                              ; ln .cwdcmd                     $HOME/.cwdcmd
  rm $HOME/.gitconfig                           ; ln .gitconfig                  $HOME/.gitconfig
  rm $HOME/.pdbrc                               ; ln .pdbrc                      $HOME/.pdbrc
  rm $HOME/.precmd                              ; ln .precmd                     $HOME/.precmd
  rm $HOME/.prompt                              ; ln .prompt                     $HOME/.prompt
  rm $HOME/.screen/default                      ; ln .screen/default             $HOME/.screen/default
  rm $HOME/.screenrc                            ; ln .screenrc                   $HOME/.screenrc
  rm $HOME/.tabletaliases                       ; ln .tabletaliases              $HOME/.tabletaliases
  rm $HOME/.vimrc                               ; ln .vimrc                      $HOME/.vimrc
  rm $HOME/.XResources                          ; ln .XResources                 $HOME/.XResources
  rm $HOME/.config/Code/User/settings.json      ; ln settings.json               $HOME/.config/Code/User/settings.json
  rm $HOME/.config/Code/User/keybindings.json   ; ln keybindings.json            $HOME/.config/Code/User/keybindings.json

  rm $HOME/scripts/updateall.sh  ; ln updateall.sh $HOME/scripts/updateall.sh

  rm $HOME/.config/nvim/init.vim  ; ln init.vim $HOME/.config/nvim/init.vim

# Ignore
#
#ccsm.profile
#ccsm.with.defaults.profile
#gradle.properties
#lxrandr-autostart.desktop
