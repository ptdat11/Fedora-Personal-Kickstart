#!/bin/bash

# Special thanks to: https://github.com/devangshekhawat/Fedora-43-Post-Install-Guide
# RPM Fusion & Terra
dnf install -y https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf install -y --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

timedatectl set-local-rtc 0

optimize_dnf() {
	dnf config-manager setopt max_parallel_downloads=10
	dnf config-manager setopt fastestmirror=true
}

setup_xdg() {
  user="$1"
  runuser -l "$user" -c "xdg-user-dirs-update"
  dirnames='Desktop Documents Downloads Music Pictures Public Templates Videos'
  for dirname in $dirnames; do 
    dirname_lower="${dirname,,}"
    runuser -l "$user" -c "mv \"\$HOME/$dirname\" \"\$HOME/$dirname_lower\""
    runuser -l "$user" -c "sed -i 's/$dirname/$dirname_lower/' \"\$HOME/.config/user-dirs.dirs\""
  done
}

optimize_dnf
setup_xdg ptdat
