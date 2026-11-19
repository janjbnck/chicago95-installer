# Agent guide

This repository contains `install-chicago95.sh`, a POSIX `sh` script that installs the [Chicago95](https://github.com/grassmunk/Chicago95) theme system-wide on Xfce and makes it the default for the current user and every account created later. `README.md` documents what the script applies and skips. Keep it in sync with every change.

## Rules every change must follow

1. **Check components first.** Before the script changes anything, it verifies that every themable component it touches is installed. If something is missing, it lists all missing items and exits without changing anything. When you add a component, add its check to `check_components` in the same change.
2. **Theme everything the script covers.** Every component in the component check gets the theme applied. Don't add a component check without applying the theme, and don't theme something without checking for it.
3. **No Microsoft or Windows branding tweaks.** Skip optional extras such as Windows logos, DOS prompts, MS-DOS titles, Windows startup sounds and Microsoft fonts. The only exception is the Start button, which the owner asked for explicitly: it uses the Tux icon from `Chicago95-tux` and the label "Start".
4. **Current user and future users.** Apply every setting to the user running the script and to `/etc/skel`, so a newly created account starts with Chicago95 already active. Anything that needs the running session or the user's home path goes into the first-login helper (`chicago95-first-login`).
5. **Updates must not undo the theme.** Never edit files owned by the package manager. Use locations that updates leave alone: the user's xfconf store, `/etc/skel`, drop-in directories, new files with unique names. Add every new system or skel path to `system_targets` or `skel_targets` so the ownership check covers it. If a package-owned file would override your setting, stop with an explanation instead of editing it, like `check_greeter_config` does.

## How to implement changes

- **Reference:** base theming steps on Chicago95's [INSTALL.md](https://github.com/grassmunk/Chicago95/blob/master/INSTALL.md) at the pinned commit in `CHICAGO95_COMMIT`. Skip components that INSTALL.md marks with known problems or incompatibilities, and list them in the README.
- **Verify, don't guess:** check property names, file locations and load order in the upstream source of the program you're configuring (xfconf, xfce4-panel, xfdesktop, lightdm-gtk-greeter, flatpak) before relying on them.
- **Distro-agnostic:** plain POSIX `sh`, no package manager commands except the ownership lookups, no bash-only syntax.
- **Both run modes:** the script runs inside an Xfce session or from a TTY while logged out. New code must work in both, so don't depend on `DISPLAY` outside session-only paths.
- **Nothing changed on failure:** every check that can fail runs before the first system or user change, and its message ends with "Nothing was changed."
- **Xfconf settings:** add them as lines to `settings()`. They then reach the current user and `/etc/skel` automatically.
- **Style:** no comments in the script. Keep functions small and well named. Run `shellcheck -s sh -e SC2016 install-chicago95.sh` and `dash -n install-chicago95.sh`.

## Testing

Test changes end to end in a headless Xfce session (Xvfb), not just with the linters:

- The current user, inside a session and from a TTY
- A newly created account's first login
- Every failure path: missing component, package-owned target, running from outside an active session

Report anything you couldn't test.
