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
echo "--- Basic 16 Colors ---"
for color in {0..15}; do
    printf "\033[48;5;%dm  " "$color"
done
printf "\033[0m\n"

echo ""
echo "--- RGB Rainbow Gradient ---"
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

echo ""
echo "--- Grayscale Gradient ---"
awk 'BEGIN{
    s="█";
    for (i = 0; i <= 25; i++) {
        gray = i * 10;
        printf "\033[48;2;%d;%d;%dm%s", gray, gray, gray, s;
    }
    printf "\033[0m\n";
}'

echo ""
echo "--- Red to Blue Gradient ---"
awk 'BEGIN{
    s="▓";
    for (i = 0; i < 50; i++) {
        r = 255 - (i * 5);
        b = i * 5;
        printf "\033[48;2;%d;0;%dm%s", r, b, s;
    }
    printf "\033[0m\n";
}'

echo ""
echo "--- 256 Color Palette (6x6x6 cube) ---"
for i in {16..231}; do
    printf "\033[48;5;%dm  \033[0m" "$i"
    if [ $(((i - 16 + 1) % 36)) -eq 0 ]; then
        echo ""
    elif [ $(((i - 16 + 1) % 6)) -eq 0 ]; then
        printf " "
    fi
done

echo ""
echo "--- Grayscale Ramp (colors 232-255) ---"
for i in {232..255}; do
    printf "\033[48;5;%dm  \033[0m" "$i"
done
printf "\n"
