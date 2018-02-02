# Aliases for Google

    alias sync_scripts_from_workstation 'rsync -azP --delete workstation:///usr/local/google/home/jeffjose/scripts/ ~/scripts/'
    alias sync_scripts_from_laptop 'rsync -azP --delete laptop:///home/jeffjose/scripts/ ~/scripts/'
    alias sync_scripts_to_workstation 'rsync -azP --delete /home/jeffjose/scripts/ workstation:////usr/local/google/home/jeffjose/scripts/'

    alias sync_dropbox_to_workstation 'rsync -azP --delete ~/dropbox/ workstation:///usr/local/google/home/jeffjose/dropbox/'
    alias sync_dropbox_from_workstation 'rsync -azP --delete workstation:///usr/local/google/home/jeffjose/dropbox/ ~/dropbox/'
    alias sync_dropbox_from_laptop 'rsync -azP --delete laptop:///home/jeffjose/dropbox/ ~/dropbox/'

    alias sync_downloads_from_workstation 'rsync -azP --delete workstation:///usr/local/google/home/jeffjose/Downloads/ ~/Downloads/'
    alias sync_downloads_from_laptop 'rsync -azP --delete laptop:///home/jeffjose/Downloads/ ~/Downloads/'



    alias send_to_laptop 'rsync -azP --delete \!* laptop:///home/jeffjose/Downloads/'
    alias get_from_workstation 'rsync -azP --delete workstation://\!* .'

    #alias connect_to_workstation 'ssh -Xt workstation scrn -x -R -S main'
    alias connect_to_workstation 'mosh workstation'

    alias b blaze
    alias bb   blaze build -c opt --forge --objfs
    alias br blaze run -c opt --forge --objfs
    alias blaze-run '/google/src/head/depot/google3/devtools/blaze/scripts/blaze-run.sh'
    alias brun br
    alias bmpm blaze mpm -c opt
    alias mpm_setlive_latest mpm setliveversion --version=latest
    alias mpmsetlive_latest mpm_setlive_latest

    alias p placer
    alias fu fileutil
    alias fl fileutil ls -lh -F -sharded

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

    alias get_cdoc_humanreadable '/google/data/ro/projects/segindexer/tools/djfetch --output_format=human_full --url=\!*'
    alias get_cdoc_compositedoc '/google/data/ro/projects/segindexer/tools/djfetch --output_format=compositedoc --url=\!*'
    alias get_html_from_cdoc 'gq from \!* proto CompositeDoc format "%{doc.Content.Representation}"'
    alias get_amphtml_from_cdoc 'gq from \!* proto CompositeDoc format "%{doc_attachments.[quality_dni.PcuParsedData].raw_data.html}"'
    alias get_amphtmlheaders_from_cdoc 'gq from \!* proto CompositeDoc format "%{doc_attachments.[quality_dni.PcuParsedData].raw_data.http_header}"'

    alias get_docjoin get_cdoc_humanreadable

    alias cs cs --experimental
    alias cscpp 'cs lang:c++'
    alias cspy 'cs lang:python'
    alias csgo 'cs lang:go'
    alias csproto 'cs lang:proto'

    alias gq gqui
    alias gq_count 'gqui select "count(*)" from \!*'

    alias fb 'nautilus . &'
    alias screen 'scrn -c ~/.screen/default'

    alias drun 'cat \!* | dremel'

    #alias describe 'echo \\"define table testtable \!*; describe testtable;\\" | dremel'

    alias export_to_cider 'git5 export'
    alias sync_from_cider 'git5 export --merge; git5 export --force'

    alias placer_remove_scratch 'placer abort `placer list_filesets \!*`'
    alias cider '/google/src/head/depot/google3/experimental/cider_here/cider_here.sh'
    alias bns_lookup 'lockserv resolveall'

    alias android-studio '/opt/android-studio-with-blaze-stable/bin/studio.sh'

    alias plxutil '/google/data/ro/teams/plx/plxutil'
