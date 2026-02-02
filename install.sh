#!/bin/bash
# Mil4ne - Pwni-Conf

set -e

LOGFILE="$HOME/install.log"
exec > >(tee "$LOGFILE") 2>&1

# =========================
# Colors
# =========================
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
RESET="\e[0m"

# =========================
# Banner
# =========================
clear
echo -e "${BLUE}"
cat << "EOF"
██████╗ ██╗    ██╗███╗   ██╗██╗       ██████╗ ██████╗ ███╗   ██╗███████╗
██╔══██╗██║    ██║████╗  ██║██║      ██╔════╝██╔═══██╗████╗  ██║██╔════╝
██████╔╝██║ █╗ ██║██╔██╗ ██║██║█████╗██║     ██║   ██║██╔██╗ ██║█████╗  
██╔═══╝ ██║███╗██║██║╚██╗██║██║╚════╝██║     ██║   ██║██║╚██╗██║██╔══╝  
██║     ╚███╔███╔╝██║ ╚████║██║      ╚██████╗╚██████╔╝██║ ╚████║██║     
╚═╝      ╚══╝╚══╝ ╚═╝  ╚═══╝╚═╝       ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝╚═╝     

                    P w n i - C o n f
EOF
echo -e "${RESET}"

echo -e "${GREEN}[*] Starting installation...${RESET}"

# =========================
# VALIDATIONS
# =========================
if [ "$EUID" -eq 0 ]; then
  echo -e "${RED}[!] Do not run as root${RESET}"
  exit 1
fi

command -v apt >/dev/null || { echo "[!] apt not found"; exit 1; }

BASE_DIR="$HOME/custom-linux-workspace"
[ -d "$BASE_DIR" ] || { echo "[!] custom-linux-workspace not found"; exit 1; }

# =========================
# UPGRADE PROMPT
# =========================
read -rp "$(echo -e "${YELLOW}Do you want to upgrade system packages first? [y/N]: ${RESET}")" UPGRADE

sudo apt update
if [[ "$UPGRADE" =~ ^[Yy]$ ]]; then
  sudo apt upgrade -y
fi

# =========================
# CORE PACKAGES
# =========================
sudo apt install -y \
  xorg xinit x11-xserver-utils \
  bspwm sxhkd \
  alacritty polybar rofi \
  tmux feh \
  dunst wmname \
  lsd bat curl git unzip wget \
  fonts-font-awesome \
  fonts-materialdesignicons-webfont unifont \
  tmux numlockx \
  pulseaudio-utils pavucontrol \
  brightnessctl \
  open-vm-tools open-vm-tools-desktop \
  build-essential git \
  libxcb-util0-dev libxcb-ewmh-dev libxcb-randr0-dev \
  libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-xinerama0-dev \
  libxcb-xtest0-dev libxcb-shape0-dev

# =========================
# CONFIG DIRS
# =========================
for dir in bspwm sxhkd polybar rofi alacritty picom dunst; do
  mkdir -p "$HOME/.config/$dir"
done

mkdir -p "$HOME/Wallpapers" "$HOME/.local/share/fonts"

# =========================
# COPY CONFIGS
# =========================
for cfg in bspwm sxhkd polybar rofi alacritty picom dunst; do
  [ -d "$BASE_DIR/config/$cfg" ] && cp -r "$BASE_DIR/config/$cfg" "$HOME/.config/"
done

chmod +x "$HOME/.config/bspwm/bspwmrc"
chmod +x "$HOME/.config/polybar/launch.sh"
chmod +x "$HOME/.config/bspwm/scripts/"* 2>/dev/null || true

# =========================
# WALLPAPERS & LOCAL FONTS
# =========================
cp -f "$BASE_DIR/wallpapers/"* "$HOME/Wallpapers/" || true
cp -r "$BASE_DIR/fonts/"* "$HOME/.local/share/fonts/" || true

# =========================
# NERD FONT (JETBRAINS MONO)
# =========================
FONT_DIR="$HOME/.local/share/fonts/JetBrainsMono"

if [ ! -d "$FONT_DIR" ]; then
  echo -e "${GREEN}[+] Installing JetBrainsMono Nerd Font...${RESET}"
  mkdir -p "$FONT_DIR"
  cd /tmp
  wget -q https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -q JetBrainsMono.zip -d "$FONT_DIR"
  rm JetBrainsMono.zip
else
  echo -e "${YELLOW}[*] JetBrainsMono Nerd Font already installed${RESET}"
fi

fc-cache -fv > /dev/null

# =========================
# FONT CHECKS (POLYBAR SAFE)
# =========================
echo -e "${GREEN}[+] Verifying fonts...${RESET}"

fc-list | grep -qi "JetBrainsMono Nerd" \
  && echo -e "  ${GREEN}✔ JetBrainsMono Nerd Font OK${RESET}" \
  || echo -e "  ${RED}✘ JetBrainsMono Nerd Font MISSING${RESET}"

fc-list | grep -qi "Font Awesome" \
  && echo -e "  ${GREEN}✔ Font Awesome OK${RESET}" \
  || echo -e "  ${RED}✘ Font Awesome MISSING${RESET}"

# =========================
# OH MY ZSH
# =========================
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  echo "[*] Installing Oh My Zsh..."
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

ZSH_CUSTOM="$HOME/.oh-my-zsh/custom"

git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions" || true
git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" || true
git clone https://github.com/zdharma-continuum/fast-syntax-highlighting "$ZSH_CUSTOM/plugins/fast-syntax-highlighting" || true

[ -f "$HOME/.zshrc" ] && mv "$HOME/.zshrc" "$HOME/.zshrc.bak"
cp "$BASE_DIR/.zshrc" "$HOME/.zshrc"

# =========================
# ALACRITTY
# =========================
alacritty migrate || true

# =========================
# VMWARE OPTIMIZATIONS
# =========================
echo -e "${BLUE}[*] Applying VMware optimizations...${RESET}"

sudo systemctl start vmtoolsd

cat <<EOF > "$HOME/.xprofile"
xset s off
xset -dpms
xset s noblank
EOF

if ! grep -q "vm.swappiness" /etc/sysctl.conf; then
  echo "vm.swappiness=10" | sudo tee -a /etc/sysctl.conf
fi

# =========================
# DONE
# =========================
echo
echo "======================================="
echo " Installation completed successfully 🎉"
echo "======================================="
echo
echo "[+} Log file: $LOGFILE"
echo "[+} Select 'bspwm' in your display manager"
echo "[+} Reboot or re-login to apply everything"
