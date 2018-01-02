# Aliases for Google

    alias sync_scripts_from_workstation 'rsync -azP --delete workstation:///usr/local/google/home/jeffjose/scripts/ ~/scripts/'
    alias sync_scripts_from_laptop 'rsync -azP --delete laptop:///home/jeffjose/scripts/ ~/scripts/'

    alias sync_dropbox_from_laptop 'rsync -azP --delete laptop:///home/jeffjose/dropbox/ ~/dropbox/'

    alias send_to_laptop 'rsync -azP --delete \!* laptop:///home/jeffjose/Downloads/'

    alias b blaze
    alias bb   blaze build -c opt --forge --objfs
    alias brun blaze run -c opt --forge --objfs

    alias fu fileutil

    alias oauth 'oauth2l header --sso $USER@google.com \!*'

    alias curl curl --silent

    alias imgdiff 'composite \!* -compose difference /tmp/imagediff.$$.jpg ; convert /tmp/imagediff.$$.jpg -auto-level /tmp/imagediff.$$.jpg ; \eog /tmp/imagediff.$$.jpg'

    alias placer '/google/data/ro/projects/placer/placer'

    alias g5 '/google/data/ro/projects/shelltoys/g5.sar'

    alias c 'cd ~/critique'

    #
    alias citc 'cd /google/src/cloud/jeffjose/\!*'
    complete citc 'p@1@`ls --color=never -1 /google/src/cloud/jeffjose/`@'

    alias er '/google/data/ro/users/ho/hooper/er'

    alias goog 'cd `git5 info --format="%(workdir)s"`/google3'

    alias cl 'chrome https://cl/\!*'

    alias colab '/google/data/ro/teams/colab/notebook'

    alias nb 'cd ~/notebooks'

    alias curlmobile 'curl -H "User-Agent: Mozilla/5.0 (Linux; Android 5.1.1; Nexus 6 Build/LYZ28E) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/62.0.3202.75 Mobile Safari/537.36"'

    alias fixit 'ssh-agent > /tmp/ssh-agent-fix.sh; source /tmp/ssh-agent-fix.sh'

    alias gd 'mkdir -p \!:1; cd \!:1; git5 start \!:1; git5 track \!:2; mkdir -p google3/\!:2; cd google3/\!:2'

    alias btargets 'source ~/bin/btargets'

    alias getcdoc '/google/data/ro/projects/segindexer/tools/djfetch --output_format=human_full --url=\!*'

    alias cs cs --experimental

    alias gq gqui
    alias fb 'nautilus . &'
    alias screen 'scrn -c ~/.screen/default'
