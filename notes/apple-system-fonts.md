# How to setup -apple-system on ubuntu

1. Install `fonttools`

```bash
$ pip install fonttools
```

2. Rename fonts

```bash

# Convert fonts to ttx files
$ ttx *otf

# Rename fonts
$ sed -i 's/FONT_NAME/-apple-system/g' *ttx

```

3. Install fonts

```bash
# Convert to otf and copy to fonts folder
$ ttx -d ~/.local/share/fonts *ttx

# rebuild cache
$ fc-cache -f -v
```

4. Verify results

```bash

$ fc-list | grep apple
/home/jeffjose/.local/share/fonts/apple-system-RegularItalic.otf: \-apple\-system:style=Italic
/home/jeffjose/.local/share/fonts/apple-system-SemiboldItalic.otf: \-apple\-system:style=Semibold Italic
/home/jeffjose/.local/share/fonts/apple-system-HeavyItalic.otf: \-apple\-system:style=Heavy Italic
/home/jeffjose/.local/share/fonts/apple-system-MediumItalic.otf: \-apple\-system:style=Medium Italic
/home/jeffjose/.local/share/fonts/apple-system-BoldItalic.otf: \-apple\-system:style=Bold Italic
/home/jeffjose/.local/share/fonts/apple-system-Light.otf: \-apple\-system:style=Light
/home/jeffjose/.local/share/fonts/apple-system-Regular.otf: \-apple\-system:style=Regular
/home/jeffjose/.local/share/fonts/apple-system-Heavy.otf: \-apple\-system:style=Heavy
/home/jeffjose/.local/share/fonts/apple-system-Semibold.otf: \-apple\-system:style=Semibold
/home/jeffjose/.local/share/fonts/apple-system-Medium.otf: \-apple\-system:style=Medium
/home/jeffjose/.local/share/fonts/apple-system-Bold.otf: \-apple\-system:style=Bold
/home/jeffjose/.local/share/fonts/apple-system-LightItalic.otf: \-apple\-system:style=Light Italic
```
