#!/bin/sh
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Hàm tạo chuỗi ngẫu nhiên
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

# Mảng các giá trị để tạo địa chỉ IP
array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)

# Hàm tạo địa chỉ IPv6 ngẫu nhiên
gen64() {
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

# Cài đặt 3proxy
install_3proxy() {
    echo "installing 3proxy"
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Hàm tạo cấu hình cho 3proxy
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

# Cấu hình SOCKS Proxy cho các cổng từ 22000 đến 22700
$(seq 22000 22700 | while read port; do echo "socks -p$port -i0.0.0.0 -e0.0.0.0"; done)

flush
EOF
}

# Hàm tạo file proxy cho người dùng
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 }' ${WORKDATA} > proxy.txt
}

# Hàm tạo dữ liệu để cấu hình proxy
gen_data() {
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "user$port/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Hàm tạo cấu hình ifconfig cho IPv6
gen_ifconfig() {
    awk -F "/" '{print "ifconfig eth0 inet6 add " $5 "/64"}' ${WORKDATA} > boot_ifconfig.sh
}

# Cài đặt 3proxy và tạo cấu hình
echo "installing apps"
install_3proxy

WORKDIR="/home/bkns"
WORKDATA="${WORKDIR}/data.txt"
mkdir -p $WORKDIR && cd $WORKDIR

# Lấy địa chỉ IP nội bộ và IPv6
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

echo "Internal IP = ${IP4}. External sub for IP6 = ${IP6}"

# Cài đặt dải cổng cho proxy
FIRST_PORT=22000
LAST_PORT=22700

# Tạo dữ liệu và cấu hình
gen_data >$WORKDIR/data.txt
gen_ifconfig
chmod +x boot_ifconfig.sh /etc/rc.d/rc.local

# Tạo cấu hình cho 3proxy
gen_3proxy >/usr/local/etc/3proxy/3proxy.cfg

# Thêm script khởi động vào /etc/rc.local
cat >>/etc/rc.d/rc.local <<EOF
bash ${WORKDIR}/boot_ifconfig.sh
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

# Tạo file proxy cho người dùng
gen_proxy_file_for_user
rm -rf /root/setup.sh
rm -rf /root/3proxy-3proxy-0.8.6

echo "Starting Proxy"

# Xóa script sau khi chạy thành công
rm -f /root/proxy.sh
