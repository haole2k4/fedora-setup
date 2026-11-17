# ============================================================
# PHẦN 1: CẬP NHẬT HỆ THỐNG & FIRMWARE (TRƯỚC KHI REBOOT)
# (Lưu ý: Đây là danh sách lệnh chạy tay từng bước, không chạy một lèo)
# ============================================================
sudo dnf update

sudo fwupdmgr refresh --force
sudo fwupdmgr update
#xong 2 lenh tren thi 
sudo reboot now

# ============================================================
# PHẦN 2: CÀI ĐẶT GÓI, DRIVER & DOTFILES (SAU KHI REBOOT)
# ============================================================
sudo dnf install dnf5 dnf5-plugins #use dnf5

sudo dnf install http://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
sudo dnf upgrade --refresh

sudo dnf install sl -y
sl

sudo dnf5 install dnfdragora #optional

sudo dnf5 install multimedia

sudo dnf5 install gnome-tweaks

flatpak install flathub com.mattjakeman.ExtensionManager

sudo dnf5 install fastfetch mpv wget git gcc make python3 python3-pip unrar unzip cargo p7zip p7zip-plugins ntfs-3g htop java-17-openjdk android-tools vlc

sudo dnf5 install timeshift

#NVIDIA
lspci | grep VGA
sudo dnf install akmod-nvidia
sudo systemctl enable --now nvidia-persistenced.service

#battery
sudo dnf5 install tlp
sudo systemctl enable tlp
sudo systemctl start tlp
# Tùy chọn: tránh UPower tự động ngủ đông/tắt nguồn đột ngột khi báo pin tới hạn
sudo sed -i 's/^CriticalPowerAction=.*/CriticalPowerAction=Ignore/' /etc/UPower/UPower.conf

# Wi-Fi Realtek RTL8852BE (rtw89_8852be): tắt PCIe ASPM L1/L1.1, CLKREQ và firmware deep power save
# để tránh lỗi "read/write rf busy swsi", "timed out to flush queues" và rớt mạng CTRL-EVENT-BEACON-LOSS
sudo tee /etc/modprobe.d/rtw89.conf << 'EOF'
options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y disable_clkreq=y
options rtw89_core disable_ps_mode=y
EOF
# Tùy chọn NetworkManager cho profile Wi-Fi hay dùng (tránh random MAC & tắt powersave):
# nmcli connection modify "<TEN_WIFI>" 802-11-wireless.mac-address-randomization never 802-11-wireless.powersave 2
# nmcli connection up "<TEN_WIFI>"

#dotfiles (clone repo dotfiles riêng & tạo symlink bằng GNU Stow)
# git clone https://github.com/haole2k4/dotfiles ~/dotfiles && make -C ~/dotfiles stow

# ============================================================
# PHẦN 3: SLIM INITRAMFS, KERNEL CACHYOS & CACHYOS-SETTINGS
# ============================================================

# 1. Slim Initramfs (làm trước khi cài kernel mới để áp dụng ngay khi tạo initramfs)
sudo tee /etc/dracut.conf.d/99-slim-initramfs.conf << 'EOF'
hostonly="yes"
hostonly_mode="strict"
compress="zstd -15 -T0"
EOF

# Gỡ rescue initramfs để tiết kiệm dung lượng /boot (chỉ dùng khi không cần entry rescue)
sudo dnf remove dracut-config-rescue
sudo rm -f /boot/*rescue*

# 2. SELinux & Kernel CachyOS
# Cho phép nạp kernel modules / domain liên quan trên SELinux
sudo setsebool -P domain_kernel_load_modules on

sudo dnf copr enable bieszczaders/kernel-cachyos
sudo dnf install kernel-cachyos kernel-cachyos-devel-matched

# 3. CachyOS Addons (cachyos-settings & sched_ext)
sudo dnf copr enable bieszczaders/kernel-cachyos-addons

# Gỡ systemd-oomd-defaults vì xung đột với cấu hình oomd/zram của cachyos-settings
sudo dnf remove systemd-oomd-defaults
sudo dnf install cachyos-settings --allowerasing

# Cài bộ scheduler sched_ext và scx_loader/scxctl (hoặc dùng gói scx-tools bản release)
sudo dnf install scx-scheds scx-tools-git

# Nếu dùng NVIDIA, đảm bảo akmods build xong module cho kernel CachyOS trước khi reboot:
# sudo akmods --force
# (Nếu bật Secure Boot, xem system/optimize/resignfornewkernel.sh để ký MOK cho kernel mới)
sudo reboot now

# ============================================================
# PHẦN 4: CẤU HÌNH SCHED_EXT (SCX_LOADER + SCX_LAVD)
# (Chạy sau khi đã reboot vào kernel CachyOS)
# ============================================================
# Lưu ý: scx-tools dùng scx_loader.service (DBus loader) với /etc/scx_loader/config.toml,
# KHÔNG dùng scx.service hay /etc/default/scx (không tồn tại trong bộ gói này).
sudo mkdir -p /etc/scx_loader
sudo cp /usr/share/scx_loader/config.toml /etc/scx_loader/config.toml
sudo sed -i 's/^#\?default_sched = .*/default_sched = "scx_lavd"/' /etc/scx_loader/config.toml
sudo sed -i 's/^#\?default_mode = .*/default_mode = "Gaming"/' /etc/scx_loader/config.toml

sudo systemctl enable --now scx_loader.service

# Kiểm tra nhanh sau khi bật:
# uname -r
# scxctl get
# cat /sys/kernel/sched_ext/state
# cat /sys/kernel/sched_ext/root/ops

