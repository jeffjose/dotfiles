# Shell integration for jot (~/scripts/jot): marks where each prompt,
# command and its output start and end (OSC 133), and which folder the
# shell is in (OSC 7). jot builds on them: the bar beside each command
# with its exit status and time, Ctrl Shift Up and Down from prompt to
# prompt, a notice when a long command ends out of sight, a command's
# output selected in one go, and the long-command editor.
#
# .cshrc sources this when TERM_PROGRAM is jot, after twig has set
# precmd and postcmd: these add to them, as screen-title.tcsh does.

set _jt_e = "`printf '\033'`"
set _jt_b = "`printf '\007'`"

# Before each prompt: the last command ended, with its status (twig saves
# it in $_twst first; without twig this saves it), then a prompt starts.
# (tcsh will not print the mark for where typing begins from a prompt,
# so jot takes it as where the cursor is at the first key.)
if ("`alias precmd`" !~ *_twst*) then
    alias precmd "set _twst = \$status; `alias precmd`"
endif
alias _jt_precmd 'printf "%s]133;D;%s%s%s]7;file://%s%s%s%s]133;A%s" "$_jt_e" "$_twst" "$_jt_b" "$_jt_e" "$HOST" "$cwd" "$_jt_b" "$_jt_e" "$_jt_b"'
# After Enter, before the command runs: its output starts.
alias _jt_postcmd 'printf "%s]133;C%s" "$_jt_e" "$_jt_b"'

if ("`alias precmd`" == "") then
    alias precmd _jt_precmd
else
    alias precmd "`alias precmd`; _jt_precmd"
endif
if ("`alias postcmd`" == "") then
    alias postcmd _jt_postcmd
else
    alias postcmd "`alias postcmd`; _jt_postcmd"
endif
