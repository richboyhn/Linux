#!/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Hàm tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Cài đặt 3proxy
install_3proxy() {
    echo "Installing 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Tạo cấu hình cho 3proxy (chạy SOCKS5 trên các cổng từ 22000 đến 22700)
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

# Proxy SOCKS5 trên các cổng từ 22000 đến 22700
$(seq 22000 22700 | while read port; do echo "socks -p$port -i0.0.0.0 -e0.0.0.0"; done)

flush
EOF
}

# Tạo dữ liệu proxy (IP và cổng cho SOCKS5)
gen_data() {
    FIRST_PORT=22000
    LAST_PORT=22700
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "$IP4:$port"
    done
}

# Cấu hình IP và cổng
WORKDIR="/home/bkns"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

# Lấy IP công cộng và IP6
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "IP địa phương: ${IP4}. Subnet địa chỉ IP6: ${IP6}"

# Tạo file data.txt
gen_data >$WORKDATA

# Cài đặt 3proxy
install_3proxy

# Tạo cấu hình 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Tạo file cấu hình ifconfig (thêm địa chỉ IP6 vào hệ thống)
gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA} > boot_ifconfig.sh
}
gen_ifconfig
chmod +x boot_ifconfig.sh /etc/rc.d/rc.local

# Cấu hình rc.local để 3proxy khởi động sau reboot
cat >>/etc/rc.d/rc.local <<EOF
#!/bin/bash
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

# Xóa các file không cần thiết
rm -rf /root/setup.sh
rm -rf /root/3proxy-3proxy-0.8.6

echo "Proxy SOCKS5 đã được cấu hình và khởi động."

# Xóa script sau khi hoàn tất
rm -f /root/proxy.sh
history -c
