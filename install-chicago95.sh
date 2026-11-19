#!/bin/sh
set -eu

CHICAGO95_COMMIT=5da19b8b1e2a886ebf6628403023d5fac3acc3ee
CHICAGO95_ARCHIVE="https://github.com/grassmunk/Chicago95/archive/$CHICAGO95_COMMIT.tar.gz"
CURSOR_THEME=Chicago95_Standard_Cursors
TERMINAL_FONT="Less Perfect DOS VGA 12"
DESKTOP_COLOR="0 0.501961 0.501961 1"
GTK4_HELPER=/usr/local/libexec/chicago95-gtk4-setup
GTK4_AUTOSTART=.config/autostart/chicago95-gtk4-setup.desktop
START_ICON=/usr/share/icons/Chicago95-tux/places/16/start-here.png
GREETER=/usr/share/xgreeters/lightdm-gtk-greeter.desktop
GREETER_MAIN_CONFIG=/etc/lightdm/lightdm-gtk-greeter.conf
GREETER_CONFIG=/etc/lightdm/lightdm-gtk-greeter.conf.d/99-chicago95.conf
CHANNELS="xsettings xfwm4 xfce4-notifyd xfce4-desktop xfce4-panel xfce4-terminal"

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }
has_lib() { find /usr/lib /usr/lib64 /usr/lib32 /lib /lib64 /usr/local/lib -maxdepth 4 -name "$1" 2>/dev/null | grep -q .; }

missing=""
need_command() { has "$2" || missing="$missing  - $1 (command $2)
"; }
need_lib() { has_lib "$2" || missing="$missing  - $1 (library $2)
"; }

check_components() {
  need_command "Xfce session manager" xfce4-session
  need_command "Xfce settings daemon" xfsettingsd
  need_command "Xfconf" xfconf-query
  need_command "Xfwm4 window manager" xfwm4
  need_command "Xfce panel" xfce4-panel
  need_command "Whisker Menu panel plugin" xfce4-popup-whiskermenu
  need_command "Xfdesktop" xfdesktop
  need_command "Xfce notification daemon" xfce4-notifyd-config
  need_command "Thunar" thunar
  need_command "Xfce Terminal" xfce4-terminal
  need_command "Flatpak" flatpak
  [ -f "$GREETER" ] || missing="$missing  - LightDM GTK greeter (file $GREETER)
"
  need_lib "GTK 4" libgtk-4.so.1
  need_lib "libcanberra GTK 3 module for event sounds" libcanberra-gtk3-module.so
  need_command "Fontconfig" fc-cache
  need_command "D-Bus" dbus-run-session
  need_command "xrandr" xrandr
  need_command "pgrep" pgrep
  need_command "tar" tar
  need_command "gzip" gzip
  has curl || has wget || missing="$missing  - curl or wget
"
  has sudo || has doas || missing="$missing  - sudo or doas
"
  [ -z "$missing" ] || {
    printf 'These components are missing. Install them and run the script again. Nothing was changed.\n%s' "$missing" >&2
    exit 1
  }
}

session_bus_available() {
  [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -S "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus" ]
}

check_session() {
  if [ -z "${DISPLAY:-}" ] || ! session_bus_available || ! pgrep -u "$(id -u)" -x xfce4-session >/dev/null 2>&1 ||
    ! xfconf-query -c xfwm4 -l >/dev/null 2>&1 || ! xrandr --query >/dev/null 2>&1; then
    die "Run this script from a terminal inside your Xfce session. Nothing was changed."
  fi
}

check_greeter_config() {
  overrides=$(grep -E '^[[:space:]]*(theme-name|icon-theme-name|cursor-theme-name|background)[[:space:]]*=' "$GREETER_MAIN_CONFIG" 2>/dev/null || true)
  [ -z "$overrides" ] || {
    printf '%s sets these keys. LightDM GTK greeter reads that file after every drop-in, so Chicago95 cannot override them without editing a file owned by the package. Comment them out and run the script again. Nothing was changed.\n%s\n' "$GREETER_MAIN_CONFIG" "$overrides" >&2
    exit 1
  }
}

owned_by_package() {
  { has dpkg-query && dpkg-query -S "$1" >/dev/null 2>&1; } ||
    { has rpm && rpm -qf "$1" >/dev/null 2>&1; } ||
    { has pacman && pacman -Qo "$1" >/dev/null 2>&1; } ||
    { has xbps-query && [ -n "$(xbps-query -o "$1" 2>/dev/null)" ]; } ||
    { has apk && apk info -W "$1" 2>/dev/null | grep -q 'owned by'; } ||
    { has qfile && qfile -q "$1" >/dev/null 2>&1; }
}

system_targets() {
  say /usr/share/themes/Chicago95
  for dir in "$src"/Icons/* "$src"/Cursors/*; do say "/usr/share/icons/${dir##*/}"; done
  say /usr/share/sounds/Chicago95
  say /usr/share/fonts/chicago95
  say /usr/share/xfce4/terminal/colorschemes/Chicago95.theme
  say "$GTK4_HELPER"
  say "$GREETER_CONFIG"
}

skel_targets() {
  for channel in $CHANNELS; do say "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/$channel.xml"; done
  say /etc/skel/.config/xfce4/terminal/terminalrc
  say /etc/skel/.config/gtk-3.0/gtk.css
  say "/etc/skel/$GTK4_AUTOSTART"
  say /etc/skel/.local/share/themes/Chicago95
  say /etc/skel/.local/share/flatpak/overrides/global
}

check_conflicts() {
  conflicts=$({ system_targets; skel_targets; } | while read -r path; do
    if owned_by_package "$path"; then say "  - $path"; fi
  done)
  [ -z "$conflicts" ] || {
    printf 'These paths belong to installed packages, so a package update would overwrite them. Remove the packages that own them and run the script again. Nothing was changed.\n%s\n' "$conflicts" >&2
    exit 1
  }
}

download() {
  if has curl; then curl -fsSL "$1"; else wget -qO- "$1"; fi
}

terminal_uses_xfconf() {
  xfce4-terminal --version 2>/dev/null | awk 'NR == 1 { split($2, v, "."); ok = v[1] > 1 || (v[1] == 1 && v[2] >= 1) } END { exit !ok }'
}

gtk3_override() {
  case "$(xfce4-panel --version 2>/dev/null)" in
    *"Xfce 4.12"*) say "$src/Extras/override/gtk-3.22/gtk.css" ;;
    *) say "$src/Extras/override/gtk-3.24/gtk.css" ;;
  esac
}

connected_monitors() {
  {
    xrandr --query | awk '$2 == "connected" { print $1 }'
    xfconf-query -c xfce4-desktop -l 2>/dev/null | sed -n 's#^/backdrop/screen0/monitor\([^/]*\)/workspace[0-9]*/.*#\1#p'
  } | sort -u
}

settings() {
  cat <<EOF
xsettings /Net/ThemeName string Chicago95
xsettings /Net/IconThemeName string Chicago95
xsettings /Gtk/CursorThemeName string $CURSOR_THEME
xsettings /Net/SoundThemeName string Chicago95
xsettings /Net/EnableEventSounds bool true
xsettings /Net/EnableInputFeedbackSounds bool true
xsettings /Gtk/OverlayScrolling bool false
xfwm4 /general/theme string Chicago95
xfwm4 /general/title_font string Sans Bold 8
xfwm4 /general/show_dock_shadow bool false
xfwm4 /general/show_frame_shadow bool false
xfwm4 /general/show_popup_shadow bool false
xfce4-notifyd /theme string Chicago95
xfce4-notifyd /initial-opacity double 1.0
xfce4-desktop /backdrop/single-workspace-mode bool true
xfce4-desktop /backdrop/single-workspace-number int 0
xfce4-panel /configver int 2
xfce4-panel /panels int[] 1
xfce4-panel /panels/panel-1/position string p=8;x=0;y=0
xfce4-panel /panels/panel-1/mode uint 0
xfce4-panel /panels/panel-1/size uint 32
xfce4-panel /panels/panel-1/nrows uint 1
xfce4-panel /panels/panel-1/length uint 100
xfce4-panel /panels/panel-1/position-locked bool true
xfce4-panel /panels/panel-1/autohide-behavior uint 0
xfce4-panel /panels/panel-1/background-style uint 0
xfce4-panel /panels/panel-1/icon-size uint 16
xfce4-panel /panels/panel-1/plugin-ids int[] 1 2 3 4 5 6 7 8 9
xfce4-panel /plugins/plugin-1 string whiskermenu
xfce4-panel /plugins/plugin-1/button-icon string $START_ICON
xfce4-panel /plugins/plugin-1/button-title string Start
xfce4-panel /plugins/plugin-1/show-button-icon bool true
xfce4-panel /plugins/plugin-1/show-button-title bool true
xfce4-panel /plugins/plugin-2 string separator
xfce4-panel /plugins/plugin-2/style uint 2
xfce4-panel /plugins/plugin-3 string showdesktop
xfce4-panel /plugins/plugin-4 string separator
xfce4-panel /plugins/plugin-4/style uint 2
xfce4-panel /plugins/plugin-5 string tasklist
xfce4-panel /plugins/plugin-5/flat-buttons bool false
xfce4-panel /plugins/plugin-5/show-handle bool false
xfce4-panel /plugins/plugin-5/sort-order uint 4
xfce4-panel /plugins/plugin-5/grouping bool false
xfce4-panel /plugins/plugin-6 string separator
xfce4-panel /plugins/plugin-6/style uint 0
xfce4-panel /plugins/plugin-6/expand bool true
xfce4-panel /plugins/plugin-7 string separator
xfce4-panel /plugins/plugin-7/style uint 2
xfce4-panel /plugins/plugin-8 string systray
xfce4-panel /plugins/plugin-8/icon-size int 16
xfce4-panel /plugins/plugin-8/show-frame bool false
xfce4-panel /plugins/plugin-9 string clock
xfce4-panel /plugins/plugin-9/mode uint 2
xfce4-panel /plugins/plugin-9/digital-layout uint 3
xfce4-panel /plugins/plugin-9/digital-time-format string %I:%M %p
xfce4-panel /plugins/plugin-9/digital-format string %I:%M %p
EOF
  for monitor in $monitors; do
    cat <<EOF
xfce4-desktop /backdrop/screen0/monitor$monitor/workspace0/color-style int 0
xfce4-desktop /backdrop/screen0/monitor$monitor/workspace0/rgba1 double[] $DESKTOP_COLOR
xfce4-desktop /backdrop/screen0/monitor$monitor/workspace0/image-style int 0
EOF
  done
  if $terminal_xfconf; then
    awk -v font="$TERMINAL_FONT" '
      /^Color/ { key = substr($0, 1, index($0, "=") - 1); gsub(/[A-Z]/, "-&", key)
                 print "xfce4-terminal /" tolower(substr(key, 2)) " string " substr($0, index($0, "=") + 1) }
      END { print "xfce4-terminal /font-name string " font; print "xfce4-terminal /font-allow-bold bool false" }
    ' "$src/Extras/Chicago95.theme"
  fi
}

xfconf_script() {
  cat <<'EOF'
set -e
xfconf-query -c xfce4-panel -p / -R -r
modules=$(xfconf-query -c xsettings -p /Gtk/Modules 2>/dev/null || true)
case ":$modules:" in
  *:canberra-gtk-module:*) ;;
  *) xfconf-query -c xsettings -p /Gtk/Modules -n -t string -s "${modules:+$modules:}canberra-gtk-module" ;;
esac
EOF
  settings | while read -r channel property type value; do
    case $type in
      *'[]')
        printf "xfconf-query -c %s -p '%s' -n -a" "$channel" "$property"
        for item in $value; do printf " -t %s -s '%s'" "${type%??}" "$item"; done
        printf '\n'
        ;;
      *) printf "xfconf-query -c %s -p '%s' -n -t %s -s '%s'\n" "$channel" "$property" "$type" "$value" ;;
    esac
  done
}

write_block() {
  mkdir -p "${1%/*}"
  [ -f "$1" ] || : >"$1"
  TAG=$2 BLOCK="/* >>> Chicago95 $2 BEGIN - managed by the Chicago95 installer, do not edit */
$3
/* <<< Chicago95 $2 END */" awk '
    index($0, ">>> Chicago95 " ENVIRON["TAG"] " BEGIN") { if (!done) print ENVIRON["BLOCK"]; done = 1; skip = 1; next }
    skip { if (index($0, "<<< Chicago95 " ENVIRON["TAG"] " END")) skip = 0; next }
    { print }
    END { if (!done) print ENVIRON["BLOCK"] }
  ' "$1" >"$1.chicago95-new"
  cat "$1.chicago95-new" >"$1"
  rm -f "$1.chicago95-new"
}

write_terminalrc() {
  mkdir -p "${1%/*}"
  {
    grep -v -E '^(Color(Foreground|Background|Selection|Cursor|Palette)|FontName|FontAllowBold)=' "$1" 2>/dev/null || say '[Configuration]'
    grep '^Color' "$src/Extras/Chicago95.theme"
    printf 'FontName=%s\nFontAllowBold=FALSE\n' "$TERMINAL_FONT"
  } >"$1.chicago95-new"
  cat "$1.chicago95-new" >"$1"
  rm -f "$1.chicago95-new"
}

flatpak_override() {
  XDG_DATA_HOME=$1 flatpak override --user --filesystem=xdg-data/themes:ro --filesystem=xdg-config/gtk-4.0:ro --env=GTK_THEME=Chicago95
}

backup_once() {
  backup="${1%/*}/backup.${1##*/}.chicago95"
  if [ -e "$1" ] && [ ! -e "$backup" ]; then cp -R "$1" "$backup"; fi
}

configure_files() {
  rm -rf "$2/themes/Chicago95"
  mkdir -p "$2/themes"
  cp -R "$src/Theme/Chicago95" "$2/themes/"
  write_block "$1/gtk-3.0/gtk.css" GTK3 "$(cat "$(gtk3_override)")"
  if ! $terminal_xfconf; then write_terminalrc "$1/xfce4/terminal/terminalrc"; fi
}

write_gtk4_helper() {
  cat >"$1" <<'EOF'
#!/bin/sh
config=${XDG_CONFIG_HOME:-$HOME/.config}
if ! grep -q '>>> Chicago95 GTK4 BEGIN' "$config/gtk-4.0/gtk.css" 2>/dev/null; then
  mkdir -p "$config/gtk-4.0"
  printf '%s\n@import url("file://%s/themes/Chicago95/gtk-4.0/gtk.css");\n%s\n' \
    '/* >>> Chicago95 GTK4 BEGIN - managed by the Chicago95 installer, do not edit */' \
    "${XDG_DATA_HOME:-$HOME/.local/share}" \
    '/* <<< Chicago95 GTK4 END */' >>"$config/gtk-4.0/gtk.css"
fi
rm -f "$config/autostart/chicago95-gtk4-setup.desktop"
EOF
}

write_greeter_config() {
  printf '[greeter]\ntheme-name=Chicago95\nicon-theme-name=Chicago95\ncursor-theme-name=%s\nbackground=#008080\n' "$CURSOR_THEME" >"$1"
}

stage_skel() {
  skel_targets | while read -r path; do
    if [ -f "$path" ]; then
      mkdir -p "$(dirname "$stage/${path#/etc/skel/}")"
      cp "$path" "$stage/${path#/etc/skel/}"
    fi
  done
  configure_files "$stage/.config" "$stage/.local/share"
  mkdir -p "$(dirname "$stage/$GTK4_AUTOSTART")"
  printf '[Desktop Entry]\nType=Application\nName=Chicago95 GTK4 setup\nExec=%s\nNoDisplay=true\n' "$GTK4_HELPER" >"$stage/$GTK4_AUTOSTART"
  flatpak_override "$stage/.local/share"
  rm -rf "$stage/.local/share/flatpak/repo" "$stage/.local/share/flatpak/.changed"
  running_xfconfd=" $(xfconfd_pids | tr '\n' ' ') "
  XDG_CONFIG_HOME="$stage/.config" LC_ALL=C dbus-run-session -- sh "$tmp/xfconf.sh" 2>"$tmp/xfconf.log" ||
    die "Could not prepare the settings for new users: $(cat "$tmp/xfconf.log") Nothing was changed."
  for pid in $(xfconfd_pids); do
    case $running_xfconfd in *" $pid "*) continue ;; esac
    tries=0
    while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt 30 ]; do sleep 1; tries=$((tries + 1)); done
  done
  for channel in $CHANNELS; do
    [ "$channel" = xfce4-terminal ] && ! $terminal_xfconf && continue
    [ -f "$stage/.config/xfce4/xfconf/xfce-perchannel-xml/$channel.xml" ] || die "Could not prepare the $channel settings for new users. Nothing was changed."
  done
  chmod -R u=rwX,go=rX "$stage"
}

install_system() {
  $ROOT sh -euc '
    umask 022
    src=$1 stage=$2 helper=$3 helper_target=$4 greeter=$5 greeter_target=$6
    install_dir() { rm -rf "$2/${1##*/}"; mkdir -p "$2"; cp -R "$1" "$2/"; chmod -R u=rwX,go=rX "$2/${1##*/}"; }
    install_dir "$src/Theme/Chicago95" /usr/share/themes
    for dir in "$src"/Icons/* "$src"/Cursors/*; do install_dir "$dir" /usr/share/icons; done
    install_dir "$src/sounds/Chicago95" /usr/share/sounds
    rm -rf /usr/share/fonts/chicago95
    mkdir -p /usr/share/fonts/chicago95 /usr/share/xfce4/terminal/colorschemes "${helper_target%/*}" "${greeter_target%/*}"
    cp "$src"/Fonts/vga_font/*.ttf /usr/share/fonts/chicago95/
    cp "$src/Extras/Chicago95.theme" /usr/share/xfce4/terminal/colorschemes/
    cp "$greeter" "$greeter_target"
    chmod 644 /usr/share/fonts/chicago95/* /usr/share/xfce4/terminal/colorschemes/Chicago95.theme "$greeter_target"
    cp "$helper" "$helper_target"
    chmod 755 "$helper_target"
    rm -rf /etc/skel/.local/share/themes/Chicago95
    cp -R "$stage/." /etc/skel/
    fc-cache -f
  ' sh "$src" "$stage" "$tmp/gtk4-helper" "$GTK4_HELPER" "$tmp/greeter.conf" "$GREETER_CONFIG"
}

panel_running() { pgrep -u "$(id -u)" -x xfce4-panel >/dev/null 2>&1; }
xfconfd_pids() { pgrep -u "$(id -u)" -x xfconfd || true; }

configure_current_user() {
  config=${XDG_CONFIG_HOME:-$HOME/.config}
  data=${XDG_DATA_HOME:-$HOME/.local/share}
  for file in "$config/gtk-3.0/gtk.css" "$config/gtk-4.0/gtk.css" "$config/xfce4/terminal/terminalrc" \
    "$config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" "$config/xfce4/panel"; do
    backup_once "$file"
  done
  configure_files "$config" "$data"
  write_block "$config/gtk-4.0/gtk.css" GTK4 "@import url(\"file://$data/themes/Chicago95/gtk-4.0/gtk.css\");"
  flatpak_override "$data"
  restart_panel=false
  if panel_running; then
    restart_panel=true
    xfce4-panel --quit >/dev/null 2>&1 || true
    tries=0
    while panel_running && [ "$tries" -lt 20 ]; do sleep 1; tries=$((tries + 1)); done
  fi
  rm -rf "$config/xfce4/panel"
  LC_ALL=C sh "$tmp/xfconf.sh"
  if $restart_panel; then (nohup xfce4-panel >/dev/null 2>&1 &); fi
}

[ "$(id -u)" -ne 0 ] || die "Run this script as the user who should get the theme, not as root. It asks for root rights when it needs them."
check_components
check_session
check_greeter_config
if has sudo; then ROOT=sudo; else ROOT=doas; fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' INT TERM
stage=$tmp/skel
mkdir -p "$stage"

say "Downloading Chicago95..."
download "$CHICAGO95_ARCHIVE" | gzip -dc | tar -xf - -C "$tmp" || die "Downloading Chicago95 failed. Nothing was changed."
src=$tmp/Chicago95-$CHICAGO95_COMMIT
[ -f "$src/INSTALL.md" ] || die "Downloading Chicago95 failed. Nothing was changed."

say "Checking that no installed package owns the target paths..."
check_conflicts

terminal_xfconf=false
if terminal_uses_xfconf; then terminal_xfconf=true; fi
monitors=$(connected_monitors)
xfconf_script >"$tmp/xfconf.sh"
write_gtk4_helper "$tmp/gtk4-helper"
write_greeter_config "$tmp/greeter.conf"

say "Preparing the defaults for new users..."
stage_skel

say "Installing the theme system-wide..."
install_system

say "Applying the theme to $(id -un)..."
configure_current_user

say "Chicago95 is installed and active. Log out and back in so every running application picks it up."
