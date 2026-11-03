#!/bin/bash

# =========================================================
# File: main.sh
# Chức năng: Entry point cho lệnh CLI 'vvc' / Daemon service
# =========================================================

BASE_DIR="/root/nast-singbox-vvc"

# Xử lý Service chạy ngầm
if [[ "$1" == "daemon" ]]; then
    while true; do
        # Các logic xử lý ngầm (api, reset pass, monitor port...) có thể để ở đây
        sleep 60
    done
    exit 0
fi

# Load thư viện utils dùng chung
source "$BASE_DIR/modules/utils.sh"

# Kiểm tra quyền khi chạy lệnh vvc
if [[ "$EUID" -ne 0 ]]; then
    die "Vui lòng chạy lệnh bằng quyền root."
fi

# Hàm xử lý gỡ cài đặt an toàn
uninstall_system() {
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${BLUE}||${NC}     ${RED}CẢNH BÁO: GỠ CÀI ĐẶT TOÀN BỘ HỆ THỐNG${NC}   ${BLUE}||${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}Thao tác này sẽ xoá toàn bộ dữ liệu và cấu hình.${NC}"
    echo -e "${RED}DỮ LIỆU SẼ KHÔNG THỂ KHÔI PHỤC!${NC}"
    echo -e ""
    read -p "Bạn có CHẮC CHẮN muốn xoá toàn bộ? (y/N): " confirm_1
    if [[ "$confirm_1" != "y" && "$confirm_1" != "Y" ]]; then
        info "Đã huỷ thao tác gỡ cài đặt."
        return
    fi
    
    info "Đang tiến hành dừng các dịch vụ ngầm..."
    systemctl stop sing-box manager
    systemctl disable sing-box manager
    
    info "Đang xoá systemd services..."
    rm -f /etc/systemd/system/sing-box.service
    rm -f /etc/systemd/system/manager.service
    systemctl daemon-reload
    
    info "Đang xoá lõi Sing-box..."
    rm -f /usr/local/bin/sing-box
    
    info "Đang xoá lệnh CLI 'vvc'..."
    rm -f /usr/local/bin/vvc
    
    info "Đang xoá thư mục mã nguồn và dữ liệu..."
    rm -rf "$BASE_DIR"
    
    success "Đã gỡ cài đặt thành công toàn bộ hệ thống Nast Sing-box."
    exit 0
}

# Vòng lặp hiển thị Menu CLI
while true; do
    clear
    CORE_VER=$(/usr/local/bin/sing-box version 2>/dev/null | grep -i version | awk '{print $3}')
    CORE_VER=${CORE_VER:-"Chưa cài đặt"}
    SYS_STATUS=$(check_singbox_status | grep -v "Thông tin:" | head -n 1)

    echo -e "${BLUE}=========================================================================${NC}"
    echo -e "${BLUE}||${NC}                          ${YELLOW}MENU NAST SING-BOX VVC${NC}                     ${BLUE}||${NC}"
    echo -e "${BLUE}=========================================================================${NC}"
    echo -e " ${CYAN}Tác Giả${NC}: ${YELLOW}Vietnamvpn${NC}    | ${CYAN}Singbox Core${NC}: ${GREEN}${CORE_VER}${NC}"
    echo -e " ${CYAN}Trạng Thái${NC} : ${GREEN}${SYS_STATUS} | ${CYAN}Trang Web${NC}  : ${YELLOW}https://linksub24h.com${NC}"
    echo -e "${BLUE}=========================================================================${NC}"
    echo -e "${YELLOW} 1.${NC} Quản Lý Node Server    | ${YELLOW} 4.${NC} Cập Nhật Hệ Thống"
    echo -e "${YELLOW} 2.${NC} Quản Lý Sing-Box       | ${YELLOW} 5.${NC} Gỡ Cài Đặt Hệ Thống"
    echo -e "${YELLOW} 3.${NC} Quản Lý SSL Cloudflare | ${RED} 0.${NC} Thoát Khỏi Hệ Thống"
    echo -e "${BLUE}=========================================================================${NC}"
    read -p "Vui lòng nhập lựa chọn của bạn: " main_choice

    case "$main_choice" in
        1)
            bash "$BASE_DIR/modules/nodes.sh"
            ;;
        2)
            bash "$BASE_DIR/modules/system.sh"
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        3)
            bash "$BASE_DIR/modules/ssl.sh"
            ;;
        4)
            bash "$BASE_DIR/update.sh"
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        5)
            uninstall_system
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        0)
            echo -e "${YELLOW}Đã Thoát${NC} ${GREEN}MENU NAST SING-BOX VVC${NC} ${YELLOW}Hẹn Gặp Lại.${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}[LỖI] Lựa chọn không hợp lệ, vui lòng thử lại!${NC}"
            sleep 2
            ;;
    esac
done