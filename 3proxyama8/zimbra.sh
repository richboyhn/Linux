#!/bin/bash
set -e

# 📍 Kiểm tra quyền root
if [[ $EUID -ne 0 ]]; then
  echo "Chạy script bằng root nhé!"
  exit 1
fi

# 📌 Kiểm tra domain
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1
HOSTNAME="mail"
FQDN="$HOSTNAME.$DOMAIN"

# 🌐 Lấy IP công cộng
PUBIP=$(curl -s http://myip.directadmin.com)
if [[ -z "$PUBIP" ]]; then
  echo "Không lấy được IP công cộng."
  exit 1
fi

# 🛠 Cập nhật hostname và /etc/hosts
hostnamectl set-hostname "$FQDN"
echo "$HOSTNAME" > /etc/hostname
cat > /etc/hosts <<EOF
127.0.0.1   localhost
$PUBIP      $FQDN $HOSTNAME
EOF
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# 📦 Cài các gói cần thiết
apt update
apt install -y net-tools curl dnsutils sudo unzip pax libaio1 resolvconf perl libgmp-dev libperl5.34 lsb-release

# 💾 Cài libidn11 từ Ubuntu 20.04 (Zimbra cần)
cd /tmp
wget -nv http://mirrors.kernel.org/ubuntu/pool/main/libi/libidn/libidn11_1.33-2.2ubuntu2_amd64.deb
apt install -y ./libidn11_1.33-2.2ubuntu2_amd64.deb || apt --fix-broken install -y
ln -sf /usr/lib/x86_64-linux-gnu/libidn.so.12 /usr/lib/x86_64-linux-gnu/libidn.so.11

# 🛑 Dừng và tắt Postfix nếu đang chạy
systemctl stop postfix || true
systemctl disable postfix || true

# 🔽 Tải Zimbra cho Ubuntu 22.04
cd /opt
wget -c https://files.zimbra.com/downloads/10.1.0_GA/zcs-10.1.0_GA_ubuntu22_64.tgz
tar xzvf zcs-*.tgz
cd $(find . -maxdepth 1 -type d -name "zcs-10.1.0*" | head -n1)

# ⌨ Tập tin trả lời tự động
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

# 💻 Cài Zimbra không tương tác
./install.sh < /tmp/keystrokes

# 🔁 Khởi động dịch vụ Zimbra
su - zimbra -c 'zmcontrol restart'

# 🎉 Thông tin sau khi cài
cat <<INFO
--------------------------------------------
✅ Zimbra Collaboration 10.1 đã cài đặt!
🔗 Admin Console: https://$FQDN:7071
📧 Username: admin@$DOMAIN
🔑 Password: StrongPass!2025
📬 Webmail: https://$FQDN
🛠 Tạo DKIM: /opt/zimbra/libexec/zmdkimkeyutil -a -d $DOMAIN
--------------------------------------------
INFO
