<p align="center">
  <img width="200" src="res/middleclick-autoscroll.svg" alt="middleclick-autoscroll">
</p>

<h1 align="center">middleclick-autoscroll</h1>

<h3 align="center">Middle-click autoscroll in every app that supports it.</h3>

<p align="center">
  Browsers, Electron apps like Discord and Spotify, Steam and anything else built on Chromium.
</p>

<h5 align="center">
  <a href="#install">Install</a> |
  <a href="#how-to-use">How to use</a> |
  <a href="https://github.com/LoonixTools/middleclick-autoscroll/issues">Report a bug</a>
</h5>

<p align="center">
  <a href="https://buymeacoffee.com/felitendo"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="48"></a>
</p>

## Install

<details>
<summary><b>Arch</b></summary>

```bash
yay -S middleclick-autoscroll
```

</details>

<details>
<summary><b>Fedora</b></summary>

```bash
sudo curl -fsSL -o /etc/yum.repos.d/middleclick-autoscroll.repo \
  https://loonixtools.github.io/middleclick-autoscroll/middleclick-autoscroll.repo
sudo dnf install middleclick-autoscroll
```

</details>

<details>
<summary><b>Bazzite</b></summary>

```bash
sudo curl -fsSL -o /etc/yum.repos.d/middleclick-autoscroll.repo \
  https://loonixtools.github.io/middleclick-autoscroll/middleclick-autoscroll.repo
sudo rpm-ostree install middleclick-autoscroll
systemctl reboot
```

</details>

<details>
<summary><b>Debian</b>, Ubuntu</summary>

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://loonixtools.github.io/middleclick-autoscroll/KEY.gpg \
  | sudo gpg --dearmor -o /etc/apt/keyrings/middleclick-autoscroll.gpg
echo "deb [signed-by=/etc/apt/keyrings/middleclick-autoscroll.gpg] https://loonixtools.github.io/middleclick-autoscroll/deb ./" \
  | sudo tee /etc/apt/sources.list.d/middleclick-autoscroll.list
sudo apt update && sudo apt install middleclick-autoscroll
```

</details>

<details>
<summary><b>openSUSE</b></summary>

```bash
sudo rpm --import https://loonixtools.github.io/middleclick-autoscroll/KEY.gpg
sudo zypper addrepo --gpgcheck --refresh \
  https://loonixtools.github.io/middleclick-autoscroll/rpm middleclick-autoscroll
sudo zypper install middleclick-autoscroll
```

</details>

## How to use

```bash
middleclick-autoscroll
```

<p align="center">
  <img src="res/screenshots/menu.png" alt="The middleclick-autoscroll menu in Konsole: autoscroll on, 19 of 19 applications covered" width="620">
</p>

Press **1**. Autoscroll _✨just works✨_, like on Windows.

<details>
<summary>Applications</summary>

**3** lists every app it found. Type to search, then Space turns one on or off.

<p align="center">
  <img src="res/screenshots/applications.png" alt="The applications list in Konsole, each with how it gets autoscroll" width="620">
</p>

</details>

## More

<details>
<summary>How it works</summary>

Chromium, Electron and CEF all have autoscroll built in. On Linux it is off, because middle click
pastes there. One flag turns it back on:

```
--enable-blink-features=MiddleClickAutoscroll
```

Adding it to every app by hand is a pain, and updates can undo it. This tool does it for you:

- It finds every app built on Chromium. AppImages too, without unpacking or starting them.
- It puts the flag where the app reads it: the app's flags file, or a copy of its menu entry in
  your home folder.
- It watches for new apps and covers them on their own.
- It only writes to your home folder, and `disable` puts everything back.

**Browsers** get a spelling of the flag that shows no warning bar. Brave and Helium also get their
own name for the feature. A browser ignores names it does not know.

**Steam** builds its own command line and repairs any file that looks changed. So the flag goes into
the script that starts its web helper, and the file keeps the size and date Steam expects. Steam
finds nothing to repair, and autoscroll works in the store and the library. After a Steam update,
the patch comes back on its own.

</details>

<details>
<summary>Commands</summary>

| | |
|---|---|
| `middleclick-autoscroll` | The menu |
| `… enable` | Turn on |
| `… disable` | Undo everything |
| `… apply` | Pick up new apps |
| `… status` | What is covered |
| `… list` | All apps and how they are handled |

</details>

<details>
<summary>Build from source</summary>

```bash
make
sudo make install
```

Optional: `msgfmt` for translations, `scdoc` for the man page.

</details>

GPL-3.0-or-later.
