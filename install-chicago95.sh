#!/bin/sh
set -eu

CHICAGO95_COMMIT=5da19b8b1e2a886ebf6628403023d5fac3acc3ee
CHICAGO95_ARCHIVE="https://github.com/grassmunk/Chicago95/archive/$CHICAGO95_COMMIT.tar.gz"
ICON_THEME=Chicago95-tux
CURSOR_THEME=Chicago95_Standard_Cursors
UI_FONT="Helvetica 8"
TITLE_FONT="Helvetica Bold 8"
TERMINAL_FONT="Less Perfect DOS VGA 12"
FONTCONFIG_CONFIG=/etc/fonts/conf.d/70-chicago95-helvetica.conf
WALLPAPER=/usr/share/backgrounds/chicago95/Setup.png
FIRST_LOGIN_HELPER=/usr/local/libexec/chicago95-first-login
FIRST_LOGIN_AUTOSTART=.config/autostart/chicago95-first-login.desktop
GREETER=/usr/share/xgreeters/lightdm-gtk-greeter.desktop
GREETER_MAIN_CONFIG=/etc/lightdm/lightdm-gtk-greeter.conf
GREETER_CONFIG=/etc/lightdm/lightdm-gtk-greeter.conf.d/99-chicago95.conf
CHANNELS="xsettings xfwm4 xfce4-notifyd xfce4-desktop xfce4-panel xfce4-terminal"

say() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
has() { command -v "$1" >/dev/null 2>&1; }
has_lib() { find /usr/lib /usr/lib64 /usr/lib32 /lib /lib64 /usr/local/lib -maxdepth 4 -name "$1" 2>/dev/null | grep -q .; }
libreoffice_dir() { soffice=$(readlink -f "$(command -v soffice)" 2>/dev/null) || soffice=""; say "${soffice%/program/soffice}"; }

missing=""
need_command() { has "$2" || missing="$missing  - $1 (command $2)
"; }
need_lib() { has_lib "$2" || missing="$missing  - $1 (library $2)
"; }
need_file() { [ -e "$2" ] || missing="$missing  - $1 (file $2)
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
  need_file "LightDM GTK greeter" "$GREETER"
  need_command "LibreOffice" soffice
  has soffice && need_file "LibreOffice installation folder" "$libreoffice/share/config"
  need_lib "LibreOffice GTK 3 integration" libvclplug_gtk3lo.so
  need_lib "libcanberra GTK 3 module for event sounds" libcanberra-gtk3-module.so
  need_command "Fontconfig" fc-cache
  need_command "D-Bus" dbus-run-session
  need_command "xrandr" xrandr
  need_command "pgrep" pgrep
  need_command "tar" tar
  need_command "gzip" gzip
  need_command "zip" zip
  has curl || has wget || missing="$missing  - curl or wget
"
  has sudo || has doas || missing="$missing  - sudo or doas
"
  [ -z "$missing" ] || {
    printf 'These components are missing. Install them and run the script again. Nothing was changed.\n%s' "$missing" >&2
    exit 1
  }
}

find_session_bus() {
  [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 0
  socket=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/bus
  [ -S "$socket" ] || return 1
  DBUS_SESSION_BUS_ADDRESS=unix:path=$socket
  export DBUS_SESSION_BUS_ADDRESS
}

detect_mode() {
  if ! pgrep -u "$(id -u)" -x xfce4-session >/dev/null 2>&1; then
    in_session=false
  elif [ -n "${DISPLAY:-}" ] && find_session_bus && xfconf-query -c xfwm4 -l >/dev/null 2>&1; then
    in_session=true
  else
    die "You are logged into Xfce. Run the script from a terminal inside that session, or log out of Xfce and run it from a TTY. Nothing was changed."
  fi
}

check_greeter_config() {
  overrides=$(grep -E '^[[:space:]]*(theme-name|icon-theme-name|cursor-theme-name|font-name|background)[[:space:]]*=' "$GREETER_MAIN_CONFIG" 2>/dev/null || true)
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
  say "$FONTCONFIG_CONFIG"
  say "${WALLPAPER%/*}"
  say /usr/share/xfce4/terminal/colorschemes/Chicago95.theme
  say "$libreoffice/share/config/images_chicago95.zip"
  say "$libreoffice/share/registry/chicago95.xcd"
  say "$FIRST_LOGIN_HELPER"
  say "$GREETER_CONFIG"
}

skel_targets() {
  for channel in $CHANNELS; do say "/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/$channel.xml"; done
  say /etc/skel/.config/xfce4/terminal/terminalrc
  say /etc/skel/.config/gtk-3.0/gtk.css
  say "/etc/skel/$FIRST_LOGIN_AUTOSTART"
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

gtk3_override() {
  case "$(xfconf-query --version 2>/dev/null)" in
    *" 4.12."*) say "$src/Extras/override/gtk-3.22/gtk.css" ;;
    *) say "$src/Extras/override/gtk-3.24/gtk.css" ;;
  esac
}

settings() {
  cat <<EOF
xsettings /Net/ThemeName string Chicago95
xsettings /Net/IconThemeName string $ICON_THEME
xsettings /Gtk/CursorThemeName string $CURSOR_THEME
xsettings /Gtk/FontName string $UI_FONT
xsettings /Net/SoundThemeName string Chicago95
xsettings /Net/EnableEventSounds bool true
xsettings /Net/EnableInputFeedbackSounds bool true
xsettings /Gtk/OverlayScrolling bool false
xfwm4 /general/theme string Chicago95
xfwm4 /general/title_font string $TITLE_FONT
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
xfce4-panel /plugins/plugin-1/button-icon string start-here
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
}

terminal_settings() {
  awk -v font="$TERMINAL_FONT" '
    /^Color/ { key = substr($0, 1, index($0, "=") - 1); gsub(/[A-Z]/, "-&", key)
               print "xfce4-terminal /" tolower(substr(key, 2)) " string " substr($0, index($0, "=") + 1) }
    END { print "xfce4-terminal /font-name string " font; print "xfce4-terminal /font-allow-bold bool false" }
  ' "$src/Extras/Chicago95.theme"
}

to_commands() {
  while read -r channel property type value; do
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
  settings | to_commands
  say "if xfconf-query -l | grep -qx '  xfce4-terminal'; then"
  terminal_settings | to_commands
  say 'fi'
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
  XDG_DATA_HOME=$1 flatpak override --user --filesystem=xdg-data/themes:ro --unset-env=GTK_THEME
}

remove_gtk4_block() {
  grep -q '>>> Chicago95 GTK4 BEGIN' "$1" 2>/dev/null || return 0
  sed '/>>> Chicago95 GTK4 BEGIN/,/<<< Chicago95 GTK4 END/d' "$1" >"$1.chicago95-new"
  cat "$1.chicago95-new" >"$1"
  rm -f "$1.chicago95-new"
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
  write_terminalrc "$1/xfce4/terminal/terminalrc"
}

write_first_login_helper() {
  printf '#!/bin/sh\nwallpaper=%s\n' "$WALLPAPER" >"$1"
  cat >>"$1" <<'EOF'
export LC_ALL=C
monitors=$(xrandr --query 2>/dev/null | awk '$2 == "connected" { print $1 }')
[ -n "$monitors" ] || exit 1
for monitor in $monitors; do
  prefix=/backdrop/screen0/monitor$monitor/workspace0
  xfconf-query -c xfce4-desktop -p "$prefix/color-style" -n -t int -s 0
  xfconf-query -c xfce4-desktop -p "$prefix/rgba1" -n -a -t double -s 0 -t double -s 0.501961 -t double -s 0.501961 -t double -s 1
  xfconf-query -c xfce4-desktop -p "$prefix/image-style" -n -t int -s 5
  xfconf-query -c xfce4-desktop -p "$prefix/last-image" -n -t string -s "$wallpaper"
done
rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/chicago95-first-login.desktop"
EOF
}

write_first_login_autostart() {
  mkdir -p "${1%/*}"
  printf '[Desktop Entry]\nType=Application\nName=Chicago95 first login setup\nExec=%s\nNoDisplay=true\n' "$FIRST_LOGIN_HELPER" >"$1"
}

run_private_xfconf() {
  running_xfconfd=" $(xfconfd_pids | tr '\n' ' ') "
  XDG_CONFIG_HOME="$1" LC_ALL=C dbus-run-session -- sh "$tmp/xfconf.sh" 2>"$tmp/xfconf.log" || return 1
  for pid in $(xfconfd_pids); do
    case $running_xfconfd in *" $pid "*) continue ;; esac
    tries=0
    while kill -0 "$pid" 2>/dev/null && [ "$tries" -lt 30 ]; do sleep 1; tries=$((tries + 1)); done
  done
}

write_greeter_config() {
  printf '[greeter]\ntheme-name=Chicago95\nicon-theme-name=%s\ncursor-theme-name=%s\nfont-name=%s\nbackground=#008080\n' "$ICON_THEME" "$CURSOR_THEME" "$UI_FONT" >"$1"
}

write_fontconfig_config() {
  cat >"$1" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <selectfont>
    <acceptfont>
      <pattern>
        <patelt name="family"><string>Helvetica</string></patelt>
        <patelt name="foundry"><string>Cron</string></patelt>
      </pattern>
    </acceptfont>
  </selectfont>
</fontconfig>
EOF
}

write_libreoffice_config() {
  cat >"$1" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<oor:data xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:oor="http://openoffice.org/2001/registry">
<dependency file="main"/>
<oor:component-data oor:package="org.openoffice.Office" oor:name="Common"><node oor:name="Misc"><prop oor:name="SymbolStyle"><value>chicago95</value></prop></node></oor:component-data>
</oor:data>
EOF
}

build_libreoffice_icons() {
  (cd "$src/Extras/libreoffice-chicago95-iconset/Chicago95-theme/iconsets/c95" && zip -qr "$1" .)
}

stage_skel() {
  skel_targets | while read -r path; do
    if [ -f "$path" ]; then
      mkdir -p "$(dirname "$stage/${path#/etc/skel/}")"
      cp "$path" "$stage/${path#/etc/skel/}"
    fi
  done
  configure_files "$stage/.config" "$stage/.local/share"
  write_first_login_autostart "$stage/$FIRST_LOGIN_AUTOSTART"
  flatpak_override "$stage/.local/share"
  rm -rf "$stage/.local/share/flatpak/repo" "$stage/.local/share/flatpak/.changed"
  run_private_xfconf "$stage/.config" ||
    die "Could not prepare the settings for new users: $(cat "$tmp/xfconf.log") Nothing was changed."
  for channel in $CHANNELS; do
    [ "$channel" = xfce4-terminal ] && continue
    [ -f "$stage/.config/xfce4/xfconf/xfce-perchannel-xml/$channel.xml" ] || die "Could not prepare the $channel settings for new users. Nothing was changed."
  done
  chmod -R u=rwX,go=rX "$stage"
}

install_system() {
  $ROOT sh -euc '
    umask 022
    src=$1 stage=$2 tmp=$3 helper=$4 greeter=$5 fontconfig=$6 wallpaper=$7 libreoffice=$8
    install_dir() { rm -rf "$2/${1##*/}"; mkdir -p "$2"; cp -R "$1" "$2/"; chmod -R u=rwX,go=rX "$2/${1##*/}"; }
    install_file() { mkdir -p "${2%/*}"; cp "$1" "$2"; chmod 644 "$2"; }
    install_dir "$src/Theme/Chicago95" /usr/share/themes
    for dir in "$src"/Icons/* "$src"/Cursors/*; do install_dir "$dir" /usr/share/icons; done
    install_dir "$src/sounds/Chicago95" /usr/share/sounds
    rm -rf /usr/share/fonts/chicago95
    for font in "$src"/Fonts/vga_font/*.ttf "$src"/Fonts/bitmap/cronyx-cyrillic/crox[1-6]h*.otb; do
      install_file "$font" "/usr/share/fonts/chicago95/${font##*/}"
    done
    install_file "$tmp/fontconfig.conf" "$fontconfig"
    rm -rf "${wallpaper%/*}"
    install_file "$src/Extras/Backgrounds/Wallpaper/${wallpaper##*/}" "$wallpaper"
    install_file "$src/Extras/Chicago95.theme" /usr/share/xfce4/terminal/colorschemes/Chicago95.theme
    install_file "$tmp/images_chicago95.zip" "$libreoffice/share/config/images_chicago95.zip"
    install_file "$tmp/chicago95.xcd" "$libreoffice/share/registry/chicago95.xcd"
    install_file "$tmp/greeter.conf" "$greeter"
    install_file "$tmp/first-login" "$helper"
    chmod 755 "$helper"
    rm -rf /etc/skel/.local/share/themes/Chicago95
    cp -R "$stage/." /etc/skel/
    fc-cache -f
  ' sh "$src" "$stage" "$tmp" "$FIRST_LOGIN_HELPER" "$GREETER_CONFIG" "$FONTCONFIG_CONFIG" "$WALLPAPER" "$libreoffice"
}

panel_running() { pgrep -u "$(id -u)" -x xfce4-panel >/dev/null 2>&1; }
xfconfd_pids() { pgrep -u "$(id -u)" -x xfconfd || true; }

configure_current_user() {
  config=${XDG_CONFIG_HOME:-$HOME/.config}
  data=${XDG_DATA_HOME:-$HOME/.local/share}
  for file in "$config/gtk-3.0/gtk.css" "$config/xfce4/terminal/terminalrc" \
    "$config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" "$config/xfce4/panel"; do
    backup_once "$file"
  done
  configure_files "$config" "$data"
  remove_gtk4_block "$config/gtk-4.0/gtk.css"
  flatpak_override "$data"
  restart_panel=false
  if panel_running; then
    restart_panel=true
    xfce4-panel --quit >/dev/null 2>&1 || true
    tries=0
    while panel_running && [ "$tries" -lt 20 ]; do sleep 1; tries=$((tries + 1)); done
  fi
  rm -rf "$config/xfce4/panel"
  if find_session_bus; then
    LC_ALL=C sh "$tmp/xfconf.sh"
  else
    run_private_xfconf "$config" || die "Could not write your Xfce settings: $(cat "$tmp/xfconf.log")"
  fi
  if $restart_panel; then (nohup xfce4-panel >/dev/null 2>&1 &); fi
  if $in_session; then
    "$FIRST_LOGIN_HELPER"
  else
    write_first_login_autostart "$config/autostart/chicago95-first-login.desktop"
  fi
}

[ "$(id -u)" -ne 0 ] || die "Run this script as the user who should get the theme, not as root. It asks for root rights when it needs them."
libreoffice=$(libreoffice_dir)
check_components
detect_mode
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

xfconf_script >"$tmp/xfconf.sh"
write_first_login_helper "$tmp/first-login"
write_greeter_config "$tmp/greeter.conf"
write_fontconfig_config "$tmp/fontconfig.conf"
write_libreoffice_config "$tmp/chicago95.xcd"
build_libreoffice_icons "$tmp/images_chicago95.zip" || die "Building the LibreOffice icon theme failed. Nothing was changed."

say "Preparing the defaults for new users..."
stage_skel

say "Installing the theme system-wide..."
install_system

say "Applying the theme to $(id -un)..."
configure_current_user

if $in_session; then
  say "Chicago95 is installed and active. Log out and back in so every running application picks it up."
else
  say "Chicago95 is installed. It takes effect the next time you log into Xfce."
fi
