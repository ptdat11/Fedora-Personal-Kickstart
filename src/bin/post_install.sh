#!/bin/bash

# Special thanks to: https://github.com/devangshekhawat/Fedora-43-Post-Install-Guide
# RPM Fusion & Terra
dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' terra-release

dnf group upgrade -y core
dnf4 group install -y core

dnf -y update
