#!/bin/bash
## Script cài đặt Zimbra 8.8.15 OSE trên Ubuntu 20.04
## Tác giả: ChatGPT - OpenAI
## Cảnh báo: chạy script trên máy sạch, không có mail server khác đang chạy.

## Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
   echo "Bạn cần chạy script này bằng quyền root."
   exit 1
fi

## Kiểm tra đối số
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <domain>"
    exit 1
fi

DOMAIN=$1
HOSTNAME="mail.$DOMAIN"
ZIMBRA_VERSION="zcs-8.8.15_GA_4179.UBUNTU20_64.20211118033954"
ZIMBRA_URL="https://files.zimbra.com/downloads/8.8.15_GA/${ZIMBRA_VERSION}.tgz"

## Cài các gói cần thiết
echo "[*] Cập nhật hệ thống và cài gói cần thiết..."
apt update && apt upgrade -y
apt install -y net-tools curl sudo unzip pax perl-core libaio1 resolvconf dnsutils wget libidn11

## Đặt hostname
echo "[*] Thiết lập hostname: $HOSTNAME"
/bin/hostnamectl set-hostname $HOSTNAME

echo "127.0.0.1 localhost" > /etc/hosts
PUBIP=$(curl -s http://myip.ipip.net | grep -oE '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+')
echo "$PUBIP $HOSTNAME $HOSTNAME.$DOMAIN" >> /etc/hosts

## Stop postfix nếu đang chạy
if lsof -Pi :25 -sTCP:LISTEN -t >/dev/null ; then
    echo "[*] Dừng Postfix..."
    systemctl stop postfix
    systemctl disable postfix
fi

## Tải và giải nén Zimbra
cd /tmp
echo "[*] Tải Zimbra $ZIMBRA_VERSION ..."
wget -c $ZIMBRA_URL

if [[ ! -f "${ZIMBRA_VERSION}.tgz" ]]; then
    echo "[!] Không tải được file Zimbra. Kiểm tra lại link hoặc kết nối mạng."
    exit 1
fi

tar xzvf ${ZIMBRA_VERSION}.tgz
cd ${ZIMBRA_VERSION}

## Cài đặt Zimbra (chỉ phần mềm, không cấu hình ngay)
echo "[*] Bắt đầu cài đặt Zimbra..."
./install.sh -s --platform-override

echo
echo "[!] Bước cài đặt phần mềm đã xong."
echo "[*] Để cấu hình Zimbra, chạy lệnh sau:"
echo
echo "   cd /tmp/$ZIMBRA_VERSION"
echo "   ./install.sh"
echo
echo "Chọn cấu hình theo nhu cầu hoặc dùng file cấu hình tự động nếu có."
