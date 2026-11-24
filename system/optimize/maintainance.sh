#!/usr/bin/env bash
# Bảo trì hệ thống Fedora + giữ tối đa 3 kernel (Fedora gốc + CachyOS).
#
# Cách dùng:
#   sudo bash maintainance.sh                        # Bảo trì đầy đủ: dọn cache dnf, cập nhật, dọn kernel, journal, fstrim
#   bash maintainance.sh prune-kernels --dry-run     # Xem kernel nào sẽ bị xoá (không cần sudo)
#   sudo bash maintainance.sh prune-kernels          # Chỉ dọn kernel
#   sudo bash maintainance.sh install-auto           # Tự dọn kernel sau mỗi lần cài kernel mới + 5 phút sau mỗi lần boot
#   sudo bash maintainance.sh uninstall-auto         # Gỡ chế độ tự động
#
# Quy tắc dọn kernel: nếu tổng số kernel > 3, xoá bản CŨ NHẤT của dòng kernel KHÔNG đang chạy
# (đang boot CachyOS -> xoá Fedora cũ nhất, và ngược lại). Không bao giờ xoá kernel đang chạy.
# Kết hợp với installonly_limit=2 trong /etc/dnf/dnf.conf (mỗi dòng tối đa 2 bản).
set -uo pipefail

MAX_KERNELS=3
INSTALLED_BIN=/usr/local/sbin/fedora-maintenance
LEGACY_BIN=/usr/local/sbin/kernel-prune
HOOK=/etc/kernel/install.d/99-kernel-prune.install
SERVICE=/etc/systemd/system/kernel-prune.service
TIMER=/etc/systemd/system/kernel-prune.timer
SELF=$(readlink -f "${BASH_SOURCE[0]}")

log() { echo "[maintenance] $*"; }

need_root() {
  [[ $EUID -eq 0 ]] || { echo "Hãy chạy với sudo: sudo bash $SELF $*" >&2; exit 1; }
}

usage() { sed -n '2,13p' "$SELF" | sed 's/^# \{0,1\}//'; }

# Đợi dnf/rpm/akmods (build kmod NVIDIA cho kernel mới) chạy xong, tối đa 60 phút.
wait_for_pkg_managers() {
  local _
  for _ in $(seq 1 360); do
    pgrep -x 'dnf|dnf5|rpm|rpmbuild|akmods|akmodsbuild' >/dev/null || return 0
    sleep 10
  done
}

prune_kernels() {
  local dry=0
  [[ "${1:-}" == "--dry-run" ]] && dry=1
  if (( ! dry )); then
    need_root prune-kernels
    exec 9>/run/kernel-prune.lock
    flock 9
    wait_for_pkg_managers
  fi

  local running name ver v victim attempt
  local -a fedora=() cachy=() same=() other=() cand=() pkgs=()
  running=$(uname -r)
  while read -r name ver; do
    case $name in
      kernel-core)         fedora+=("$ver") ;;
      kernel-cachyos-core) cachy+=("$ver") ;;
    esac
  done < <(rpm -q --qf '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n' kernel-core kernel-cachyos-core 2>/dev/null)

  in_list() { local x=$1 i; shift; for i in "$@"; do [[ $i == "$x" ]] && return 0; done; return 1; }
  oldest()  { printf '%s\n' "$@" | sort -V | head -n1; }

  if in_list "$running" "${cachy[@]}"; then
    same=("${cachy[@]}"); other=("${fedora[@]}")
  elif in_list "$running" "${fedora[@]}"; then
    same=("${fedora[@]}"); other=("${cachy[@]}")
  else
    log "kernel đang chạy ($running) không thuộc kernel-core/kernel-cachyos-core, bỏ qua dọn kernel"; return 0
  fi

  local total=$(( ${#fedora[@]} + ${#cachy[@]} ))
  log "kernel đang chạy: $running | Fedora: ${fedora[*]:-không có} | CachyOS: ${cachy[*]:-không có} | tổng: $total"
  (( total <= MAX_KERNELS )) && { log "≤ $MAX_KERNELS kernel, không cần xoá"; return 0; }

  if (( ${#other[@]} >= 2 )); then
    victim=$(oldest "${other[@]}")
  else
    for v in "${same[@]}"; do [[ $v != "$running" ]] && cand+=("$v"); done
    (( ${#cand[@]} )) || { log "không có kernel nào để xoá"; return 0; }
    victim=$(oldest "${cand[@]}")
  fi
  [[ $victim == "$running" ]] && { log "từ chối xoá kernel đang chạy"; return 1; }

  mapfile -t pkgs < <(rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}.%{ARCH}\n' | awk -v k="$victim" '
    $2 == k && $1 ~ /^kernel(-cachyos)?(-core|-modules(-core|-extra|-internal)?|-devel(-matched)?)?$/ { print $1 "-" $2; next }
    index($1, "kmod-") == 1 && length($1) > length(k) + 1 && substr($1, length($1) - length(k)) == "-" k { print $1 "-" $2 }')
  (( ${#pkgs[@]} )) || { log "không tìm thấy gói cho $victim"; return 1; }
  log "sẽ xoá kernel $victim: ${pkgs[*]}"

  if ! rpm -e --test "${pkgs[@]}"; then
    log "rpm -e --test báo lỗi phụ thuộc, KHÔNG xoá"; return 1
  fi
  (( dry )) && { log "dry-run, dừng ở đây"; return 0; }

  for attempt in 1 2 3; do
    dnf5 remove -y "${pkgs[@]}" && { log "đã xoá kernel $victim"; return 0; }
    log "dnf5 remove thất bại (lần $attempt), thử lại sau 60s"; sleep 60
  done
  return 1
}

install_auto() {
  need_root install-auto
  install -Dm755 "$SELF" "$INSTALLED_BIN"
  rm -f "$LEGACY_BIN"

  install -d /etc/kernel/install.d
  cat > "$HOOK" <<'EOF'
#!/usr/bin/sh
# kernel-install hook (fedora-maintenance): sau khi cài kernel mới, hẹn dọn kernel cũ.
# Service tự đợi dnf/akmods chạy xong rồi mới xoá.
[ "$1" = "add" ] || exit 0
[ -d /run/systemd/system ] || exit 0
systemctl start --no-block kernel-prune.service >/dev/null 2>&1 || :
exit 0
EOF
  chmod 755 "$HOOK"

  cat > "$SERVICE" <<EOF
[Unit]
Description=Keep at most $MAX_KERNELS kernels (Fedora + CachyOS)
After=akmods.service
ConditionPathExists=!/system-update

[Service]
Type=oneshot
ExecStart=$INSTALLED_BIN prune-kernels
TimeoutStartSec=90min
EOF

  cat > "$TIMER" <<'EOF'
[Unit]
Description=Run kernel-prune 5 minutes after boot

[Timer]
OnBootSec=5min

[Install]
WantedBy=timers.target
EOF

  command -v restorecon >/dev/null && restorecon -F "$INSTALLED_BIN" "$HOOK" "$SERVICE" "$TIMER"
  systemctl daemon-reload
  systemctl enable kernel-prune.timer
  log "đã cài chế độ tự dọn kernel ($HOOK, kernel-prune.service, kernel-prune.timer)"
  prune_kernels
}

uninstall_auto() {
  need_root uninstall-auto
  systemctl disable --now kernel-prune.timer 2>/dev/null || :
  rm -f "$HOOK" "$SERVICE" "$TIMER" "$INSTALLED_BIN" "$LEGACY_BIN"
  systemctl daemon-reload
  log "đã gỡ chế độ tự dọn kernel"
}

# Nếu đã install-auto, giữ bản cài trong /usr/local/sbin đồng bộ với bản trong repo.
refresh_installed_copy() {
  if [[ -f $INSTALLED_BIN && $SELF != "$INSTALLED_BIN" ]] && ! cmp -s "$SELF" "$INSTALLED_BIN"; then
    install -Dm755 "$SELF" "$INSTALLED_BIN"
    log "đã cập nhật $INSTALLED_BIN"
  fi
}

full_maintenance() {
  need_root
  log "Running system maintenance..."
  refresh_installed_copy
  dnf5 clean all
  dnf5 upgrade --refresh -y
  prune_kernels
  journalctl --vacuum-time=7d
  fstrim -v /
  [[ -f $HOOK ]] || log "Mẹo: chạy 'sudo bash $SELF install-auto' để tự dọn kernel cả khi cập nhật bằng dnf/GNOME Software."
  log "Maintenance complete!"
}

case "${1:-}" in
  ""|run)          full_maintenance ;;
  prune-kernels)   shift; prune_kernels "$@" ;;
  install-auto)    install_auto ;;
  uninstall-auto)  uninstall_auto ;;
  -h|--help|help)  usage ;;
  *)               usage; exit 1 ;;
esac
