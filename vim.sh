#!/bin/bash
#
# Jeffrey Jose | May 2, 2020
#

echo "-----------------"
echo "VIM"
echo "-----------------"

# Setup the essential vim plugins
#
#
rm -rf ~/.vim/bundle/Vundle.vim
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
mkdir -p ~/.vim/autoload ~/.vim/bundle && curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim

# Setup vim plugins
#
#

clone() {

  echo ""
  echo "> Working on $1"

  [ -d $2 ] || git clone $1 $2
  (
    cd $2
    git pull $1
  )

}

clone https://github.com/posva/vim-vue.git ~/.vim/bundle/vim-vue
clone https://github.com/dart-lang/dart-vim-plugin ~/.vim/bundle/dart-vim-plugin
clone https://github.com/kchmck/vim-coffee-script.git ~/.vim/bundle/vim-coffee-script
clone git://github.com/digitaltoad/vim-pug.git ~/.vim/bundle/vim-pug
clone https://github.com/leafoftree/vim-svelte-plugin ~/.vim/bundle/vim-svelte-plugin
