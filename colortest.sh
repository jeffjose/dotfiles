#!/bin/sh
echo "--- TERM variable ---"
echo "TERM = $TERM"
echo ""
echo "--- terminfo details from infocmp ---"
# Use the local infocmp if it exists, otherwise use the system one
if [ -x "$HOME/.local/bin/infocmp" ]; then
    "$HOME/.local/bin/infocmp" "$TERM"
else
    infocmp "$TERM"
fi
echo ""
echo "--- Color Test ---"
awk 'BEGIN{
    s="/\\/\\/\\/\\/\\"; s=s s;
    for (colnum = 0; colnum<77; colnum++) {
        r = 255-(colnum*255/76);
        g = (colnum*510/76);
        b = (colnum*255/76);
        if (g>255) g = 510-g;
        printf "\033[48;2;%d;%d;%dm", r,g,b;
        printf "\033[38;2;%d;%d;%dm", 255-r,255-g,255-b;
        printf "%s\033[0m", substr(s,colnum+1,1);
    }
    printf "\n";
}'
