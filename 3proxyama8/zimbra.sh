#!/bin/bash

set -e

# ➤ Kiểm tra root
if [[ $EUID -ne 0 ]]; then
  echo "Run as root"
  exit 1
fi

# ➤ Kiểm tra domain
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1
HOSTNAME="mail"
FQDN="$HOSTNAME.$DOMAIN"

# ➤ Lấy IP công cộng
PUBIP=$(curl -s http://myip.directadmin.com)
if [[ -z "$PUBIP" ]]; then
  echo "Cannot get public IP"
  exit 1
fi

# ➤ Cấu hình hostname và hosts
hostnamectl set-hostname "$FQDN"
echo "$HOSTNAME" > /etc/hostname
echo -e "127.0.0.1\tlocalhost\n$PUBIP\t$FQDN\t$HOSTNAME" > /etc/hosts
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# ➤ Cài đặt phụ thuộc
apt update
apt install -y net-tools curl dnsutils sudo unzip pax libaio1 resolvconf perl libgmp-dev libperl5.34 lsb-release

# ➤ Cài libidn11 từ Ubuntu 20.04
cd /tmp
wget -nv http://mirrors.kernel.org/ubuntu/pool/main/libi/libidn/libidn11_1.33-2.2ubuntu2_amd64.deb
apt install -y ./libidn11_1.33-2.2ubuntu2_amd64.deb || apt --fix-broken install -y
ln -sf /usr/lib/x86_64-linux-gnu/libidn.so.12 /usr/lib/x86_64-linux-gnu/libidn.so.11

# ➤ Tắt Postfix nếu có
systemctl stop postfix || true
systemctl disable postfix || true

# ➤ Tải và giải nén Zimbra OSE 10.1.7
cd /opt
wget -c https://files.zimbra.com/downloads/10.1.7_GA/zcs-10.1.7_GA.tgz
tar xzvf zcs-*.tgz
cd $(find . -maxdepth 1 -type d -name "zcs-10.1.7*" | head -n1)

# ➤ Tự động trả lời installer
cat <<EOF > /tmp/keystrokes
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
YourStrongPass123
r
a
yes

yes
no
EOF

# ➤ Chạy installer
./install.sh < /tmp/keystrokes

# ➤ Khởi động lại Zimbra
su - zimbra -c 'zmcontrol restart'

# ➤ Thông tin kết thúc
cat <<INFO
--------------------------------
✅ Zimbra 10.1.7 đã cài đặt xong!
🔗 Admin Console: https://$FQDN:7071
📧 Username: admin@$DOMAIN
🔑 Password: YourStrongPass123
📬 Webmail: https://$FQDN
🛠 Tạo DKIM: /opt/zimbra/libexec/zmdkimkeyutil -a -d $DOMAIN
--------------------------------
INFO
