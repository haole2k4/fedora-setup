.PHONY: help optimize kernel-check kernel-prune kernel-auto performance powersave gnome-backup gnome-restore

help:
	@echo "=================================================================="
	@echo "  FEDORA SYSTEM SETUP & GNOME BACKUP - BẢNG ĐIỀU KHIỂN"
	@echo "=================================================================="
	@echo "  make optimize      : Bảo trì: dọn cache, cập nhật, dọn kernel cũ, journal, fstrim (cần sudo)"
	@echo "  make kernel-check  : Xem kernel cũ nào sẽ bị xoá (giữ tối đa 3, không cần sudo)"
	@echo "  make kernel-prune  : Dọn kernel cũ ngay (cần sudo)"
	@echo "  make kernel-auto   : Bật tự dọn kernel sau mỗi lần cập nhật & sau khi boot (cần sudo)"
	@echo "  make performance   : Bật chế độ hiệu năng tối đa (Docker + scx_lavd Gaming + GNOME UI)"
	@echo "  make powersave     : Bật chế độ tiết kiệm pin (Tắt Docker + scx_lavd PowerSave + GNOME UI)"
	@echo "  make gnome-backup  : Sao lưu cấu hình GNOME (/org/gnome/) qua dconf"
	@echo "  make gnome-restore : Khôi phục cấu hình GNOME từ bản sao lưu dconf"
	@echo "=================================================================="

optimize:
	@echo "[INFO] Đang chạy bảo trì hệ thống Fedora..."
	sudo bash system/optimize/maintainance.sh

kernel-check:
	bash system/optimize/maintainance.sh prune-kernels --dry-run

kernel-prune:
	sudo bash system/optimize/maintainance.sh prune-kernels

kernel-auto:
	sudo bash system/optimize/maintainance.sh install-auto

performance:
	zsh system/optimize/performance.sh

powersave:
	zsh system/optimize/powersave.sh

gnome-backup:
	bash gnome/backup-gnome.sh backup

gnome-restore:
	bash gnome/backup-gnome.sh restore
