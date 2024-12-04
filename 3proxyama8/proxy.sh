#!/bin/bash

# Cài đặt 3proxy nếu chưa cài
install_3proxy() {
    echo "Cài đặt 3proxy..."
    URL="https://github.com/z3APA3A/3proxy/archive/refs/tags/0.8.13.tar.gz"
    wget -qO- $URL | tar -xzf-
    cd 3proxy-0.8.13
    make -f Makefile.Linux
    mkdir -p /usr/local/etc/3proxy/{bin,logs,stat}
    cp src/3proxy /usr/local/etc/3proxy/bin/
    cd ..
}

# Mở cổng từ 22000 đến 22700 cho TCP


# Tạo file cấu hình 3proxy
gen_3proxy_cfg() {
    echo "Tạo cấu hình 3proxy..."
    cat <<EOF > /usr/local/etc/3proxy/3proxy.cfg
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

# Cấu hình SOCKS5 Proxy cho các cổng từ 22000 đến 22700
$(for port in {22000..22700}; do echo "socks -p$port -i0.0.0.0 -e0.0.0.0"; done)

flush
EOF
}

# Khởi động 3proxy với cấu hình đã tạo
start_3proxy() {
    echo "Khởi động 3proxy..."
    sudo /usr/local/etc/3proxy/bin/3proxy /usr/local/etc/3proxy/3proxy.cfg
}

# Cấu hình iptables nếu cần
configure_iptables() {
    echo "Cấu hình iptables để mở cổng..."
    sudo iptables -A INPUT -p tcp --dport 22000:22700 -j ACCEPT
    sudo service iptables save
    sudo systemctl restart iptables
}

# Tạo file proxy.txt cho người dùng
gen_proxy_file_for_user() {
    awk -F "/" '{print $3 ":" $4 }' ${WORKDATA} > /home/bkns/proxy.txt
    echo "File proxy.txt đã được tạo tại /home/bkns/proxy.txt"
}

# Kiểm tra nếu script đang chạy với quyền sudo
if [ "$(id -u)" -ne "0" ]; then
    echo "Vui lòng chạy script này với quyền sudo."
    exit 1
fi

# Cài đặt 3proxy
install_3proxy



# Tạo file cấu hình 3proxy
gen_3proxy_cfg

# Khởi động dịch vụ 3proxy
start_3proxy

# Cấu hình iptables
configure_iptables

# Tạo file proxy.txt cho người dùng
gen_proxy_file_for_user

echo "Mọi thứ đã được cấu hình xong!"
