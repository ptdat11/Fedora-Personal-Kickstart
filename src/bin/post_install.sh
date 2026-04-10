#!/bin/bash
SCRIPT_DIR="$(dirname "$0")"
USER="$1"

external_repos() {
# Special thanks to: https://github.com/devangshekhawat/Fedora-44-Post-Install-Guide
	# RPM Fusion & Terra
	dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
	dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release
}

optimize_system() {
	dnf config-manager setopt max_parallel_downloads=10
	dnf config-manager setopt fastestmirror=true
	dnf swap ffmpeg-free ffmpeg --allowerasing
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

	# Set default apps
  runuser -l "$user" -c 'xdg-mime default mpv.desktop video/mp4'
	runuser -l "$user" -c 'xdg-mime default firefox.desktop application/pdf'
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

	# Fix an error where Swappy cannot open image properly from Dolphin
	sed -i -E $'s#^Exec=.*#Exec=sh -c \'if [ -n "$*" ]; then exec swappy -f "$@"; else grim -g "$(slurp)" - | swappy -f -; fi\' -- %F#' /usr/share/applications/swappy.desktop

	# Fix theme changing error
	# runuser -l ptdat -c $'sed -i -E \'s/^(\s*)(matugen_args=.*)/\1# \2/\' ~/.config/quickshell/ii/scripts/colors/switchwall.sh'
	runuser -l ptdat -c $'sed -i -E \'/^def\s+reload\(\):/a \\\\treturn\' ~/.local/state/quickshell/.venv/lib/python3.12/site-packages/kde_material_you_colors/utils/kwin_utils.py'
}

install_astronvim() {
	local user="$1"
	runuser -l "$user" -c 'cp -r /opt/dots-nvim ~/.config/nvim'
	runuser -l "$user" -c 'rm -rf ~/.config/nvim/.git'

	runuser -l "$user" -c $'sed -E \'s/^(\s*relativenumber\s*=\s*)(true|false)(.*)/\1false\3/\' ~/.config/nvim/lua/plugins/astrocore.lua'
}

install_fcitx5_lotus() {
	# Non pre-edit Vietnamese keyboard
	local user="$1"

	RELEASEVER=$(grep '^VERSION_ID=' /etc/os-release | cut -d'=' -f2)
	rpm --import https://fcitx5-lotus.pages.dev/pubkey.gpg
	dnf config-manager addrepo --from-repofile=https://fcitx5-lotus.pages.dev/rpm/fedora/fcitx5-lotus-$RELEASEVER.repo
	dnf install -y fcitx5-lotus

	systemctl enable fcitx5-lotus-server@"$user".service || (sudo systemd-sysusers && sudo systemctl enable fcitx5-lotus-server@"$user".service)

	runuser -l "$user" -c 'echo "export GTK_IM_MODULE=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export QT_IM_MODULE=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export XMODIFIERS=@im=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export SDL_IM_MODULE=fcitx" >> ~/.bash_profile'
	runuser -l "$user" -c 'echo "export GLFW_IM_MODULE=ibus" >> ~/.bash_profile'

	runuser -l "$user" -c 'echo "exec-once = fcitx5 -d" >> ~/.config/hypr/custom/execs.conf'
}

add_omz_plugin() {
    local plugin="$1"
    local zshrc="$HOME/.zshrc"
    
    if grep -qE "^\s*plugins=\(.*\b${plugin}\b.*\)" "$zshrc"; then
        return 0
    fi

    sed -i -E "s/^(\s*plugins=\([^)]*)\)/\1 $plugin)/" "$zshrc"
}
install_zsh() {
	local user="$1"

	# Install Oh My Zsh (plugin manager for zsh)
	runuser -l "$user" -c "yes | sh $SCRIPT_DIR/install_zsh"
	runuser -l "$user" -c $'sed -i -E \'s/^\s*ZSH_THEME=.*/ZSH_THEME=""/\' ~/.zshrc'
	# Install Oh My Zsh plugins
	{
		runuser -l "$user" -c 'cp -r /opt/zsh-plugins/* ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/'

		plugins=(
			zsh-autosuggestions
			zsh-syntax-highlighting
			zsh-vi-mode
		)
		for plugin in ${plugins[@]}; do
			runuser -l "$user" -c "$(declare -f add_omz_plugin); add_omz_plugin $plugin"
		done
	}

	# Apply all ~/.config/zshrc.d/*.zsh files
	runuser -l "$user" -c 'echo "source ~/.config/zshrc.d/*.zsh" >> ~/.zshrc'
	# Apply starship
	runuser -l "$user" -c 'echo "eval \"\$(starship init zsh)\"" >> ~/.config/zshrc.d/75-starship.zsh'

	# Replace End-4 default fish shell with zsh, entirely
	fish_2_zsh_files=(
		\$HOME/.config/foot/foot.ini
		\$HOME/.config/illogical-impulse/config.json
		\$HOME/.config/kitty/kitty.conf
		\$HOME/.config/hypr/custom/keybinds.conf
		\$HOME/.config/hypr/hyprland/keybinds.conf
		\$HOME/.config/quickshell/ii/modules/common/Config.qml
	)
	for file in ${fish_2_zsh_files[@]}; do
		runuser -l "$user" -c "sed -i 's/fish/zsh/' $file"
	done

	usermod --shell /bin/zsh "$user"
	dnf remove -y fish
	runuser -l "$user" -c 'rm -rf ~/.config/fish'
}

install_sddm_theme() {
	user="$1"
	sed -i -E 's/^\s*(%wheel\s+ALL=\(ALL\)\s+)ALL/\1NOPASSWD: ALL/' /etc/sudoers
	runuser -l "$user" -c "(echo y; echo 1) | bash $SCRIPT_DIR/install_sddm_theme.sh"
	# Restore password requirement of $user
	sed -i -E 's/^\s*(%wheel\s+ALL=\(ALL\)\s+)NOPASSWD: ALL/\1ALL/' /etc/sudoers
}

cleanup_kickstart() {
	rm /root/anaconda-ks.cfg
}

external_repos 
optimize_system
setup_xdg "$USER"
mok_enroll_uefi
install_hyprland_end4 "$USER"
install_astronvim "$USER"
install_fcitx5_lotus "$USER"
install_zsh "$USER"
install_sddm_theme "$USER"

cleanup_kickstart
