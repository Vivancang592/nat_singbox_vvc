#!/bin/bash

# =========================================================
# File: update.sh
# Chức năng: Cập nhật an toàn phiên bản script từ Git và Sing-box core
# =========================================================

source /root/nast-singbox-vvc/modules/utils.sh

clear
echo -e "${BLUE}=================================================${NC}"
echo -e "${YELLOW}            MENU CẬP NHẬT HỆ THỐNG${NC}"
echo -e "${BLUE}=================================================${NC}"
echo -e "${YELLOW} 1.${NC} Cập nhật mã nguồn Script"
echo -e "${GREEN} 2.${NC} Cập nhật Sing-box Core"
echo -e "${RED} 0.${NC} Quay lại menu chính"
echo -e "${BLUE}=================================================${NC}"
read -p "Nhập lựa chọn của bạn: " choice

case $choice in
    1)
        info "Đang tiến hành kéo bản cập nhật mã nguồn từ Git..."
        cd "$BASE_DIR" || exit
        
        # An toàn 1: Ép đồng bộ mã nguồn mới nhất từ repo, bỏ qua các sửa đổi rác ở local.
        # Thao tác này CHỈ tác động lên các file do git quản lý. 
        # Thư mục data/ và certs/ không bị ảnh hưởng vì không nằm trong source code gốc.
        git fetch --all
        if git reset --hard origin/main; then
            chmod +x install.sh update.sh main.sh modules/*.sh
            success "Cập nhật mã nguồn hoàn tất! Dữ liệu của bạn được bảo toàn."
        else
            die "Không thể kết nối đến Github. Cập nhật mã nguồn thất bại!"
        fi
        ;;
    2)
        info "Đang kiểm tra phiên bản Sing-box Core..."
        ARCH=$(uname -m)
        case "$ARCH" in
            x86_64) SB_ARCH="amd64" ;;
            aarch64) SB_ARCH="arm64" ;;
            *) die "Không hỗ trợ kiến trúc CPU: $ARCH" ;;
        esac
        
        SB_VERSION=$(curl -s "https://api.github.com/repos/SagerNet/sing-box/releases/latest" | jq -r .tag_name)
        
        if [[ -z "$SB_VERSION" || "$SB_VERSION" == "null" ]]; then
            die "Không thể lấy được thông tin phiên bản mới từ Github, vui lòng thử lại sau."
        fi

        CURRENT_VERSION=$(/usr/local/bin/sing-box version 2>/dev/null | grep -i "version" | awk '{print $3}')
        
        if [[ "v$CURRENT_VERSION" == "$SB_VERSION" ]]; then
            info "Sing-box hiện đang ở phiên bản mới nhất ($SB_VERSION). Không cần cập nhật."
        else
            info "Bắt đầu tải phiên bản $SB_VERSION về thư mục tạm..."
            SB_URL="https://github.com/SagerNet/sing-box/releases/download/${SB_VERSION}/sing-box-${SB_VERSION#v}-linux-${SB_ARCH}.tar.gz"
            
            # An toàn 2: Tải về file tạm và kiểm tra xem có giải nén thành công không
            rm -rf /tmp/sing-box-update
            mkdir -p /tmp/sing-box-update
            
            if wget -qO /tmp/sing-box-update/sing-box.tar.gz "$SB_URL"; then
                tar -xzf /tmp/sing-box-update/sing-box.tar.gz -C /tmp/sing-box-update/
                
                # Tìm đường dẫn file binary sing-box vừa giải nén
                NEW_CORE_PATH=$(find /tmp/sing-box-update -type f -name "sing-box" | head -n 1)
                
                if [[ -n "$NEW_CORE_PATH" && -x "$NEW_CORE_PATH" ]]; then
                    info "Tải và giải nén thành công, đang tiến hành thay thế lõi..."
                    stop_singbox
                    
                    # Backup nhẹ lõi cũ trong vài giây trước khi đè
                    mv /usr/local/bin/sing-box /usr/local/bin/sing-box.bak
                    mv "$NEW_CORE_PATH" /usr/local/bin/sing-box
                    chmod +x /usr/local/bin/sing-box
                    rm -f /usr/local/bin/sing-box.bak
                    
                    start_singbox
                    success "Đã cập nhật Sing-box Core lên $SB_VERSION thành công!"
                else
                    die "Giải nén tệp tin lõi thất bại. Hệ thống cũ vẫn được giữ nguyên an toàn."
                fi
            else
                die "Không thể tải lõi Sing-box từ Github. Cập nhật huỷ bỏ, hệ thống cũ không bị ảnh hưởng."
            fi
            
            # Dọn rác
            rm -rf /tmp/sing-box-update
        fi
        ;;
    0)
        exit 0
        ;;
    *)
        echo -e "${RED}[LỖI] Lựa chọn không hợp lệ!${NC}"
        ;;
esac