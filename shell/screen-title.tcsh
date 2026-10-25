#
# screen-title.tcsh — tell screen what each window is doing.
#
# .cshrc sources this inside screen, after twig has set precmd and postcmd, and
# it adds to the end of both. Each window then carries two strings for the
# status line:
#
#   title       the folder's name, for the window list         nuscreen
#   hardstatus  for the pane's caption: the command while it   nuscreen: cargo build
#               runs, then a failure and how long it took      nuscreen exit 101 4.1s
#
# postcmd sets the running command itself; precmd hands the rest to
# bin/scrn-title. Both stay one-line aliases: tcsh runs postcmd before every
# line of a sourced file, so a hook that sourced a file would set itself off.
#
# The exit status is twig's $_twst: its part of precmd runs first and saves
# $status before anything else changes it. Without twig there is no badge.
#

# postcmd also fires for each line .cshrc runs after this; _scrn_on keeps it
# quiet until the first prompt, so a new window doesn't open on a stale command.
set _scrn_t0 = ""
set _scrn_on = 0
if (! $?_twst) set _twst = ""

alias _scrn_precmd '~/dotfiles/bin/scrn-title "$cwd" "$_twst" "$_scrn_t0"; set _scrn_t0 = ""; set _scrn_on = 1'
alias _scrn_postcmd 'if ($_scrn_on) set _scrn_t0 = `date +%s%3N`; if ($_scrn_on) ~/dotfiles/bin/scrn-title -r "$cwd" "`history -h 1`"'

if ("`alias precmd`" == "") then
    alias precmd _scrn_precmd
else
    alias precmd "`alias precmd`; _scrn_precmd"
endif
if ("`alias postcmd`" == "") then
    alias postcmd _scrn_postcmd
else
    alias postcmd "`alias postcmd`; _scrn_postcmd"
endif
