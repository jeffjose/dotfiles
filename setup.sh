#!/usr/bin/tcsh -fb

# Setting up some directories
#
#
  mkdir -p $HOME/scripts
  mkdir -p $HOME/Downloads
  mkdir -p $HOME/.config/nvim
  mkdir -p $HOME/.screen
  mkdir -p $HOME/.config/Code/User/
  mkdir -p $HOME/.config/catt/
  mkdir -p $HOME/.ipython/profile_default/
  mkdir -p $HOME/.screenlayout
  mkdir -p $HOME/.jupyter/custom/

  touch /tmp/cwdcmd_recent_dirs

# Ensure that the .aliases.sensitive.sh file exists
#
#
  touch $HOME/.aliases.sensitive.sh

# Setup the essential vim plugins
#
#
  rm -rf ~/.vim/bundle/Vundle.vim
  git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
  mkdir -p ~/.vim/autoload ~/.vim/bundle && curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Setup vim plugins
#
#

  rm -rf ~/.vim/bundle/vim-vue;           git clone https://github.com/posva/vim-vue.git         ~/.vim/bundle/vim-vue
  rm -rf ~/.vim/bundle/dart-vim-plugin;   git clone https://github.com/dart-lang/dart-vim-plugin ~/.vim/bundle/dart-vim-plugin
  rm -rf ~/.vim/bundle/vim-coffee-script; git clone  https://github.com/kchmck/vim-coffee-script.git ~/.vim/bundle/vim-coffee-script
  rm -rf ~/.vim/bundle/vim-pug;           git clone git://github.com/digitaltoad/vim-pug.git ~/.vim/bundle/vim-pug


# Link dotfiles
#
#
  rm $HOME/.aliases                                   ; ln .aliases                    $HOME/.aliases
  rm $HOME/.aliases.bash                              ; ln .aliases.bash               $HOME/.aliases.bash
  rm $HOME/.colordiffrc                               ; ln .colordiffrc                $HOME/.colordiffrc
  rm $HOME/.cshrc                                     ; ln .cshrc                      $HOME/.cshrc
  rm $HOME/.cwdcmd                                    ; ln .cwdcmd                     $HOME/.cwdcmd
  rm $HOME/.gitconfig                                 ; ln .gitconfig                  $HOME/.gitconfig
  rm $HOME/.pdbrc                                     ; ln .pdbrc                      $HOME/.pdbrc
  rm $HOME/.precmd                                    ; ln .precmd                     $HOME/.precmd
  rm $HOME/.prompt                                    ; ln .prompt                     $HOME/.prompt
  rm $HOME/.screen/default                            ; ln .screen/default             $HOME/.screen/default
  rm $HOME/.screenrc                                  ; ln .screenrc                   $HOME/.screenrc
  rm $HOME/.tabletaliases                             ; ln .tabletaliases              $HOME/.tabletaliases
  rm $HOME/.vimrc                                     ; ln .vimrc                      $HOME/.vimrc
  rm $HOME/.XResources                                ; ln .XResources                 $HOME/.XResources
  rm $HOME/.config/Code/User/settings.json            ; ln settings.json               $HOME/.config/Code/User/settings.json
  rm $HOME/.config/Code/User/keybindings.json         ; ln keybindings.json            $HOME/.config/Code/User/keybindings.json
  rm $HOME/.config/catt/catt.cfg                      ; ln catt.cfg                    $HOME/.config/catt/catt.cfg
  rm $HOME/.ipython/profile_default/ipython_config.py ; ln ipython_config.py           $HOME/.ipython/profile_default/ipython_config.py
  rm $HOME/.jupyter/custom/custom.js                  ; ln custom.js                   $HOME/.jupyter/custom/custom.js

  rm $HOME/scripts/updateall.sh  ; ln updateall.sh $HOME/scripts/updateall.sh

  rm $HOME/.config/nvim/init.vim  ; ln init.vim $HOME/.config/nvim/init.vim
  rm $HOME/.screenlayout/3monitor.sh  ; ln 3monitor.sh $HOME/.screenlayout/3monitor.sh


# Ignore
#
#ccsm.profile
#ccsm.with.defaults.profile
#gradle.properties
#lxrandr-autostart.desktop
