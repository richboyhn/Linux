#!/bin/bash
set -e

# 👉 Kiểm tra root
if [[ $EUID -ne 0 ]]; then
  echo "Vui lòng chạy bằng quyền root."
  exit 1
fi

# 👉 Kiểm tra domain
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1
HOSTNAME="mail"
FQDN="$HOSTNAME.$DOMAIN"

# 👉 IP công cộng
PUBIP=$(curl -s http://myip.directadmin.com)
if [[ -z "$PUBIP" ]]; then
  echo "Không lấy được IP công cộng!"
  exit 1
fi

# 👉 Thiết lập hostname
hostnamectl set-hostname "$FQDN"
echo "$HOSTNAME" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n$PUBIP\t$FQDN\t$HOSTNAME" > /etc/hosts
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 👉 Cài gói phụ thuộc
apt update
apt install -y net-tools curl dnsutils sudo unzip pax libaio1 perl libgmp-dev libperl5.34 lsb-release

# 👉 Cài libidn11 (từ Ubuntu 20.04)
cd /tmp
wget http://mirrors.kernel.org/ubuntu/pool/main/libi/libidn/libidn11_1.33-2.2ubuntu2_amd64.deb
apt install -y ./libidn11_1.33-2.2ubuntu2_amd64.deb || apt --fix-broken install -y
ln -sf /usr/lib/x86_64-linux-gnu/libidn.so.12 /usr/lib/x86_64-linux-gnu/libidn.so.11

# 👉 Tắt postfix nếu có
systemctl stop postfix 2>/dev/null || true
systemctl disable postfix 2>/dev/null || true

# 👉 Tải Zimbra 10.1.0 cho Ubuntu 22.04
cd /opt
wget -c https://files.zimbra.com/downloads/10.1.0_GA/zcs-10.1.0_GA_ubuntu22_64.tgz
tar xzvf zcs-10.1.0_GA_ubuntu22_64.tgz
cd zcs-10.1.0_GA_ubuntu22_64

# 👉 Script trả lời tự động
cat > /tmp/keystrokes <<EOF
Y
Y
Y
Y
Y
n
Y
Y
Y
Y
Y
Y
n
N
n
y
Yes
$DOMAIN
6
4
StrongPass!2025
r
a
yes

yes
no
EOF

# 👉 Cài đặt không tương tác
./install.sh < /tmp/keystrokes

# 👉 Khởi động Zimbra
su - zimbra -c 'zmcontrol restart'

# 👉 In thông tin
cat <<EOF

✅ Zimbra đã cài thành công trên Ubuntu 22.04!
🌐 Webmail: https://$FQDN
🛠 Admin:  https://$FQDN:7071
👤 Tài khoản: admin@$DOMAIN
🔐 Mật khẩu: StrongPass!2025

📌 Chạy thêm lệnh tạo DKIM:
    /opt/zimbra/libexec/zmdkimkeyutil -a -d $DOMAIN

EOF
