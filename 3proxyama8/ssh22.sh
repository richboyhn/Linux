#!/bin/bash

# Kiểm tra quyền root
if [ "$(id -u)" -ne 0 ]; then
    echo "Cần quyền root để chạy script này."
    exit 1
fi

# Xác định file cấu hình sshd_config
SSHD_CONFIG="/etc/ssh/sshd_config"

# Kiểm tra xem file cấu hình có tồn tại không
if [ ! -f "$SSHD_CONFIG" ]; then
    echo "Không tìm thấy file cấu hình SSH: $SSHD_CONFIG"
    exit 1
fi
# Thay đổi cổng SSH về 22
echo "Đang thay đổi cổng SSH về 22..."
sed -i 's/^Port [0-9]\+/Port 22/' $SSHD_CONFIG

# Mở cổng 22 trong firewall (ufw hoặc firewalld)
echo "Đang mở cổng 22 trong firewall..."

# Khởi động lại dịch vụ SSH
echo "Đang khởi động lại dịch vụ SSH..."
systemctl restart sshd

