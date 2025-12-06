#!/bin/bash
set -e

### CONFIG (you *can* change this if you want another Yuki package) ###
YUKI_PKG="yuki-iptv"    # e.g. yuki-iptv or yuki-iptv-bin
#######################################################################

if [[ $EUID -ne 0 ]]; then
  echo "Please run this script as root, e.g.:"
  echo "  sudo $0"
  exit 1
fi

### Detect the user that should run the IPTV UI ###

# 1. Prefer the user who invoked sudo
if [[ -n "$SUDO_USER" && "$SUDO_USER" != "root" ]]; then
  USER_NAME="$SUDO_USER"
fi

# 2. If still empty, fall back to UID 1000 (first normal user)
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
  USER_NAME="$(getent passwd 1000 2>/dev/null | cut -d: -f1 || true)"
fi

# 3. Final sanity check
if [[ -z "$USER_NAME" || "$USER_NAME" == "root" ]]; then
  echo "Could not auto-detect a non-root user."
  echo "Create a user first (e.g. useradd -m tvbox) and then run:"
  echo "  SUDO_USER=tvbox sudo $0"
  exit 1
fi

if ! id "$USER_NAME" &>/dev/null; then
  echo "Detected user '$USER_NAME' does not exist. Aborting."
  exit 1
fi

HOME_DIR="$(getent passwd "$USER_NAME" | cut -d: -f6)"
echo "Using user: $USER_NAME (home: $HOME_DIR)"

echo "==> Updating system and installing base packages..."
pacman -Syu --noconfirm

echo "==> Installing required packages..."
pacman -S --noconfirm --needed \
  base-devel git \
  xorg-server xorg-xinit \
  openbox tint2 picom \
  xorg-xmodmap xorg-xev \
  xdotool \
  mpv \
  mesa \
  networkmanager \
  pipewire pipewire-alsa pipewire-pulse wireplumber \
  alsa-utils

echo "==> Enabling NetworkManager..."
systemctl enable NetworkManager

### Install yay for AUR ###
if ! command -v yay &>/dev/null; then
  echo "==> Installing yay (AUR helper)..."
  sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "
    mkdir -p \"\$HOME/.builds\" &&
    cd \"\$HOME/.builds\" &&
    rm -rf yay &&
    git clone https://aur.archlinux.org/yay.git &&
    cd yay &&
    makepkg -si --noconfirm
  "
else
  echo '==> yay already installed, skipping.'
fi

echo "==> Installing Yuki IPTV from AUR ($YUKI_PKG)..."
sudo -u "$USER_NAME" HOME="$HOME_DIR" yay -S --noconfirm --needed "$YUKI_PKG"

### .bash_profile: startx on tty1 ###
echo "==> Configuring .bash_profile to autostart X on tty1..."
sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "cat > \"\$HOME/.bash_profile\" << 'EOF'
# Autostart X on tty1
if [[ -z \$DISPLAY ]] && [[ \$(tty) == /dev/tty1 ]]; then
  startx
fi
EOF
"

### .xinitrc: start openbox-session ###
echo "==> Creating .xinitrc for Openbox..."
sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "cat > \"\$HOME/.xinitrc\" << 'EOF'
#!/bin/sh
exec openbox-session
EOF
"
chmod +x "$HOME_DIR/.xinitrc"

### Openbox autostart ###
echo "==> Creating Openbox autostart..."
sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "mkdir -p \"\$HOME/.config/openbox\""

sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "cat > \"\$HOME/.config/openbox/autostart\" << 'EOF'
# Load remote key remaps
xmodmap \$HOME/.Xmodmap &

# Optional compositor to reduce tearing
picom --config \$HOME/.config/picom/picom.conf &

# Optional panel
tint2 &

# Start Yuki IPTV
yuki-iptv &

# After Yuki starts, double-click to fullscreen (mouse starts roughly center)
(sleep 6 && xdotool click --repeat 2 1) &
EOF
"

### picom config (simple, with vsync) ###
echo "==> Creating minimal picom config..."
sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "mkdir -p \"\$HOME/.config/picom\""
sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "cat > \"\$HOME/.config/picom/picom.conf\" << 'EOF'
backend = \"xrender\";
vsync = true;
unredir-if-possible = false;
EOF
"

### Xmodmap for your remote keycodes ###
echo "==> Creating .Xmodmap for remote buttons..."
sudo -u "$USER_NAME" HOME="$HOME_DIR" bash -c "cat > \"\$HOME/.Xmodmap\" << 'EOF'
! Right button (114) -> 'n' (next channel)
keycode 114 = n

! Page Up (112) -> 'n' (next channel)
keycode 112 = n

! Left button (113) -> 'b' (previous channel)
keycode 113 = b

! Page Down (117) -> 'b' (previous channel)
keycode 117 = b

! Hamburger (135) -> 't' (playlist toggle)
keycode 135 = t
EOF
"

### Auto-login service on tty1 ###
echo "==> Creating autologin service for tty1..."
cat > /etc/systemd/system/autologin-tty1.service << EOF
[Unit]
Description=Autologin on tty1
After=systemd-user-sessions.service plymouth-quit-wait.service
Before=getty.target

[Service]
ExecStart=-/usr/bin/agetty --autologin $USER_NAME --noclear tty1 linux
Type=simple

[Install]
WantedBy=multi-user.target
EOF

echo "==> Disabling default getty on tty1 and enabling autologin-tty1..."
systemctl disable getty@tty1.service || true
systemctl stop getty@tty1.service || true
systemctl enable autologin-tty1.service

echo
echo "====================================================="
echo " Done."
echo " User:    $USER_NAME"
echo " Home:    $HOME_DIR"
echo " Package: $YUKI_PKG"
echo
echo "On reboot, it should:"
echo "  - auto-login as $USER_NAME on tty1"
echo "  - autostart X + Openbox"
echo "  - start Yuki IPTV and go fullscreen"
echo "  - map remote keys (Right/Left/PageUp/PageDown/Hamburger)"
echo
echo "Reboot now with:  systemctl reboot"
echo "====================================================="
