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
