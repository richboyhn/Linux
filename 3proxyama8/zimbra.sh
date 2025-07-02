
#!/bin/bash

# Zimbra 8.8.15 installer script for Ubuntu 22.04
# Compatible with UBUNTU18_64 build

# Exit on error
set -e

# Check root user
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root."
  exit 1
fi

# Check input domain
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <domain>"
  exit 1
fi

DOMAIN=$1
HOSTNAME="mail"
FQDN="$HOSTNAME.$DOMAIN"
PUBIP=$(curl -s http://myip.directadmin.com)

if [[ -z $PUBIP ]]; then
  echo "Unable to retrieve public IP. Check internet connectivity."
  exit 1
fi

# Set hostname and hosts
hostnamectl set-hostname "$FQDN"
echo "$HOSTNAME" > /etc/hostname

echo -e "127.0.0.1\tlocalhost\n$PUBIP\t$FQDN\t$HOSTNAME" > /etc/hosts
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Install required packages
apt update
apt install -y net-tools curl dnsutils sudo unzip pax libidn11 libaio1 resolvconf perl libgmp-dev unzip libperl5.34

# Disable and stop postfix if running
systemctl stop postfix || true
systemctl disable postfix || true

# Download and extract Zimbra
cd /opt
wget -c https://files.zimbra.com/downloads/8.8.15_GA/zcs-8.8.15_GA_3869.UBUNTU18_64.20190918004220.tgz

tar xzvf zcs-*.tgz
cd zcs-*

# Prepare keystrokes input
cat <<EOF > /tmp/installZimbra-keystrokes
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
123456abcA
r
a
yes

yes
no
EOF

# Install Zimbra silently
./install.sh < /tmp/installZimbra-keystrokes

# Restart Zimbra
su - zimbra -c 'zmcontrol restart'

# Output
cat <<INFO
---------------------------------------------------
Zimbra installation completed!
Admin Console: https://$FQDN:7071
Username: admin@$DOMAIN
Password: 123456abcA
Webmail: https://$FQDN
To setup DKIM: /opt/zimbra/libexec/zmdkimkeyutil -a -d $DOMAIN
---------------------------------------------------
INFO
