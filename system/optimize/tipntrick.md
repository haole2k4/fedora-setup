## Mẹo:
1. Upscale fonts sẽ đỡ tốn pin hơn so với Upscale độ phân giải màn hình
2. Tiết kiệm pin thì dùng `scxctl switch --sched scx_lavd --mode powersave` (trên kernel CachyOS) hoặc `tlp` + kernel gốc Fedora
3. Các extension cần tắt khi tiết kiệm pin:
- Blur my shell 
- Clipboard indicator
- Gnome 4x UI Improvement
- Search Light
4. `power-profiles-daemon` có thể không có mặc định trên cấu hình Fedora tối giản (hoặc bị thay thế bởi `tuned-ppd` / `scx_loader`).

## Kiểm tra & chẩn đoán Kernel CachyOS + `sched_ext` (`scx_lavd`)

### 1. Kernel & BORE Scheduler
```bash
# Kiểm tra kernel đang chạy (vd: 7.3.4-1.cachyos1.fc44.x86_64)
uname -r

# Kiểm tra BORE scheduler đã bật chưa (kết quả: kernel.sched_bore = 1)
sysctl kernel.sched_bore

# Liệt kê các gói kernel-cachyos, cachyos-settings và scx đã cài
rpm -qa | grep -E 'kernel-cachyos|scx-|cachyos-settings'
```

### 2. Trạng thái `sched_ext` & `scx_loader`
```bash
# Kiểm tra service quản lý bộ lập lịch
systemctl status scx_loader.service

# Xem scheduler & mode đang chạy qua scxctl
scxctl get
scxctl list
scxctl modes --sched scx_lavd --show-args

# Kiểm tra trực tiếp qua sysfs của kernel
cat /sys/kernel/sched_ext/state      # enabled
cat /sys/kernel/sched_ext/root/ops   # vd: lavd_1.1.4_x86_64_unknown_linux_gnu
```

### 3. Chuyển chế độ `scx_lavd` nhanh với `scxctl`
```bash
sudo scxctl switch --sched scx_lavd --mode gaming     # Hiệu năng cao / Gaming
sudo scxctl switch --sched scx_lavd --mode powersave  # Tiết kiệm pin
sudo scxctl switch --sched scx_lavd --mode auto       # Tự động cân bằng
sudo scxctl restore                                   # Khôi phục mặc định trong /etc/scx_loader/config.toml
```

### 4. I/O Scheduler (`cachyos-settings` udev rule `60-ioschedulers.rules`)
```bash
# Kiểm tra I/O scheduler của NVMe (cachyos-settings đặt [kyber] cho NVMe, mq-deadline cho SSD, bfq cho HDD)
cat /sys/block/nvme0n1/queue/scheduler
```

## Ổn định Wi-Fi Realtek RTL8852BE (`rtw89_8852be`)

Card RTL8852BE (`04:00.0`) bật mặc định PCIe ASPM L1/L1.1, CLKREQ và firmware deep power save (`disable_ps_mode=N`), dễ gây lỗi `read/write rf busy swsi`, `timed out to flush queues` và rớt kết nối `CTRL-EVENT-BEACON-LOSS` (nhất là với AP 2.4GHz đổi băng thông 20/40MHz).

### 1. Cấu hình module kernel (`/etc/modprobe.d/rtw89.conf`)
```ini
options rtw89_pci disable_aspm_l1=y disable_aspm_l1ss=y disable_clkreq=y
options rtw89_core disable_ps_mode=y
```

### 2. Tối ưu profile NetworkManager
```bash
nmcli connection modify "<TEN_WIFI>" 802-11-wireless.mac-address-randomization never 802-11-wireless.powersave 2
nmcli connection up "<TEN_WIFI>"
```

### 3. Kiểm tra nhanh trạng thái tham số & liên kết
```bash
cat /sys/module/rtw89_pci/parameters/disable_aspm_l1
cat /sys/module/rtw89_pci/parameters/disable_aspm_l1ss
cat /sys/module/rtw89_pci/parameters/disable_clkreq
cat /sys/module/rtw89_core/parameters/disable_ps_mode
cat /sys/bus/pci/devices/0000:04:00.0/link/l1_aspm
cat /sys/bus/pci/devices/0000:04:00.0/link/l1_1_aspm
iw dev wlp4s0 link
```
