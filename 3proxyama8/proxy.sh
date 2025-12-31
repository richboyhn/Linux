#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

install_3proxy() {
    echo "Installing build tools..."
    dnf install -y gcc make wget curl net-tools

    echo "Downloading 3proxy..."
    cd /root || exit
    wget -q https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz
    tar -xzf 0.8.13.tar.gz
    cd 3proxy-0.8.13 || exit

    echo "Building 3proxy..."
    make -f Makefile.Linux

    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
}

gen_3proxy() {
cat <<EOF
daemon
maxconn 4000
nserver 1.1.1.1
nserver 8.8.4.4
nserver 2001:4860:4860::8888
nserver 2001:4860:4860::8844
nscache 65536
timeouts 1 5 30 60 180 1800 15 60
setgid 65535
setuid 65535
stacksize 6291456
flush

auth none

$(awk -F "/" '{print \
"allow *\n" \
"proxy -6 -n -a -p" $4 " -i" $3 " -e" $5 "\n" \
"flush\n"}' ${WORKDATA})
EOF
}

gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4}' ${WORKDATA} > proxy.txt
}

gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "x/x/$IP4/$port/$(gen64 $IP6)"
    done
}

gen_ifconfig() {
    awk -F "/" '{print "ip -6 addr add " $5 "/64 dev eth0"}' ${WORKDATA}
}

echo "==== START INSTALL ===="

install_3proxy

WORKDIR="/home/bkns"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR
cd $WORKDIR || exit

IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d:)

echo "IPv4 = $IP4"
echo "IPv6 prefix = $IP6"

if [ -z "$IP6" ]; then
    echo "❌ VPS KHÔNG CÓ IPV6 – SCRIPT DỪNG"
    exit 1
fi

FIRST_PORT=22000
LAST_PORT=22700

gen_data > $WORKDATA
gen_ifconfig > boot_ifconfig.sh
chmod +x boot_ifconfig.sh

gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# Create rc.local
cat >/etc/rc.d/rc.local <<EOF
#!/bin/bash
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local

# Enable rc-local for AlmaLinux 8
systemctl enable rc-local.service
systemctl restart rc-local.service

bash /etc/rc.d/rc.local

gen_proxy_file_for_user

echo "===================================="
echo " 3PROXY IPV6 STARTED (NO AUTH)"
echo " Proxy list: /home/bkns/proxy.txt"
echo " Format: IP:PORT"
echo "===================================="
