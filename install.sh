#!/bin/bash

# =========================================================
# File: install.sh
# Chức năng: Script cài đặt ban đầu (tải sing-box, thiết lập môi trường)
# =========================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}Đang tiến hành cài đặt Nast Sing-box VVC...${NC}"

# Kiểm tra quyền root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[LỖI] Vui lòng chạy lệnh bằng quyền root (sudo -i).${NC}"
    exit 1
fi

# Cài đặt các gói phụ thuộc
echo -e "${YELLOW}Đang cài đặt các gói phụ thuộc (curl, wget, jq, git, openssl, netcat, uuid-runtime)...${NC}"
apt-get update -y
apt-get install -y curl wget jq git openssl netcat-openbsd uuid-runtime

# Thiết lập thư mục và kéo mã nguồn từ git
REPO_URL="https://github.com/Vivancang592/nat_singbox_vvc.git"
BASE_DIR="/root/nast-singbox-vvc"

if [ -d "$BASE_DIR/.git" ]; then
    echo -e "${YELLOW}Thư mục dự án đã tồn tại, tiến hành cập nhật code từ git...${NC}"
    cd "$BASE_DIR" && git pull
else
    echo -e "${YELLOW}Đang tải cấu trúc dự án từ Github...${NC}"
    git clone "$REPO_URL" "$BASE_DIR"
fi

cd "$BASE_DIR" || exit 1
chmod +x install.sh update.sh main.sh modules/*.sh

# Tạo cấu trúc thư mục chứa data và chứng chỉ
mkdir -p "$BASE_DIR/data" "$BASE_DIR/certs"

# Tự động tạo chứng chỉ tự ký (Self-signed) nếu chưa có
if [[ ! -f "$BASE_DIR/certs/cert.crt" ]] || [[ ! -f "$BASE_DIR/certs/cert.key" ]]; then
    echo -e "${YELLOW}Đang tạo chứng chỉ SSL tự ký mặc định...${NC}"
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
        -keyout "$BASE_DIR/certs/cert.key" \
        -out "$BASE_DIR/certs/cert.crt" \
        -subj "/C=US/ST=California/L=Los Angeles/O=Bing/OU=IT/CN=bing.com" >/dev/null 2>&1
    chmod 644 "$BASE_DIR/certs/cert.crt"
    chmod 600 "$BASE_DIR/certs/cert.key"
    echo -e "${GREEN}Đã tạo chứng chỉ tại thư mục certs/${NC}"
fi

# Tự động tạo các file database mặc định nếu chưa có
if [ ! -f "$BASE_DIR/data/nodes.json" ]; then
    echo "[]" > "$BASE_DIR/data/nodes.json"
fi

if [ ! -f "$BASE_DIR/data/domain.json" ]; then
    echo "[]" > "$BASE_DIR/data/domain.json"
fi

# Tự động tạo user admin
if [ ! -f "$BASE_DIR/data/users.json" ]; then
    ADMIN_UUID=$(uuidgen)
    echo "[{\"name\": \"admin\", \"uuid\": \"$ADMIN_UUID\"}]" > "$BASE_DIR/data/users.json"
    echo -e "${GREEN}Đã khởi tạo user admin mặc định với UUID: $ADMIN_UUID${NC}"
fi

# Nhận diện OS và cài đặt Sing-box Core
echo -e "${YELLOW}Đang kiểm tra hệ điều hành và cài đặt Sing-box core...${NC}"
ARCH=$(uname -m)
case "$ARCH" in
    x86_64) SB_ARCH="amd64" ;;
    aarch64) SB_ARCH="arm64" ;;
    *) echo -e "${RED}[LỖI] Không hỗ trợ kiến trúc CPU: $ARCH${NC}"; exit 1 ;;
esac

SB_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name)
SB_URL="https://github.com/SagerNet/sing-box/releases/download/${SB_VERSION}/sing-box-${SB_VERSION#v}-linux-${SB_ARCH}.tar.gz"

wget -qO sing-box.tar.gz "$SB_URL"
tar -xzf sing-box.tar.gz
mv sing-box-*/sing-box /usr/local/bin/
rm -rf sing-box.tar.gz sing-box-*
chmod +x /usr/local/bin/sing-box

# Cài đặt file systemd services
echo -e "${YELLOW}Đang thiết lập systemd services...${NC}"
cp "$BASE_DIR/templates/sing-box.service" /etc/systemd/system/
cp "$BASE_DIR/templates/manager.service" /etc/systemd/system/

# Chạy build_config lần đầu
source "$BASE_DIR/modules/utils.sh"
build_config_json

# Khởi động dịch vụ
systemctl daemon-reload
systemctl enable sing-box
systemctl enable manager
systemctl start sing-box
systemctl start manager

# Tạo lệnh tắt cho CLI (vvc)
ln -sf "$BASE_DIR/main.sh" /usr/local/bin/vvc

echo -e "${GREEN}[THÀNH CÔNG] Quá trình cài đặt hoàn tất!${NC}"
echo -e "${YELLOW}=> Vui lòng gõ lệnh: ${CYAN}vvc${YELLOW} để mở menu quản lý.${NC}"