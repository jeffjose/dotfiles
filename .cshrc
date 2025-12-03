if ( ! $?prompt ) exit

   # Fixes vertical scrolling issues in vim
   if ( "$TERM" !~ "screen*" ) then
     setenv TERM xterm-256color
   endif

# Auto correct turn'd on
# Possible values = (cmd complete all)
    set correct = all

# Tab completions in color
    set autolist
    set color
    set colorcat

# Distinguish between files and folders in TAB completion
    set addsuffix
    set rmstar

# Enabled "complete" to "enhance"
# If you have a file called "complete.tcs" and you
# want to edit it, do "vi c.t<TAB>" and that's it
    set complete = enhance

# Keybindings
    bindkey " "  magic-space
    bindkey "" complete-word-fwd

    bindkey -k up   history-search-backward
    bindkey -k down history-search-forward

    bindkey -s "^x" "exit^M"

    set ignoreeof  # prevent accidental shell termination

# History
    set history = 10000
    set savehist = (10000 merge)
    set histfile = ~/.history

# Colors
#setenv LS_COLORS "rs=0:di=01;34:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=40;31;01:mi=01;05;37;41:su=37;41:sg=30;43:ca=30;41:tw=30;42:ow=34;42:st=37;44:ex=01;00:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.lzma=01;31:*.tlz=01;31:*.txz=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.dz=01;31:*.gz=01;31:*.lz=01;31:*.xz=01;31:*.bz2=01;31:*.tbz=01;31:*.tbz2=01;31:*.bz=01;31:*.tz=01;31:*.deb=01;31:*.rpm=01;31:*.jar=01;31:*.war=01;31:*.ear=01;31:*.sar=01;31:*.rar=01;31:*.ace=01;31:*.zoo=01;31:*.cpio=01;31:*.7z=01;31:*.rz=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.pbm=01;35:*.pgm=01;35:*.ppm=01;35:*.tga=01;35:*.xbm=01;35:*.xpm=01;35:*.tif=01;35:*.tiff=01;35:*.png=01;35:*.svg=01;35:*.svgz=01;35:*.mng=01;35:*.pcx=01;35:*.mov=01;35:*.mpg=01;35:*.mpeg=01;35:*.m2v=01;35:*.mkv=01;35:*.ogm=01;35:*.mp4=01;35:*.m4v=01;35:*.mp4v=01;35:*.vob=01;35:*.qt=01;35:*.nuv=01;35:*.wmv=01;35:*.asf=01;35:*.rm=01;35:*.rmvb=01;35:*.flc=01;35:*.avi=01;35:*.fli=01;35:*.flv=01;35:*.gl=01;35:*.dl=01;35:*.xcf=01;35:*.xwd=01;35:*.yuv=01;35:*.cgm=01;35:*.emf=01;35:*.axv=01;35:*.anx=01;35:*.ogv=01;35:*.ogx=01;35:*.aac=01;36:*.au=01;36:*.flac=01;36:*.mid=01;36:*.midi=01;36:*.mka=01;36:*.mp3=01;36:*.mpc=01;36:*.ogg=01;36:*.ra=01;36:*.wav=01;36:*.axa=01;36:*.oga=01;36:*.spx=01;36:*.xspf=01;36:*.pdf=00;33:*.ps=00;33:*.ps.gz=00;33:*.txt=00;33:*.patch=00;33:*.diff=00;33:*.log=00;33:*.tex=00;33:*.xls=00;33:*.xlsx=00;33:*.ppt=00;33:*.pptx=00;33:*.rtf=00;33:*.doc=00;33:*.docx=00;33:*.odt=00;33:*.ods=00;33:*.odp=00;33:*.xml=00;33:*.epub=00;33:*.abw=00;33:*.htm=00;33:*.html=00;33:*.shtml=00;33:*.wpd=00;33:"
    setenv LS_COLORS 'no=00:fi=00:di=01;97:ow=01;97:st=01;97:tw=01;97:ln=01;36:pi=40;33:so=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=00;00;00;41:ex=01;32:*.cmd=01;32:*.exe=01;32:*.com=01;32:*.btm=01;32:*.bat=01;32:*.sh=01;32:*.csh=01;32:*.tar=01;31:*.tgz=01;31:*.arj=01;31:*.taz=01;31:*.lzh=01;31:*.zip=01;31:*.z=01;31:*.Z=01;31:*.gz=01;31:*.bz2=01;31:*.bz=01;31:*.tz=01;31:*.rpm=01;31:*.cpio=01;31:*.jpg=01;35:*.jpeg=01;35:*.gif=01;35:*.bmp=01;35:*.xbm=01;35:*.xpm=01;35:*.png=01;35:*.tif=01;35:*.r=01;35:*.map=01;35:*.adb=01;98:*.pdf=01;35'

    # EDITOR
    setenv EDITOR nvim

    # P4 Diff
    setenv P4DIFF meld

    source ~/.aliases

    setenv GRADLEPATH           /opt/gradle
    setenv GOPATH               $HOME/go
    setenv BUNPATH               $HOME/.bun/
    setenv DARTPATH             /usr/lib/dart
    setenv GOOGLEDARTPATH       /usr/lib/google-dartlang
    setenv CARGOPATH            $HOME/.cargo
    setenv PYENVPATH            $HOME/.pyenv
    setenv MISEPATH             $HOME/.local/share/mise/shims

    setenv PNPM_HOME            $HOME/.pnpm
    setenv ANDROID_HOME         $HOME/Android/Sdk
    setenv ANDROID_NDK_HOME     $HOME/Android/Ndk
    setenv ANDROID_SDK_ROOT     $HOME/Android/Sdk
    setenv ANDROID_VER          30.0.2

    setenv BREWPATH /home/linuxbrew/.linuxbrew

    # Build PATH with only existing directories
    if ( ! $?__MY_PATHS_ARE_SET ) then
        set new_path = ""

        # Add each directory only if it exists
        if (-d ${GRADLEPATH}/bin) set new_path = "${new_path}:${GRADLEPATH}/bin"
        if (-d ${MISEPATH}) set new_path = "${new_path}:${MISEPATH}"
        if (-d ${CARGOPATH}/bin) set new_path = "${new_path}:${CARGOPATH}/bin"
        if (-d ${PYENVPATH}/bin) set new_path = "${new_path}:${PYENVPATH}/bin"
        if (-d ${BREWPATH}/bin) set new_path = "${new_path}:${BREWPATH}/bin"
        if (-d ${GOPATH}/bin) set new_path = "${new_path}:${GOPATH}/bin"
        if (-d ${PNPM_HOME}) set new_path = "${new_path}:${PNPM_HOME}"
        if (-d ${BUNPATH}/bin) set new_path = "${new_path}:${BUNPATH}/bin"
        if (-d ${DARTPATH}/bin) set new_path = "${new_path}:${DARTPATH}/bin"
        if (-d ${GOOGLEDARTPATH}/bin) set new_path = "${new_path}:${GOOGLEDARTPATH}/bin"
        if (-d ${ANDROID_HOME}/emulator) set new_path = "${new_path}:${ANDROID_HOME}/emulator"
        if (-d ${ANDROID_HOME}/tools/bin) set new_path = "${new_path}:${ANDROID_HOME}/tools/bin"
        if (-d ${ANDROID_HOME}/platform-tools) set new_path = "${new_path}:${ANDROID_HOME}/platform-tools"
        if (-d ${ANDROID_HOME}/build-tools/${ANDROID_VER}) set new_path = "${new_path}:${ANDROID_HOME}/build-tools/${ANDROID_VER}"
        if (-d ${HOME}/.pub-cache/bin) set new_path = "${new_path}:${HOME}/.pub-cache/bin"
        if (-d ${HOME}/bin) set new_path = "${new_path}:${HOME}/bin"
        if (-d ${HOME}/.local/bin) set new_path = "${new_path}:${HOME}/.local/bin"
        if (-d /usr/sbin) set new_path = "${new_path}:/usr/sbin"

        # Remove leading colon and append to existing PATH
        setenv PATH `echo $new_path | sed 's/^://'`:${PATH}

        unset new_path
        setenv __MY_PATHS_ARE_SET 1
    endif

    #setenv PYTHONPATH $HOME/.local/lib/python2.7/site-packages:/usr/local/buildtools/current/sitecustomize

    setenv PIPENV_PYTHON $HOME/.pyenv/shims/python

    # Use public PyPI for uv/uvx to bypass corporate registry
    setenv UV_INDEX_URL https://pypi.org/simple/

    setenv LD_LIBRARY_PATH /lib:/usr/lib:/usr/local/lib

    # cd completions should ignore blaze directories
    complete cd 'p/1/d:^{blaze-bin,blaze-genfiles,blaze-google3,blaze-out,blaze-testlogs,READONLY}/'

    complete sudo 'p/1/c/'
    complete kill 'p/*/`ps -eo pid`/'

# After a 'Ctrl-Z', list all the jobs
    set listjobs

    # Set Caps Lock to Ctrl
    #
    # if Caps Lock gets stuck in "on" position, run `setxkbmap -option` to undo the following line
    #setxkbmap -option caps:ctrl_modifier
    #~/.xsession


# Synaptics
# This has to be done because my touchpad kinda broke after update to 15.10
#    # Speed up 2 finger scroll speed
#    synclient VertScrollDelta=50
#    synclient HorizScrollDelta=50
#
#    # 1 finger = Click
#    synclient TapButton1=1
#    # 2 finger = Right Click Menu
#    synclient TapButton2=3
#    # 3 finger = Middle
#    synclient TapButton3=2


# Various usage statistics set with the time command.
# Do "man tcsh" to find about more data that can be shown here.
# Only shows for commands taking > 8 seconds
    set time=(8 "\
─────────────────────────────────────────\
  Elapsed time       : %Es\
  CPU usage          : %P\
  User / System time : %Us / %Ss\
  Memory (max RSS)   : %Mk\
  I/O operations     : %I+%O (in+out)\
─────────────────────────────────────────\
    ")

    if ($?STY) then
        # Inside a screen session. Do nothing
    else if ($?SSH_CLIENT) then
        # Inside an ssh session. Do nothing
    else
        # A blank terminal session.
        # get or create a new session named 'mainsession'
        scrn -x -R -S default
    endif

#eval `starship init tcsh`

source ~/.prompt

# Setup our precmd; this gets executed before every prompt
alias precmd 'source ~/.precmd'

# cwdcmd gets executed after every cd
alias cwdcmd 'source ~/.cwdcmd'
