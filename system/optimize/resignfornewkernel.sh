#!/usr/bin/env bash
set -euo pipefail

# Ký lại kernel (Secure Boot MOK) cho kernel CachyOS hoặc Fedora gốc bằng khoá akmods.
# Yêu cầu: gói sbsigntools (sbsign, sbverify), openssl, và cặp khoá MOK tại /etc/pki/akmods/.

CERT_DER="/etc/pki/akmods/certs/public_key.der"
CERT_PEM="/etc/pki/akmods/certs/public_key.pem"
PRIV_KEY="/etc/pki/akmods/private/private_key.priv"

if [[ $# -eq 0 || "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  echo "Kernel đang chạy: $(uname -r)"
  echo ""
  echo "Các kernel image hiện có trong /boot:"
  ls -1 /boot/vmlinuz-* 2>/dev/null | grep -v 'rescue' | sed 's|^/boot/vmlinuz-|  |' || echo "  (Không tìm thấy hoặc không có quyền đọc /boot)"
  echo ""
  echo "Cách dùng:"
  echo "  bash $0 <kernel-version> [--rebuild-initramfs]"
  echo "Ví dụ:"
  echo "  bash $0 $(uname -r)"
  echo "  bash $0 $(uname -r) --rebuild-initramfs"
  exit 0
fi

KVER="$1"
REBUILD_INITRAMFS="${2:-}"
VMLINUZ="/boot/vmlinuz-${KVER}"
INITRAMFS="/boot/initramfs-${KVER}.img"

for cmd in openssl sbsign sbverify; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    echo "[ERROR] Thiếu lệnh '${cmd}'. Hãy cài đặt: sudo dnf install sbsigntools openssl" >&2
    exit 1
  fi
done

if [[ ! -f "${VMLINUZ}" ]]; then
  echo "[ERROR] Không tìm thấy ${VMLINUZ}" >&2
  exit 1
fi

if [[ ! -r "${CERT_DER}" ]] && ! sudo test -r "${CERT_DER}"; then
  echo "[ERROR] Không tìm thấy chứng chỉ MOK tại ${CERT_DER}" >&2
  exit 1
fi

if ! sudo test -r "${PRIV_KEY}"; then
  echo "[ERROR] Không tìm thấy khoá riêng MOK tại ${PRIV_KEY}" >&2
  exit 1
fi

if ! sudo test -f "${CERT_PEM}" || sudo test "${CERT_DER}" -nt "${CERT_PEM}"; then
  echo "[INFO] Xuất ${CERT_PEM} từ ${CERT_DER}..."
  sudo openssl x509 -inform DER -in "${CERT_DER}" -out "${CERT_PEM}"
fi

if sudo sbverify --cert "${CERT_PEM}" "${VMLINUZ}" >/dev/null 2>&1; then
  echo "[INFO] ${VMLINUZ} đã được ký hợp lệ bởi ${CERT_PEM}."
else
  echo "[INFO] Đang ký ${VMLINUZ}..."
  sudo sbsign \
    --key "${PRIV_KEY}" \
    --cert "${CERT_PEM}" \
    "${VMLINUZ}" \
    --output "${VMLINUZ}.signed"

  sudo sbverify --list "${VMLINUZ}.signed"
  sudo mv "${VMLINUZ}.signed" "${VMLINUZ}"
  echo "[OK] Đã ký và cập nhật ${VMLINUZ}."
fi

if [[ "${REBUILD_INITRAMFS}" == "--rebuild-initramfs" ]]; then
  echo "[INFO] Đang tạo lại initramfs: ${INITRAMFS}..."
  sudo dracut -f "${INITRAMFS}" "${KVER}"
fi
