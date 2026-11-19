# Chicago95 installer

`install-chicago95.sh` installs the [Chicago95](https://github.com/grassmunk/Chicago95) theme system-wide on an Xfce desktop. It activates the theme for the current user and makes it the default for every account created afterwards. Every step follows the manual instructions in Chicago95's [INSTALL.md](https://github.com/grassmunk/Chicago95/blob/master/INSTALL.md), pinned to commit `5da19b8`.

The script is plain POSIX `sh` and has no distro-specific package commands. It has been tested with `dash` and BusyBox `ash`.

## Usage

Run it as your normal user. It asks for `sudo` or `doas` when it needs root rights.

```bash
sh install-chicago95.sh
```

You can run it in two places:

- **From a terminal inside your Xfce session:** the theme switches right away. Log out and back in afterwards so every running application picks it up.
- **From a TTY or over SSH while you're logged out of Xfce:** the script writes your settings directly, and they take effect at your next Xfce login.

If you're logged into Xfce and run the script from outside that session, it refuses. The running session would otherwise overwrite the new settings.

## Requirements

Before it changes anything, the script checks that the following are installed. If anything is missing, it lists what's missing and exits.

- Xfce: `xfce4-session`, `xfce4-settings`, `xfconf`, `xfwm4`, `xfce4-panel`, `xfdesktop`, `xfce4-notifyd` and the Whisker Menu plugin
- Thunar, Xfce Terminal, Flatpak and the LightDM GTK greeter
- LibreOffice with its GTK 3 integration (`libvclplug_gtk3lo.so`, packaged as `libreoffice-gtk3` on many distros)
- The libcanberra GTK 3 module and Fontconfig
- `dbus-run-session`, `xrandr`, `pgrep`, `tar`, `gzip`, `zip`, `curl` or `wget`, and `sudo` or `doas`

It also stops without changes in two more cases:

- Any path it would write belongs to an installed package. It checks this with `dpkg`, `rpm`, `pacman`, `xbps`, `apk` or `qfile`.
- `/etc/lightdm/lightdm-gtk-greeter.conf` sets the greeter's theme, icons, cursor, font or background. The greeter reads that file after every drop-in, so those lines would win over Chicago95.

## What gets applied

| INSTALL.md section | What the script does |
| --- | --- |
| System-wide install | Copies the GTK theme to `/usr/share/themes`, and the icon and cursor themes to `/usr/share/icons` |
| LightDM font, Terminal fonts | Installs the DOS VGA fonts to `/usr/share/fonts/chicago95` and refreshes the font cache |
| MS Sans Serif font | Installs the cronyx-cyrillic Helvetica bitmap font instead and sets it as `Helvetica 8` for the interface and `Helvetica Bold 8` for window titles |
| Enabling the GTK, icon, window manager and notification themes | Sets the theme, icons and 100% notification opacity |
| XFCE4 panelbar (horizontal) | Builds the taskbar from the manual steps: Whisker Menu, Show Desktop, window buttons, notification area and clock |
| Start Buttons | Gives the Whisker Menu button the Tux icon from the `Chicago95-tux` icon theme and a "Start" label |
| GTK3 override | Adds the override for your Xfce version to `~/.config/gtk-3.0/gtk.css` |
| Flatpak | Adds a per-user override that exposes the theme |
| Overlay scrollbars | Turns overlay scrolling off through Xfce's `Gtk/OverlayScrolling` setting |
| Desktop shadows, background color | Turns off xfwm4 shadows and sets a solid `#008080` desktop on every monitor connected at login |
| Cursors | Selects `Chicago95_Standard_Cursors` |
| Terminal theme | Applies the Chicago95 colors and the `Less Perfect DOS VGA 12` font without bold text |
| Sound theme | Selects the Chicago95 sound theme and turns on event and input feedback sounds |
| LightDM GTK greeter (not in INSTALL.md) | Adds `/etc/lightdm/lightdm-gtk-greeter.conf.d/99-chicago95.conf` with the Chicago95 theme, icons, cursor, Helvetica font and teal background |
| LibreOffice (not in INSTALL.md) | Builds the icon theme from `Extras/libreoffice-chicago95-iconset` and makes it the default for every user. The GTK 3 integration gives LibreOffice the Chicago95 widgets |

Only the Helvetica files from the cronyx-cyrillic folder are installed, so requests for Times, Courier or Fixed keep their usual fonts. Many distros hide bitmap fonts with a `70-no-bitmaps` fontconfig rule. `/etc/fonts/conf.d/70-chicago95-helvetica.conf` whitelists just this font, so other bitmap fonts stay hidden.

New accounts get the same settings through `/etc/skel`. The desktop background is stored per monitor and needs the monitor names from `xrandr`, so a one-time autostart entry sets it on the user's first login and then removes itself. The same entry handles your own account when you run the script from a TTY.

## What gets skipped

- **Microsoft branding:** Windows start button badges, Thunar status badge, DOS prompt and startup message for Bash and zsh, MS-DOS terminal title and cursor, Whisker Menu sidebar image and the Windows 95 startup sound
- **libadwaita applications:** left in their own style on purpose. Plain GTK 4 applications still pick up Chicago95 through the theme name. Running the script again removes the GTK4 `@import` block and the Flatpak `GTK_THEME` override that earlier versions added
- **Known problems in INSTALL.md:**
  - Qt5 and qt5ct: missing scrollbar borders with no fix
  - MS Sans Serif font: the Microsoft font isn't included
  - HiDPI: marked experimental
  - Disabling client-side decorations: needs distro-specific forks that may have to be built by hand
  - GNOME Shell theme: not maintained
  - Global `GTK_THEME`: INSTALL.md says not to set it
  - Snap: no fix exists
- **Not applicable:**
  - Launcher icon scaling: only for the Xfce 4.12 panel
  - compton: no longer packaged, so xfwm4's own compositor is configured instead
  - Separate Indicator plugin: the notification area shows indicators since Xfce 4.16
  - LightDM webkit greeter, Plymouth and KDE themes: not covered by INSTALL.md

## Why updates can't undo it

- The script only adds new files and never edits files owned by the package manager.
- All settings live in the user's own xfconf store, which takes priority over the distro defaults in `/etc/xdg`.
- The greeter settings use a drop-in file that is read after the distro's own drop-ins, so the package's `lightdm-gtk-greeter.conf` stays untouched.
- The Helvetica bitmap font is whitelisted with its own fontconfig drop-in, so the package-owned `70-no-bitmaps` rule stays untouched.
- LibreOffice gets two new files next to its own: `share/config/images_chicago95.zip` and `share/registry/chicago95.xcd`. LibreOffice loads every `.xcd` file in that folder, and updates leave unknown files alone. A user who picks another icon theme in LibreOffice keeps that choice.
- Overlay scrolling uses an Xfce setting instead of `~/.xsessionrc`, which only Debian reads.
- Each user gets a copy of the GTK theme in `~/.local/share/themes`. Flatpak blocks `/usr/share/themes`, and GTK 4.22 deprecates `~/.themes`.

## Backups and undo

On the first run the script saves your existing files next to the originals:

- `backup.gtk.css.chicago95` in `~/.config/gtk-3.0`
- `backup.terminalrc.chicago95` in `~/.config/xfce4/terminal`
- `backup.xfce4-panel.xml.chicago95` in `~/.config/xfce4/xfconf/xfce-perchannel-xml`
- `backup.panel.chicago95` in `~/.config/xfce4`

To remove the theme system-wide, delete these paths:

- `/usr/share/themes/Chicago95`
- `/usr/share/icons/Chicago95*`
- `/usr/share/sounds/Chicago95`
- `/usr/share/fonts/chicago95`
- `/etc/fonts/conf.d/70-chicago95-helvetica.conf`
- `/usr/share/xfce4/terminal/colorschemes/Chicago95.theme`
- `images_chicago95.zip` and `chicago95.xcd` in LibreOffice's `share/config` and `share/registry` folders
- `/usr/local/libexec/chicago95-first-login`
- `/etc/lightdm/lightdm-gtk-greeter.conf.d/99-chicago95.conf`
- the Chicago95 files the script added to `/etc/skel`
