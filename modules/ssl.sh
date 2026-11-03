#!/bin/bash

# =========================================================
# File: modules/ssl.sh
# Chức năng: Xin chứng chỉ SSL Cloudflare (lưu file riêng biệt không ghi đè)
# =========================================================

BASE_DIR="/root/nast-singbox-vvc"
source "$BASE_DIR/modules/utils.sh"

while true; do
    clear
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${YELLOW}           XIN CHỨNG CHỈ SSL CLOUDFLARE${NC}"
    echo -e "${BLUE}=================================================${NC}"
    echo -e "${GREEN} 1.${NC} Đăng ký chứng chỉ SSL qua Cloudflare"
    echo -e "${GREEN} 2.${NC} Xem danh sách chứng chỉ hiện có"
    echo -e "${RED} 0.${NC} Quay lại menu chính"
    echo -e "${BLUE}=================================================${NC}"
    read -p "Nhập lựa chọn của bạn: " ssl_choice

    case "$ssl_choice" in
        1)
            read -p "Nhập tên miền của bạn (vd: sub.domain.com): " domain
            read -p "Nhập Cloudflare Account Email: " cf_email
            read -p "Nhập Cloudflare Global API Key hoặc API Token: " cf_key

            if [[ -z "$domain" || -z "$cf_email" || -z "$cf_key" ]]; then
                echo -e "${RED}[LỖI] Vui lòng điền đầy đủ thông tin!${NC}"
                read -p "Nhấn Enter để tiếp tục..."
                continue
            fi

            info "Đang kiểm tra và cài đặt acme.sh..."
            if [[ ! -f "$HOME/.acme.sh/acme.sh" ]]; then
                curl https://get.acme.sh | sh -s email="$cf_email"
            fi

            export CF_Key="$cf_key"
            export CF_Email="$cf_email"

            info "Đang tiến hành xin chứng chỉ SSL cho domain: $domain..."
            ~/.acme.sh/acme.sh --set-default-ca --server zerossl
            ~/.acme.sh/acme.sh --issue --dns dns_cf -d "$domain"

            if [[ $? -eq 0 ]]; then
                mkdir -p "$BASE_DIR/certs"
                # Lưu ra file riêng theo tên domain, KHÔNG ghi đè file cũ
                ~/.acme.sh/acme.sh --install-cert -d "$domain" \
                    --key-file "$BASE_DIR/certs/${domain}.key" \
                    --fullchain-file "$BASE_DIR/certs/${domain}.crt"
                
                success "Xin và cài đặt chứng chỉ SSL thành công cho domain $domain!"
                
                # Lưu thông tin domain vào domain.json
                jq --arg dom "$domain" '. + [{"domain": $dom}]' "$DATA_DIR/domain.json" > "$DATA_DIR/domain.json.tmp" && mv "$DATA_DIR/domain.json.tmp" "$DATA_DIR/domain.json"
            else
                echo -e "${RED}[LỖI] Xin chứng chỉ thất bại, vui lòng kiểm tra lại thông tin API hoặc Domain.${NC}"
            fi
            read -p "Nhấn Enter để tiếp tục..."
            ;;
        2)
            clear
            echo -e "${CYAN}--- DANH SÁCH CHỨNG CHỈ SSL TRONG THƯ MỤC CERTS/ ---${NC}"
            if ls "$BASE_DIR/certs/"*.crt 1>/dev/null 2>&1; then
                for cert in "$BASE_DIR/certs/"*.crt; do
                    echo -e "${GREEN}File: $(basename "$cert")${NC}"
                    openssl x509 -in "$cert" -text -noout | grep -E "Subject:|Not After"
                    echo "-------------------------------------------------"
                done
            else
                echo -e "${YELLOW}Chưa có chứng chỉ SSL riêng nào được tạo.${NC}"
            fi
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