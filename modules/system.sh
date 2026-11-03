#!/bin/bash

# =========================================================
# File: modules/system.sh
# Chức năng: Menu bật, tắt, khởi động sing-box và xem logs
# =========================================================

BASE_DIR="/root/nast-singbox-vvc"
source "$BASE_DIR/modules/utils.sh"

while true; do
    clear
    echo -e "${BLUE}===============================================================${NC}"
    echo -e "${YELLOW}              QUẢN LÝ HỆ THỐNG SING-BOX${NC}"
    echo -e "${BLUE}===============================================================${NC}"
    echo -e " Trạng thái hiện tại : $(check_singbox_status) | Phiên bản Sing-box : ${GREEN}$(/usr/local/bin/sing-box version 2>/dev/null | grep -i "version" | awk '{print $3}')${NC}"
    echo -e "${BLUE}===============================================================${NC}"
    echo -e "${GREEN} 1.${NC} Khởi động Sing-box"
    echo -e "${GREEN} 2.${NC} Dừng Sing-box"
    echo -e "${GREEN} 3.${NC} Khởi động lại Sing-box"
    echo -e "${GREEN} 4.${NC} Xem nhật ký hoạt động"
    echo -e "${RED} 0.${NC} Quay lại menu chính"
    echo -e "${BLUE}===============================================================${NC}"
    read -p "Nhập lựa chọn của bạn: " sys_choice

    case "$sys_choice" in
        1)
            start_singbox
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        2)
            stop_singbox
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        3)
            restart_singbox
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        4)
            clear
            echo -e "${CYAN}--- 50 DÒNG NHẬT KÝ HOẠT ĐỘNG GẦN NHẤT ---${NC}"
            journalctl -u sing-box -n 50 --no-pager
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        0)
            break
            ;;
        *)
            echo -e "${RED}[LỖI] Lựa chọn không hợp lệ!${NC}"
            sleep 1
            ;;
    esac
done