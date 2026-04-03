#!/bin/bash
SCRIPT_DIR="$(dirname "$0")"
USER="$1"

# Special thanks to: https://github.com/devangshekhawat/Fedora-43-Post-Install-Guide
# RPM Fusion & Terra
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

timedatectl set-local-rtc 0

optimize_system() {
	dnf config-manager setopt max_parallel_downloads=10
	dnf config-manager setopt fastestmirror=true
	dnf swap ffmpeg-free ffmpeg
	systemctl disable NetworkManager-wait-online.service
}

setup_xdg() {
  local user="$1"
  runuser -l "$user" -c "xdg-user-dirs-update"
  dirnames='Desktop Documents Downloads Music Pictures Public Templates Videos'
  for dirname in $dirnames; do 
    dirname_lower="${dirname,,}"
    runuser -l "$user" -c "mv \"\$HOME/$dirname\" \"\$HOME/$dirname_lower\""
    runuser -l "$user" -c "sed -i 's/$dirname/$dirname_lower/' \"\$HOME/.config/user-dirs.dirs\""
  done
}

mok_enroll_uefi() {
	# This step is neccessary for NVIDIA driver installation
	kmodgenca -a --force
	yes @@@MOKUTIL_PASSWD@@@ | mokutil --import /etc/pki/akmods/certs/public_key.der
}

install_hyprland_end4() {
	local user="$1"

	# Temporarily allow $user to privilege escalate without requiring password (we are non-interactive)
	sed -i -E 's/^\s*(%wheel\s+ALL=\(ALL\)\s+)ALL/\1NOPASSWD: ALL/' /etc/sudoers
	# Install End-4 dotfiles
	runuser -l "$user" -c "(echo; echo; echo; echo; echo Y; echo y; echo yesforall) | bash $SCRIPT_DIR/install_end4"
	# Restore password requirement of $user
	sed -i -E 's/^\s*(%wheel\s+ALL=\(ALL\)\s+)NOPASSWD: ALL/\1ALL/' /etc/sudoers

	runuser -l "$user" -c 'echo "monitor = ,preferred,auto,auto" >> ~/.config/hypr/custom/general.conf'

	# Switch from command line to graphical environemnt
	systemctl enable sddm
	systemctl set-default graphical.target
}

install_astronvim() {
	local user="$1"
	runuser -l "$user" -c 'git clone --depth 1 https://github.com/AstroNvim/template ~/.config/nvim'
	runuser -l "$user" -c 'rm -rf ~/.config/nvim/.git'

	sed -E 's/^(\s*relativenumber\s*=\s*)(true|false)(.*)/\1false\3/' ~/.config/nvim/lua/plugins/astrocore.lua
}

install_fcitx5_lotus() {
	# Non pre-edit Vietnamese keyboard
	local user="$1"

	RELEASEVER=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2)
	rpm --import https://fcitx5-lotus.pages.dev/pubkey.gpg
	dnf config-manager addrepo --from-repofile=https://fcitx5-lotus.pages.dev/rpm/fedora/fcitx5-lotus-$RELEASEVER.repo
	dnf install -y fcitx5-lotus

	systemctl enable --now fcitx5-lotus-server@"$user".service || (sudo systemd-sysusers && sudo systemctl enable --now fcitx5-lotus-server@"$user".service)

	runuser -l "$user" -c 'echo "export GTK_IM_MODULE=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export QT_IM_MODULE=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export XMODIFIERS=@im=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export SDL_IM_MODULE=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export GLFW_IM_MODULE=ibus" >> ~/.bash_profile'

	runuser -l "$user" -c 'echo "exec-once = fcitx5 -d" >> ~/.config/hypr/custom/execs.conf'
}

install_zsh() {
	local user="$1"

	usermod --shell /bin/zsh "$user"
	runuser -l "$user" -c 'echo "eval \"\$(starship init zsh)\"" >> ~/.config/zshrc.d/75-starship.zsh'
	runuser -l "$user" -c 'echo "source ~/.config/zshrc.d/*.zsh" >> ~/.zshrc'

	fish_2_zsh_files=(
		~/.config/foot/foot.ini
		~/.config/illogical-impulse/config.json
		~/.config/kitty/kitty.conf
		~/.config/hypr/custom/keybinds.conf
		~/.config/hypr/hyprland/keybinds.conf
		~/.config/quickshell/ii/modules/common/Config.qml
	)
	runuser -l "$user" -c "sed -i 's/fish/zsh/' ${fish_2_zsh_files[@]}"

	dnf remove -y fish
	runuser -l "$user" -c 'rm -rf ~/.config/fish'
}

optimize_system
setup_xdg "$USER"
mok_enroll_uefi
install_hyprland_end4 "$USER"
install_astronvim "$USER"
install_fcitx5_lotus "$USER"
install_zsh "$USER"
