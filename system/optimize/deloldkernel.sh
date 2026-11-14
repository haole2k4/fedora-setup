#!/usr/bin/env bash
set -euo pipefail

# Liệt kê các kernel đang cài (cả Fedora gốc và CachyOS) và xoá một phiên bản cụ thể một cách an toàn.
RUNNING_KERNEL="$(uname -r)"
ARCH="$(uname -m)"

list_installed_kernels() {
  echo "Kernel đang chạy: ${RUNNING_KERNEL}"
  echo ""
  echo "Các gói kernel đang cài:"
  rpm -q --qf '  %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' kernel kernel-cachyos 2>/dev/null || true
}

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  list_installed_kernels
  echo ""
  echo "Cách dùng:"
  echo "  bash $0 <kernel-version>"
  echo "Ví dụ:"
  echo "  bash $0 7.2.15-200.fc44.${ARCH}"
  echo "  bash $0 7.3.4-1.cachyos1.fc44.${ARCH}"
  echo ""
  echo "Mẹo xem các kernel cũ có thể xoá tự động (giữ lại 2 bản mới nhất):"
  echo "  sudo dnf repoquery --installonly --latest-limit=-2 -q"
  exit 0
fi

TARGET_VER="$1"
if [[ "${TARGET_VER}" != *.${ARCH} ]]; then
  TARGET_VER="${TARGET_VER}.${ARCH}"
fi

if [[ "${TARGET_VER}" == "${RUNNING_KERNEL}" ]]; then
  echo "[ERROR] Không thể xoá kernel đang chạy (${RUNNING_KERNEL})!" >&2
  exit 1
fi

CANDIDATES=(
  "kernel-${TARGET_VER}"
  "kernel-core-${TARGET_VER}"
  "kernel-modules-${TARGET_VER}"
  "kernel-modules-core-${TARGET_VER}"
  "kernel-modules-extra-${TARGET_VER}"
  "kernel-devel-${TARGET_VER}"
  "kernel-devel-matched-${TARGET_VER}"
  "kernel-cachyos-${TARGET_VER}"
  "kernel-cachyos-core-${TARGET_VER}"
  "kernel-cachyos-modules-${TARGET_VER}"
  "kernel-cachyos-modules-core-${TARGET_VER}"
  "kernel-cachyos-modules-extra-${TARGET_VER}"
  "kernel-cachyos-devel-${TARGET_VER}"
  "kernel-cachyos-devel-matched-${TARGET_VER}"
)

PACKAGES=()
for pkg in "${CANDIDATES[@]}"; do
  if rpm -q "${pkg}" >/dev/null 2>&1; then
    PACKAGES+=("${pkg}")
  fi
done

while IFS= read -r kmod; do
  [[ -n "${kmod}" ]] && PACKAGES+=("${kmod}")
done < <(rpm -qa "kmod-nvidia-${TARGET_VER}-*" 2>/dev/null)

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "[INFO] Không tìm thấy gói kernel nào khớp với '${TARGET_VER}'."
  list_installed_kernels
  exit 1
fi

echo "Chuẩn bị xoá các gói sau (kernel đang chạy: ${RUNNING_KERNEL}):"
printf '  %s\n' "${PACKAGES[@]}"
echo ""
sudo dnf remove "${PACKAGES[@]}"
