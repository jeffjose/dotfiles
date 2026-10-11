<p>
  <a href="jeffreyjose.com">
    <img alt="jeffjose's dotfiles" src="https://raw.github.com/jeffjose/dotfiles/master/banner.png">
  </a>
</p>

## A new machine

```sh
curl -fsSL https://raw.githubusercontent.com/jeffjose/dotfiles/master/scripts/install/firstrun | bash -s -- server
```

or `desktop` in place of `server`. That clones this repo to `~/dotfiles` and
runs [`scripts/install/firstrun`](scripts/install/firstrun) from it. With the
repo already cloned, run `firstrun` directly; with no profile given, it asks.

| Profile   | For                                   | Gets                                                                                   |
| --------- | ------------------------------------- | -------------------------------------------------------------------------------------- |
| `server`  | machines that never run anything graphical | a small apt list, tcsh, the shell/git/editor config, mise with its core tools, an ssh key |
| `desktop` | desktops and laptops                  | all of that, plus the desktop apt list, every mise tool, fonts, Chrome, VS Code, terminal setup |

The answers are recorded in `~/.config/dotfiles/host.conf`, which is per-machine
and not in this repo. Every step can be repeated: `firstrun --list` shows them,
`firstrun --only mise` runs one, `firstrun --dry-run` changes nothing. FreeBSD
has [`firstrun-bsd`](scripts/install/firstrun-bsd).

## Where things are decided

| What                         | Where                                                        |
| ---------------------------- | ------------------------------------------------------------ |
| apt packages                 | [`packages/`](packages) — `apt-server.txt`, `apt-desktop.txt` |
| mise tools, every machine    | [`apps/config.toml`](apps/config.toml)                       |
| mise tools, desktops only    | [`apps/mise-desktop.toml`](apps/mise-desktop.toml)           |
| kept off corp hosts          | [`apps/mise-corp.toml`](apps/mise-corp.toml)                 |
| AppImages                    | [`scripts/utils/appimage-catalog.tsv`](scripts/utils/appimage-catalog.tsv) |
| debs from outside apt        | [`misc/package.toml`](misc/package.toml)                     |
| directories and symlinks     | [`setup`](setup)                                             |

## Day to day

`uq` pulls this repo, re-runs `setup`, and updates everything above that the
machine's profile has.

The three scripts that get run by hand are at the root of the repo:
[`./setup`](setup), [`./firstrun`](firstrun) and [`./update_mise`](update_mise)
— the last two are links into `scripts/`.
