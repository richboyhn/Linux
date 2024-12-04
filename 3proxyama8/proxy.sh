#!/bin/bash

# Đường dẫn công việc
WORKDIR="/home/bkns"
WORKDATA="${WORKDIR}/data.txt"

# IP địa phương và công cộng
IP4=$(curl -4 -s icanhazip.com)
IP6=$(curl -6 -s icanhazip.com | cut -f1-4 -d':')

# Kiểm tra thư mục công việc và tạo nếu chưa có
mkdir -p $WORKDIR && cd $WORKDIR

# Tạo dữ liệu proxy (ví dụ: user22000/abc123/192.168.0.1/22000/abcd1234:5678:9012:3456)
random() {
    tr </dev/urandom -dc A-Za-z0-9 | head -c5
    echo
}

gen64() {
    array=(1 2 3 4 5 6 7 8 9 0 a b c d e f)
    ip64() {
        echo "${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}${array[$RANDOM % 16]}"
    }
    echo "$1:$(ip64):$(ip64):$(ip64):$(ip64)"
}

gen_data() {
    FIRST_PORT=22000
    LAST_PORT=22700
    seq $FIRST_PORT $LAST_PORT | while read port; do
        echo "user$port/$(random)/$IP4/$port/$(gen64 $IP6)"
    done
}

# Lưu dữ liệu vào file data.txt
gen_data > $WORKDATA

# Cài đặt 3proxy
install_3proxy() {
    echo "Cài đặt 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd $WORKDIR
}

# Tạo cấu hình cho 3proxy
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

# Mở proxy SOCKS5 cho các cổng từ 22000 đến 22700
$(seq 22000 22700 | while read port; do echo "socks -p$port -i0.0.0.0 -e0.0.0.0"; done)

flush
EOF
}

# Lưu cấu hình 3proxy vào file
gen_3proxy > /usr/local/etc/3proxy/3proxy.cfg

# Tạo file proxy.txt cho người dùng
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 }' ${WORKDATA} > /home/bkns/proxy.txt
    echo "Đã tạo file proxy.txt tại /home/bkns/proxy.txt"
    cat /home/bkns/proxy.txt
}

# Kiểm tra và tạo file proxy.txt
gen_proxy_file_for_user

# Cấu hình iptables để mở các cổng từ 22000 đến 22700
echo "Cấu hình iptables để mở cổng..."
sudo iptables -A INPUT -p tcp --dport 22000:22700 -j ACCEPT
sudo iptables-save

# Cấu hình 3proxy để tự động khởi động sau reboot
echo "Cấu hình 3proxy khởi động sau reboot..."
cat >> /etc/rc.d/rc.local <<EOF
#!/bin/bash
ulimit -n 10048
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
EOF

chmod +x /etc/rc.d/rc.local
systemctl enable rc-local
systemctl start rc-local

# Kiểm tra lại và xóa script sau khi hoàn tất
echo "Khởi động 3proxy..."
/usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg

echo "Cài đặt và cấu hình proxy SOCKS5 hoàn tất."
