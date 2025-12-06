# ARCHIPTV

Turn a **minimal Arch Linux install** on an Intel NUC (or similar small PC) into a **dedicated IPTV set-top box** using:

- Arch Linux (bare/minimal)
- Openbox (lightweight window manager)
- Yuki IPTV
- Autologin + autostart to full-screen IPTV
- Simple remote-control key mappings

This repo provides a single setup script that handles everything for you.

---

## Features

- ✅ Auto-login on `tty1` (no login prompt)
- ✅ Auto-start X + Openbox
- ✅ Auto-start **Yuki IPTV**
- ✅ Auto-fullscreen via simulated double-click
- ✅ Minimal compositor (**picom**) to reduce tearing
- ✅ Remote key mappings:
  - Right / PageUp → **Next channel**
  - Left / PageDown → **Previous channel**
  - Hamburger button → **Toggle playlist**

> Note: The script does **not** modify Yuki’s internal hotkeys (which can be buggy with large playlists).  
> Instead it remaps your remote keys at the X11 level to match Yuki’s default shortcuts.

---

## Requirements

- A **bare Arch Linux** install (no desktop environment)
- A non-root user created (e.g. `tvbox`), with:
  - Home directory (e.g. `/home/tvbox`)
  - Ability to run `sudo`
- Internet access (for installing packages + AUR helper)
- A supported **Intel NUC** or small x86 PC with:
  - HDMI video + audio
  - A remote that appears as a keyboard / airmouse (USB dongle is ideal)

The script will:

- Auto-detect which user to use (the `sudo` invoker or UID 1000)
- Install:
  - `xorg-server`, `xorg-xinit`
  - `openbox`, `tint2`, `picom`
  - `mpv`, `mesa`
  - PipeWire + ALSA tools
  - `xorg-xmodmap`, `xorg-xev`, `xdotool`
  - `yay` (AUR helper)
  - `yuki-iptv` from AUR

---

## One-liner install

From your Arch install (after creating your user and logging in as that user), run:

```bash
sudo bash <(curl -fsSL https://raw.githubusercontent.com/4ddict/ARCHIPTV/main/setup-iptv.sh)
```

Then reboot:

```bash
sudo reboot
```

On reboot, it should:

1. Auto-login as your user on `tty1`
2. Auto-start X + Openbox
3. Launch Yuki IPTV
4. Simulate a double-click after a short delay → fullscreen
5. Apply remote key mappings for next/previous channel + playlist

---

## What the script does (overview)

1. **Detects the user**  
   - Prefers `$SUDO_USER` if non-root  
   - Otherwise uses the first normal user (UID 1000)

2. **System packages**  
   - Updates packages (`pacman -Syu`)  
   - Installs Xorg, Openbox, picom, mpv, audio stack, tools

3. **Networking**  
   - Enables `NetworkManager`

4. **AUR helper (`yay`)**  
   - Installs `yay` for the chosen user (if missing)

5. **Yuki IPTV**  
   - Installs `yuki-iptv` from AUR (you can tweak package name inside the script)

6. **Autostart to X**  
   - Creates `~/.bash_profile` to run `startx` automatically on `tty1`
   - Creates `~/.xinitrc` to start `openbox-session`

7. **Openbox autostart**  
   - `~/.config/openbox/autostart`:
     - loads `.Xmodmap` (remote mappings)
     - starts `picom` and `tint2`
     - starts `yuki-iptv`
     - after a delay, runs `xdotool click --repeat 2 1` to fullscreen Yuki

8. **Remote mappings** (`~/.Xmodmap`)  
   Mapped to Yuki’s defaults:

   - `keycode 114` → `n` (Next channel)  
   - `keycode 112` → `n` (Next channel)  
   - `keycode 113` → `b` (Previous channel)  
   - `keycode 117` → `b` (Previous channel)  
   - `keycode 135` → `t` (Toggle playlist)

   > These keycodes are based on one specific universal remote.  
   > If your remote differs, you can adjust `~/.Xmodmap` after installation using `xev`.

9. **Autologin on tty1**  
   - Creates `/etc/systemd/system/autologin-tty1.service`
   - Disables `getty@tty1.service`
   - Enables `autologin-tty1.service` to log the chosen user in automatically

---

## Customization

After running the script, you can tweak:

- **Delay before fullscreen**  
  Edit `~/.config/openbox/autostart` and adjust the `sleep 6` value.

- **Remote keycodes / actions**  
  Edit `~/.Xmodmap` and run:
  ```bash
  xmodmap ~/.Xmodmap
  ```
  Use `xev` to discover keycodes for your particular remote.

- **Compositor / panel**  
  If you don’t want `picom` or `tint2`, comment them out in `autostart`.

- **Different Yuki package**  
  In the script, change:
  ```bash
  YUKI_PKG="yuki-iptv"
  ```
  to e.g. `yuki-iptv-bin` if you prefer.

---

## Troubleshooting

- **Black screen / X issues**  
  Switch to another TTY with `Ctrl+Alt+F2`, log in, edit/delete:
  - `~/.bash_profile`
  - `~/.xinitrc`
  - or `~/.config/openbox/autostart`

- **Remote buttons don’t match**  
  Use:
  ```bash
  DISPLAY=:0 xev -event keyboard
  ```
  to see your actual keycodes and adjust `~/.Xmodmap` accordingly.

- **Yuki not starting or crashing**  
  Run it manually in X from a terminal to inspect output:
  ```bash
  yuki-iptv
  ```

---

## Disclaimer

This script is opinionated and optimized for a very specific use case:

- Minimal Arch install
- Intel NUC-like hardware
- Universal remote acting as a keyboard

Use at your own risk. Read through `setup-iptv.sh` before running if you want to understand or adapt it further.

---

## License

Free to use and modify for everyone :)
