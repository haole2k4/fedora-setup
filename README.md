# Fedora System Setup & GNOME Backup

Bộ công cụ thiết lập sau khi cài mới, tối ưu hóa hệ thống và sao lưu cấu hình **GNOME** cho **Fedora Linux**.

## Cấu trúc thư mục

```text
fedora-setup/
├── Makefile                     # Tự động hóa tối ưu máy & backup/restore GNOME
├── .gitignore                   # Chặn file rác, cache, history và secret/token
│
├── system/                      # [HỆ THỐNG] Các script cấp hệ thống (cần sudo)
│   ├── after-install/           # Thiết lập sau khi cài mới Fedora (dnf.conf, codec, driver...)
│   ├── optimize/                # Tối ưu dịch vụ nền, tiết kiệm pin, dọn kernel cũ, bảo trì
│   ├── upgrade/                 # Quy trình nâng cấp phiên bản Fedora (system-upgrade)
│   └── setup-apps/              # Script cài đặt Ollama (Open WebUI), UxPlay, mẹo MPV
│
└── gnome/                       # [GNOME] Sao lưu/khôi phục riêng nhánh /org/gnome/
    ├── backup-gnome.sh          # Quản lý sao lưu cấu hình GNOME Shell
    └── gnome-settings.dconf     # Bản sao lưu cấu hình dconf của GNOME
```

---

## 1. Sau khi cài mới: Đồng bộ Dotfiles

Các cấu hình cá nhân (`zsh`, `ghostty`, `starship`, `tmux`, `git`, `mpv`, `vim`, `nvim`) đã được tách sang repo riêng [`haole2k4/dotfiles`](https://github.com/haole2k4/dotfiles). Sau khi cài mới máy, clone repo dotfiles rồi chạy `make stow`:

```bash
git clone https://github.com/haole2k4/dotfiles ~/dotfiles
make -C ~/dotfiles stow
```

---

## 2. Sao lưu & Khôi phục cấu hình GNOME (`dconf`)

Chỉ trích xuất nhánh `/org/gnome/` để giữ cấu hình gọn gàng và độc lập:

```bash
make gnome-backup    # Xuất cấu hình ra gnome/gnome-settings.dconf
make gnome-restore   # Nạp lại cấu hình từ gnome/gnome-settings.dconf
```

---

## 3. Tối ưu & Bảo trì Hệ thống (`system/`)

### Chạy nhanh qua `Makefile`:
```bash
make optimize        # Dọn cache dnf5, cập nhật gói, dọn journalctl (7 ngày) & fstrim SSD
make performance     # Bật Docker, chuyển scx_lavd sang Gaming (nếu có) & bật hiệu ứng/extension GNOME
make powersave       # Tắt Docker, chuyển scx_lavd sang PowerSave (nếu có) & tắt hiệu ứng/extension GNOME
```

### Thiết lập sau khi cài mới (`system/after-install/`):
- **Cấu hình DNF:** `sudo cp system/after-install/dnf.conf /etc/dnf/dnf.conf`
- **Cài đặt cơ bản:** Xem và chạy từng bước trong [`system/after-install/mustdo.sh`](system/after-install/mustdo.sh) (RPM Fusion, Multimedia Codecs, NVIDIA `akmod-nvidia`, `tlp`, slim `dracut` initramfs, `kernel-cachyos`, `cachyos-settings`, `scx_loader` với `scx_lavd`, clone `dotfiles`...).
- **Sửa tốc độ cuộn Touchpad:** Xem [`system/after-install/touchpadfix.sh`](system/after-install/touchpadfix.sh).

### Quản lý Kernel & Dịch vụ nền (`system/optimize/`):
- [`system/optimize/optimize.sh`](system/optimize/optimize.sh): Tắt các dịch vụ ngầm gây tốn pin/SSD (`localsearch`, `abrtd`, `ModemManager`...) và cài `auto-cpufreq`.
- [`system/optimize/performance.sh`](system/optimize/performance.sh) & [`system/optimize/powersave.sh`](system/optimize/powersave.sh): Chuyển đổi chế độ hiệu năng/tiết kiệm pin (Docker, `scxctl` cho `scx_lavd`, hiệu ứng & extension GNOME).
- [`system/optimize/deloldkernel.sh`](system/optimize/deloldkernel.sh) & [`system/optimize/resignfornewkernel.sh`](system/optimize/resignfornewkernel.sh): Xóa kernel cũ an toàn và ký lại Secure Boot (MOK) cho cả kernel CachyOS và Fedora gốc.
- [`system/optimize/tipntrick.md`](system/optimize/tipntrick.md): Sổ tay mẹo tiết kiệm pin và các lệnh kiểm tra/chẩn đoán kernel CachyOS, `sched_ext` (`scxctl`, `sched_bore`, NVMe I/O scheduler).

---

## Tham khảo
- [Hướng dẫn tối ưu Fedora - Video 1](https://www.youtube.com/watch?v=iRUt8As9hXM)
- [Hướng dẫn tối ưu Fedora - Video 2](https://www.youtube.com/watch?v=ud7YxC33Z3w)
- [Touchpad Scroll Fix (Framework/Fedora)](https://www.reddit.com/r/framework/comments/17z30p3/comment/kdywvuy/)
