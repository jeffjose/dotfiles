sudo apt install git neovim curl moreutils tilix ack screen gitk

mkdir -p ~/bin/
ln /usr/bin/screen ~/bin/scrn -s

curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list

sudo apt-get update && sudo apt-get install yarn

sudo apt autoremove

#ssh-keygen -t rsa -b 4096 -C "jeffjosejeff@gmail.com"
