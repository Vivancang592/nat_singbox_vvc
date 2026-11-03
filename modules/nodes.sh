#!/bin/bash

# =========================================================
# File: modules/nodes.sh
# Chức năng: Quản lý nodes
# =========================================================

BASE_DIR="/root/nast-singbox-vvc"
DATA_DIR="$BASE_DIR/data"
NODES_FILE="$DATA_DIR/nodes.json"
DOMAIN_FILE="$DATA_DIR/domain.json"
USERS_FILE="$DATA_DIR/users.json"

mkdir -p "$DATA_DIR"

if [ ! -f "$NODES_FILE" ]; then
    echo "[]" > "$NODES_FILE"
fi

if [ ! -f "$DOMAIN_FILE" ]; then
    echo "[]" > "$DOMAIN_FILE"
fi

if [ ! -f "$USERS_FILE" ]; then
    echo "[]" > "$USERS_FILE"
fi

if [ -f "$BASE_DIR/modules/utils.sh" ]; then
    source "$BASE_DIR/modules/utils.sh"
fi

# ====================================================================
# CÁC HÀM PHỤ TRỢ (HELPER) KIỂM TRA VÀ TỰ ĐỘNG TẠO DỮ LIỆU
# ====================================================================

check_port_usage() {
    local check_port=$1
    if grep -q "\"port\": *$check_port\b" "$NODES_FILE" 2>/dev/null; then
        return 1
    fi
    if command -v ss >/dev/null 2>&1; then
        if ss -tuln | grep -qE ":$check_port\b"; then
            return 1
        fi
    elif command -v netstat >/dev/null 2>&1; then
         if netstat -tuln | grep -qE ":$check_port\b"; then
            return 1
         fi
    fi
    return 0
}

get_random_port() {
    while true; do
        local rand_port=$((RANDOM % 4001 + 2000))
        if check_port_usage "$rand_port"; then
            echo "$rand_port"
            return
        fi
    done
}

open_firewall_port() {
    local port=$1
    echo -e "${YELLOW} Đang kiểm tra và mở port $port trên tường lửa...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        ufw allow "$port"/tcp >/dev/null 2>&1
        ufw allow "$port"/udp >/dev/null 2>&1
    fi
    if command -v iptables >/dev/null 2>&1; then
        iptables -I INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
        iptables -I INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null
        if command -v netfilter-persistent >/dev/null 2>&1; then
            netfilter-persistent save >/dev/null 2>&1
        fi
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --add-port="${port}/tcp" --permanent >/dev/null 2>&1
        firewall-cmd --add-port="${port}/udp" --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
    echo -e "${GREEN} -> Đã mở port $port thành công.${NC}"
}

close_firewall_port() {
    local port=$1
    echo -e "${YELLOW} Đang đóng port $port trên tường lửa...${NC}"
    if command -v ufw >/dev/null 2>&1; then
        ufw delete allow "$port"/tcp >/dev/null 2>&1
        ufw delete allow "$port"/udp >/dev/null 2>&1
    fi
    if command -v iptables >/dev/null 2>&1; then
        iptables -D INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null
        iptables -D INPUT -p udp --dport "$port" -j ACCEPT 2>/dev/null
        if command -v netfilter-persistent >/dev/null 2>&1; then
            netfilter-persistent save >/dev/null 2>&1
        fi
    fi
    if command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --remove-port="${port}/tcp" --permanent >/dev/null 2>&1
        firewall-cmd --remove-port="${port}/udp" --permanent >/dev/null 2>&1
        firewall-cmd --reload >/dev/null 2>&1
    fi
    echo -e "${GREEN} -> Đã đóng port $port thành công.${NC}"
}

save_domain_mapping() {
    local tag=$1
    local domain=$2
    if [ -n "$tag" ] && [ -n "$domain" ]; then
        if [ ! -s "$DOMAIN_FILE" ] || ! jq -e . "$DOMAIN_FILE" >/dev/null 2>&1; then
            echo "[]" > "$DOMAIN_FILE"
        fi
        jq --arg tag "$tag" --arg domain "$domain" \
           '[.[] | select(.tag != $tag)] + [{"tag": $tag, "domain": $domain}]' \
           "$DOMAIN_FILE" > "$DOMAIN_FILE.tmp" && mv "$DOMAIN_FILE.tmp" "$DOMAIN_FILE"
    fi
}

ASKED_PORT=""
ask_port() {
    while true; do
        read -p " Nhập Port [Để trống = ngẫu nhiên 2000-6000]: " ASKED_PORT
        if [ -z "$ASKED_PORT" ]; then
            ASKED_PORT=$(get_random_port)
            echo -e "${GREEN} -> Đã chọn Port ngẫu nhiên chưa sử dụng: $ASKED_PORT${NC}"
            break
        elif ! [[ "$ASKED_PORT" =~ ^[0-9]+$ ]] || [ "$ASKED_PORT" -lt 1 ] || [ "$ASKED_PORT" -gt 65535 ]; then
            echo -e "${RED}Lỗi: Port không hợp lệ!${NC}"
        elif ! check_port_usage "$ASKED_PORT"; then
            echo -e "${RED}Lỗi: Port $ASKED_PORT đã có người dùng, chọn port khác!${NC}"
        else
            break
        fi
    done
    open_firewall_port "$ASKED_PORT"
}

ASKED_SNI=""
ask_sni() {
    read -p " Nhập SNI (Server Name) [Để trống = tự tạo ngẫu nhiên]: " ASKED_SNI
    if [ -z "$ASKED_SNI" ]; then
        local snis=("itunes.apple.com" "aws.amazon.com" "www.bing.com" "s0.awsstatic.com" "gateway.icloud.com")
        local index=$((RANDOM % ${#snis[@]}))
        ASKED_SNI="${snis[$index]}"
        echo -e "${GREEN} -> Đã tự chọn SNI ngẫu nhiên: $ASKED_SNI${NC}"
    fi
}

ASKED_DOMAIN=""
ask_domain() {
    read -p " Nhập Tên miền (Domain) [Để trống = lấy IP VPS]: " ASKED_DOMAIN
    if [ -z "$ASKED_DOMAIN" ]; then
        local ip=$(curl -s4 ifconfig.me || curl -s4 icanhazip.com || echo "127.0.0.1")
        ASKED_DOMAIN="$ip"
        echo -e "${GREEN} -> Đã tự động lấy Domain theo IP VPS: $ASKED_DOMAIN${NC}"
    fi
}

ASKED_TAG=""
ask_tag() {
    local default_prefix=$1
    read -p " Nhập Tag cho Node [Để trống = tự động theo quốc gia & port]: " ASKED_TAG
    if [ -z "$ASKED_TAG" ]; then
        local country
        country=$(curl -s ipinfo.io/country 2>/dev/null | tr '[:lower:]' '[:upper:]')
        [[ -z "$country" || "$country" == "NULL" ]] && country="VN"
        ASKED_TAG="${country}-${ASKED_PORT}"
        echo -e "${GREEN} -> Đã tạo Tag tự động theo quốc gia và port: $ASKED_TAG${NC}"
    fi
}

ASKED_CERT=""
ASKED_KEY=""
ask_cert() {
    local cert_dir="$BASE_DIR/certs"
    mkdir -p "$cert_dir"

    local certs=()
    while IFS= read -r file; do
        [ -n "$file" ] && certs+=("$file")
    done < <(find "$cert_dir" -type f \( -name "*.crt" -o -name "*.pem" -o -name "fullchain.pem" \) ! -name "*.key" ! -name "privkey.pem" 2>/dev/null)

    if [ ${#certs[@]} -eq 0 ]; then
        echo -e "${YELLOW} -> Không tìm thấy chứng chỉ nào trong $cert_dir, dùng mặc định:${NC}"
        ASKED_CERT="$cert_dir/cert.crt"
        ASKED_KEY="$cert_dir/cert.key"
    elif [ ${#certs[@]} -eq 1 ]; then
        ASKED_CERT="${certs[0]}"
        local dir_path=$(dirname "$ASKED_CERT")
        local base_name=$(basename "$ASKED_CERT" | sed -E 's/\.(crt|pem)$//')

        if [ -f "$dir_path/$base_name.key" ]; then
            ASKED_KEY="$dir_path/$base_name.key"
        elif [ -f "$dir_path/privkey.pem" ]; then
            ASKED_KEY="$dir_path/privkey.pem"
        else
            ASKED_KEY="$dir_path/cert.key"
        fi
        echo -e "${GREEN} -> Tự động nhận diện chứng chỉ duy nhất tìm thấy:${NC}"
    else
        echo -e "${YELLOW} -> Danh sách chứng chỉ tìm thấy trong $cert_dir:${NC}"
        for i in "${!certs[@]}"; do
            echo -e " ${GREEN}$((i+1)).${NC} ${certs[$i]}"
        done
        read -p " Chọn số thứ tự chứng chỉ [1-${#certs[@]}]: " cert_choice
        if [[ "$cert_choice" =~ ^[0-9]+$ ]] && [ "$cert_choice" -ge 1 ] && [ "$cert_choice" -le "${#certs[@]}" ]; then
            ASKED_CERT="${certs[$((cert_choice-1))]}"
        else
            ASKED_CERT="${certs[0]}"
        fi

        local dir_path=$(dirname "$ASKED_CERT")
        local base_name=$(basename "$ASKED_CERT" | sed -E 's/\.(crt|pem)$//')
        if [ -f "$dir_path/$base_name.key" ]; then
            ASKED_KEY="$dir_path/$base_name.key"
        elif [ -f "$dir_path/privkey.pem" ]; then
            ASKED_KEY="$dir_path/privkey.pem"
        else
            ASKED_KEY="$dir_path/cert.key"
        fi
    fi

    echo -e "${GREEN}    Cert: $ASKED_CERT${NC}"
    echo -e "${GREEN}    Key:  $ASKED_KEY${NC}"
}

check_tag_exists() {
    if grep -q "\"tag\": \"$ASKED_TAG\"" "$NODES_FILE" 2>/dev/null; then
        echo -e "${RED}Lỗi: Node với tag '$ASKED_TAG' đã tồn tại! Hủy bỏ thao tác.${NC}"
        sleep 2
        return 1
    fi
    return 0
}

# ====================================================================
# CÁC HÀM AUTO-GENERATE
# ====================================================================

AUTO_PK=""
AUTO_PUBK=""
generate_private_key() {
    if command -v sing-box &> /dev/null; then
        local kp=$(sing-box generate reality-keypair)
        AUTO_PK=$(echo "$kp" | grep -iE "private" | awk -F':' '{print $2}' | tr -d ' \r\n')
        AUTO_PUBK=$(echo "$kp" | grep -iE "public" | awk -F':' '{print $2}' | tr -d ' \r\n')
    fi
    
    if [ -z "$AUTO_PK" ]; then
        AUTO_PK=$(openssl rand -base64 32 | tr '+/' '-_' | tr -d '=' | head -c 43)
    fi

    if [ -z "$AUTO_PUBK" ] && command -v sing-box &> /dev/null; then
        AUTO_PUBK=$(sing-box x25519 "$AUTO_PK" 2>/dev/null | grep -i "Public" | awk '{print $NF}')
    fi
    
    echo -e "${GREEN} -> Đã tự động tạo Reality Keypair thành công.${NC}"
}

AUTO_SHORT_ID=""
generate_short_id() {
    if command -v openssl >/dev/null 2>&1; then
        AUTO_SHORT_ID=$(openssl rand -hex 4)
    else
        AUTO_SHORT_ID=$(tr -dc 'a-f0-9' </dev/urandom | head -c 8)
    fi
    echo -e "${GREEN} -> Đã tự động tạo Short ID: $AUTO_SHORT_ID${NC}"
}

AUTO_UUID=""
generate_uuid() {
    if command -v uuidgen >/dev/null 2>&1; then
        AUTO_UUID=$(uuidgen)
    else
        AUTO_UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "12345678-1234-1234-1234-123456789abc")
    fi
    echo -e "${GREEN} -> Đã tự động tạo UUID.${NC}"
}

AUTO_PASS=""
generate_password() {
    AUTO_PASS=$(tr -dc 'a-zA-Z0-9' </dev/urandom | head -c 16)
    echo -e "${GREEN} -> Đã tự động tạo Password.${NC}"
}

# ====================================================================
# CÁC FORM TẠO NODE
# ====================================================================

form_vless_reality() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}||${NC}             ${YELLOW}THÊM NODE: VLESS REALITY (TCP)                 ${CYAN}||${NC}"
    echo -e "${CYAN}================================================================${NC}"
    
    if [ ! -s "$NODES_FILE" ] || ! jq -e . "$NODES_FILE" >/dev/null 2>&1; then
        echo "[]" > "$NODES_FILE"
    fi

    ask_port
    ask_sni
    ask_domain
    ask_tag "vless-reality"
    
    check_tag_exists || { ASKED_TAG=""; return; }

    generate_private_key
    generate_short_id

    jq --arg tag "$ASKED_TAG" \
       --arg protocol "vless-reality" \
       --argjson port "$ASKED_PORT" \
       --arg domain "$ASKED_DOMAIN" \
       --arg server_name "$ASKED_SNI" \
       --arg private_key "$AUTO_PK" \
       --arg public_key "$AUTO_PUBK" \
       --arg short_id "$AUTO_SHORT_ID" \
       '. += [{
           "tag": $tag,
           "protocol": $protocol,
           "port": $port,
           "domain": $domain,
           "server_name": $server_name,
           "private_key": $private_key,
           "public_key": $public_key,
           "short_id": $short_id
       }]' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"

    save_domain_mapping "$ASKED_TAG" "$ASKED_DOMAIN"
    echo -e "${GREEN}Thêm Node VLESS REALITY thành công! Tag: $ASKED_TAG${NC}"
    sleep 1
}

form_vless_ws_tls() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}||${NC}             ${YELLOW}THÊM NODE: VLESS WEBSOCKET TLS                 ${CYAN}||${NC}"
    echo -e "${CYAN}================================================================${NC}"

    ask_port
    ask_domain
    ask_cert
    ask_tag "vless-ws-tls"
    
    check_tag_exists || { ASKED_TAG=""; return; }

    local auto_ws_path="/ws-$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
    echo -e "${GREEN} -> Đã tự động tạo WS Path: $auto_ws_path${NC}"

    jq --arg tag "$ASKED_TAG" \
       --arg protocol "vless-ws-tls" \
       --argjson port "$ASKED_PORT" \
       --arg domain "$ASKED_DOMAIN" \
       --arg server_name "$ASKED_DOMAIN" \
       --arg ws_path "$auto_ws_path" \
       --arg cert_path "$ASKED_CERT" \
       --arg key_path "$ASKED_KEY" \
       '. += [{
           "tag": $tag,
           "protocol": $protocol,
           "port": $port,
           "domain": $domain,
           "server_name": $server_name,
           "ws_path": $ws_path,
           "cert_path": $cert_path,
           "key_path": $key_path
       }]' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"

    save_domain_mapping "$ASKED_TAG" "$ASKED_DOMAIN"
    echo -e "${GREEN}Thêm Node VLESS WS TLS thành công! Tag: $ASKED_TAG${NC}"
    sleep 1
}

form_vless_grpc_reality() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}||${NC}               ${YELLOW}THÊM NODE: VLESS gRPC REALITY                ${CYAN}||${NC}"
    echo -e "${CYAN}================================================================${NC}"

    ask_port
    ask_sni
    ask_domain
    ask_tag "vless-grpc-reality"
    
    check_tag_exists || { ASKED_TAG=""; return; }

    local auto_grpc="grpc-$(tr -dc 'a-z0-9' </dev/urandom | head -c 6)"
    echo -e "${GREEN} -> Đã tự động tạo gRPC Service: $auto_grpc${NC}"
    
    generate_private_key
    generate_short_id

    jq --arg tag "$ASKED_TAG" \
       --arg protocol "vless-grpc-reality" \
       --argjson port "$ASKED_PORT" \
       --arg domain "$ASKED_DOMAIN" \
       --arg service_name "$auto_grpc" \
       --arg server_name "$ASKED_SNI" \
       --arg private_key "$AUTO_PK" \
       --arg public_key "$AUTO_PUBK" \
       --arg short_id "$AUTO_SHORT_ID" \
       '. += [{
           "tag": $tag,
           "protocol": $protocol,
           "port": $port,
           "domain": $domain,
           "service_name": $service_name,
           "server_name": $server_name,
           "private_key": $private_key,
           "public_key": $public_key,
           "short_id": $short_id
       }]' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"

    save_domain_mapping "$ASKED_TAG" "$ASKED_DOMAIN"
    echo -e "${GREEN}Thêm Node VLESS gRPC REALITY thành công! Tag: $ASKED_TAG${NC}"
    sleep 1
}

form_hy2() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}||${NC}                 ${YELLOW}THÊM NODE: HYSTERIA 2                      ${CYAN}||${NC}"
    echo -e "${CYAN}================================================================${NC}"

    ask_port
    ask_domain
    ask_cert
    ask_tag "hy2"
    
    check_tag_exists || { ASKED_TAG=""; return; }

    generate_password
    local auto_up_mbps="1000"
    local auto_down_mbps="1000"
    echo -e "${GREEN} -> Đã tự động gán tốc độ UP/DOWN mặc định là 1000 Mbps.${NC}"

    jq --arg tag "$ASKED_TAG" \
       --arg protocol "hysteria2" \
       --argjson port "$ASKED_PORT" \
       --arg domain "$ASKED_DOMAIN" \
       --arg server_name "$ASKED_DOMAIN" \
       --arg password "$AUTO_PASS" \
       --argjson up_mbps "$auto_up_mbps" \
       --argjson down_mbps "$auto_down_mbps" \
       --arg cert_path "$ASKED_CERT" \
       --arg key_path "$ASKED_KEY" \
       '. += [{
           "tag": $tag,
           "protocol": $protocol,
           "port": $port,
           "domain": $domain,
           "server_name": $server_name,
           "password": $password,
           "up_mbps": $up_mbps,
           "down_mbps": $down_mbps,
           "cert_path": $cert_path,
           "key_path": $key_path
       }]' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"

    save_domain_mapping "$ASKED_TAG" "$ASKED_DOMAIN"
    echo -e "${GREEN}Thêm Node Hysteria 2 thành công! Tag: $ASKED_TAG${NC}"
    sleep 1
}

form_tuic() {
    clear
    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}||${NC}                      ${YELLOW}THÊM NODE: TUIC${NC}                       ${CYAN}||${NC}"
    echo -e "${CYAN}================================================================${NC}"

    ask_port
    ask_domain
    ask_cert
    ask_tag "tuic"
    
    check_tag_exists || { ASKED_TAG=""; return; }

    generate_uuid
    generate_password

    jq --arg tag "$ASKED_TAG" \
       --arg protocol "tuic" \
       --argjson port "$ASKED_PORT" \
       --arg domain "$ASKED_DOMAIN" \
       --arg server_name "$ASKED_DOMAIN" \
       --arg uuid "$AUTO_UUID" \
       --arg password "$AUTO_PASS" \
       --arg cert_path "$ASKED_CERT" \
       --arg key_path "$ASKED_KEY" \
       '. += [{
           "tag": $tag,
           "protocol": $protocol,
           "port": $port,
           "domain": $domain,
           "server_name": $server_name,
           "uuid": $uuid,
           "password": $password,
           "cert_path": $cert_path,
           "key_path": $key_path
       }]' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"

    save_domain_mapping "$ASKED_TAG" "$ASKED_DOMAIN"
    echo -e "${GREEN}Thêm Node TUIC thành công! Tag: $ASKED_TAG${NC}"
    sleep 1
}

add_node_menu() {
    local has_added=0
    while true; do
        clear
        ASKED_TAG=""
        echo -e "${BLUE}================================================================${NC}"
        echo -e "${BLUE}||${NC}                 ${YELLOW}CHỌN GIAO THỨC CHO NODE${NC}                    ${BLUE}||${NC}"
        echo -e "${BLUE}================================================================${NC}"
        echo -e " ${GREEN}1.${NC} VLESS REALITY (TCP)"
        echo -e " ${GREEN}2.${NC} VLESS WebSocket TLS"
        echo -e " ${GREEN}3.${NC} VLESS gRPC REALITY"
        echo -e " ${GREEN}4.${NC} Hysteria 2"
        echo -e " ${GREEN}5.${NC} TUIC"
        echo -e " ${RED}0.${NC} Quay lại"
        echo -e "${CYAN}================================================================${NC}"
        read -p " Vui lòng chọn giao thức [0-5]: " proto_choice

        case $proto_choice in
            1) form_vless_reality ;;
            2) form_vless_ws_tls ;;
            3) form_vless_grpc_reality ;;
            4) form_hy2 ;;
            5) form_tuic ;;
            0) break ;;
            *) 
                echo -e "${RED}Lựa chọn không hợp lệ!${NC}"
                sleep 1 
                continue
                ;;
        esac

        if [ -n "$ASKED_TAG" ]; then
            has_added=1
        fi

        read -p " Bạn có muốn thêm giao thức nữa không? (y/n): " add_more
        if [[ "$add_more" =~ ^[Nn]$ ]]; then
            break
        fi
    done

    if [ "$has_added" -eq 1 ]; then
        info "Đang tiến hành build cấu hình và khởi động lại dịch vụ..."
        build_config_json
        restart_singbox
        
        sleep 1
        if systemctl is-active --quiet sing-box; then
            echo -e "${GREEN}[XÁC NHẬN] Dịch vụ Sing-box đã KHỞI ĐỘNG THÀNH CÔNG và đang hoạt động thực tế!${NC}"
        else
            echo -e "${RED}[XÁC NHẬN] Dịch vụ Sing-box KHỞI ĐỘNG THẤT BẠI! Vui lòng kiểm tra lại cấu hình hoặc log (journalctl -u sing-box -e).${NC}"
        fi
        read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
    fi
}

list_nodes() {
    local mode="${1:-raw}"
    clear
    echo -e "${BLUE}================================================================${NC}"
    if [ "$mode" = "select" ]; then
        echo -e "${BLUE}||${NC}                   ${YELLOW}DANH SÁCH NODE HIỆN CÓ                   ${BLUE}||${NC}"
    else
        echo -e "${BLUE}||${NC}                   ${YELLOW}DANH SÁCH LINK KẾT NỐI                   ${BLUE}||${NC}"
    fi
    echo -e "${BLUE}================================================================${NC}"

    if [ ! -s "$NODES_FILE" ] || [ "$(cat "$NODES_FILE")" = "[]" ]; then
        echo -e "${YELLOW}Chưa có node nào được tạo.${NC}"
        echo -e "${CYAN}================================================================${NC}"
        return 1
    fi

    local default_uuid=""
    if [ -f "$USERS_FILE" ]; then
        default_uuid=$(jq -r '.[0].uuid // empty' "$USERS_FILE" 2>/dev/null)
    fi

    local count
    count=$(jq '. | length' "$NODES_FILE" 2>/dev/null || echo 0)

    for (( i=0; i<$count; i++ )); do
        local tag=$(jq -r ".[$i].tag" "$NODES_FILE")
        local protocol=$(jq -r ".[$i].protocol" "$NODES_FILE")
        local port=$(jq -r ".[$i].port" "$NODES_FILE")
        local domain=$(jq -r ".[$i].domain" "$NODES_FILE")
        local sni=$(jq -r ".[$i].server_name // .domain" "$NODES_FILE")
        local pbk=$(jq -r ".[$i].public_key // \"\"" "$NODES_FILE")
        local sid=$(jq -r ".[$i].short_id // \"\"" "$NODES_FILE")
        local grpc_service=$(jq -r ".[$i].service_name // \"\"" "$NODES_FILE")
        local ws_path=$(jq -r ".[$i].ws_path // \"/\"" "$NODES_FILE")
        local node_uuid=$(jq -r ".[$i].uuid // \"\"" "$NODES_FILE")
        local node_pass=$(jq -r ".[$i].password // \"\"" "$NODES_FILE")

        local user_id="${default_uuid:-$node_uuid}"
        [ -z "$user_id" ] && user_id="12345678-1234-1234-1234-123456789abc"

        if [ "$mode" = "select" ]; then
            echo -e " ${GREEN}$((i + 1)).${NC} ${YELLOW}[$tag]${NC} (${CYAN}$protocol${NC}) - $domain:$port"
        else
            local link
            link=$(build_link "$protocol" "$user_id" "$domain" "$port" "$tag" "$sni" "$pbk" "$sid" "$grpc_service" "$ws_path" "$node_pass")
            echo -e "$link"
        fi
    done

    echo -e "${CYAN}================================================================${NC}"
    return 0
}

update_node() {
    clear
    if ! list_nodes "select"; then
        sleep 2
        return
    fi
    
    read -p " Nhập số thứ tự node cần cập nhật, 0 để hủy: " node_idx
    if [ -z "$node_idx" ] || [ "$node_idx" -eq 0 ]; then
        return
    fi

    local real_idx=$((node_idx - 1))
    local node_tag
    node_tag=$(jq -r --argjson idx "$real_idx" '.[$idx].tag // empty' "$NODES_FILE")

    if [ -z "$node_tag" ]; then
        echo -e "${RED}Lỗi: Số thứ tự node không hợp lệ!${NC}"
        sleep 2
        return
    fi

    echo -e "${GREEN} -> Đang tiến hành cập nhật cho node: $node_tag${NC}"
    
    read -p " Nhập Tag mới [Để trống để giữ nguyên]: " new_tag
    read -p " Nhập Tên miền (Domain) mới [Để trống để giữ nguyên]: " new_domain
    read -p " Nhập Port mới [Để trống để giữ nguyên]: " new_port

    if [ -n "$new_tag" ] && [ "$new_tag" != "$node_tag" ]; then
        if grep -q "\"tag\": \"$new_tag\"" "$NODES_FILE" 2>/dev/null; then
            echo -e "${RED}Lỗi: Tag '$new_tag' đã tồn tại! Bỏ qua cập nhật tag.${NC}"
        else
            jq --arg old_tag "$node_tag" --arg new_tag "$new_tag" \
               '(.[] | select(.tag == $old_tag).tag) = $new_tag' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"
            
            if [ -f "$DOMAIN_FILE" ] && jq -e --arg tag "$node_tag" '.[] | select(.tag == $tag)' "$DOMAIN_FILE" >/dev/null 2>&1; then
                jq --arg old_tag "$node_tag" --arg new_tag "$new_tag" \
                   '(.[] | select(.tag == $old_tag).tag) = $new_tag' "$DOMAIN_FILE" > "$DOMAIN_FILE.tmp" && mv "$DOMAIN_FILE.tmp" "$DOMAIN_FILE"
            fi

            if [ -f "$USERS_FILE" ]; then
                jq --arg old_tag "$node_tag" --arg new_tag "$new_tag" \
                   '(.[] | select(.tag == $old_tag).tag) = $new_tag' "$USERS_FILE" > "$USERS_FILE.tmp" && mv "$USERS_FILE.tmp" "$USERS_FILE"
            fi

            echo -e "${GREEN} -> Cập nhật Tag thành công từ '$node_tag' sang '$new_tag'.${NC}"
            node_tag="$new_tag"
        fi
    fi

    if [ -n "$new_domain" ]; then
        jq --arg tag "$node_tag" --arg domain "$new_domain" \
           '(.[] | select(.tag == $tag).domain) = $domain | (.[] | select(.tag == $tag).server_name) = $domain' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"
        save_domain_mapping "$node_tag" "$new_domain"
        echo -e "${GREEN} -> Cập nhật Domain thành công.${NC}"
    fi

    if [ -n "$new_port" ]; then
        if ! [[ "$new_port" =~ ^[0-9]+$ ]] || [ "$new_port" -lt 1 ] || [ "$new_port" -gt 65535 ]; then
            echo -e "${RED}Lỗi: Port không hợp lệ! Bỏ qua cập nhật port.${NC}"
        elif ! check_port_usage "$new_port"; then
            echo -e "${RED}Lỗi: Port $new_port đã có người dùng! Bỏ qua cập nhật port.${NC}"
        else
            open_firewall_port "$new_port"
            jq --arg tag "$node_tag" --argjson port "$new_port" \
               '(.[] | select(.tag == $tag).port) = $port' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"
            echo -e "${GREEN} -> Cập nhật Port thành công.${NC}"
        fi
    fi

    read -p " Bạn có muốn cập nhật/chọn lại Chứng chỉ SSL không? (y/n): " update_ssl
    if [[ "$update_ssl" =~ ^[Yy]$ ]]; then
        ask_cert
        if [ -n "$ASKED_CERT" ] && [ -n "$ASKED_KEY" ]; then
            jq --arg tag "$node_tag" --arg cert "$ASKED_CERT" --arg key "$ASKED_KEY" \
               '(.[] | select(.tag == $tag).cert_path) = $cert | (.[] | select(.tag == $tag).key_path) = $key' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"
            echo -e "${GREEN} -> Cập nhật Chứng chỉ SSL thành công.${NC}"
        fi
    fi

    echo -e "${YELLOW}Cập nhật Node hoàn tất!${NC}"
    build_config_json
    restart_singbox
    sleep 2
}

delete_node() {
    clear
    if ! list_nodes "select"; then
        sleep 2
        return
    fi
    
    read -p " Nhập số thứ tự node cần xóa [Để trống = XÓA TẤT CẢ, 0 = Hủy]: " node_idx

    # Nhập 0 -> Hủy
    if [ "$node_idx" = "0" ]; then
        return
    fi

    # Để trống -> Xóa tất cả node
    if [ -z "$node_idx" ]; then
        read -p " XÁC NHẬN: Bạn có chắc chắn muốn XÓA TẤT CẢ các node? (y/N): " confirm_all
        if [[ "$confirm_all" =~ ^[Yy]$ ]]; then
            if command -v jq &> /dev/null; then
                # Đóng toàn bộ port tường lửa của các node đang hoạt động
                local count
                count=$(jq '. | length' "$NODES_FILE" 2>/dev/null || echo 0)
                for (( i=0; i<$count; i++ )); do
                    local port
                    port=$(jq -r ".[$i].port // empty" "$NODES_FILE")
                    if [ -n "$port" ] && [[ "$port" =~ ^[0-9]+$ ]]; then
                        close_firewall_port "$port"
                    fi
                done

                # Reset các file dữ liệu về mảng rỗng
                echo "[]" > "$NODES_FILE"
                echo "[]" > "$DOMAIN_FILE"
                
                echo -e "${GREEN}Đã xóa TẤT CẢ các node thành công!${NC}"
                build_config_json
                restart_singbox
            else
                echo -e "${RED}Thiếu công cụ jq để xử lý JSON.${NC}"
            fi
        else
            echo -e "${YELLOW}Đã hủy thao tác xóa tất cả.${NC}"
        fi
        sleep 2
        return
    fi

    # Nhập số thứ tự cụ thể -> Xóa 1 node
    local real_idx=$((node_idx - 1))
    local node_tag
    local node_port
    node_tag=$(jq -r --argjson idx "$real_idx" '.[$idx].tag // empty' "$NODES_FILE")
    node_port=$(jq -r --argjson idx "$real_idx" '.[$idx].port // empty' "$NODES_FILE")

    if [ -z "$node_tag" ]; then
        echo -e "${RED}Lỗi: Số thứ tự node không hợp lệ!${NC}"
        sleep 2
        return
    fi

    if command -v jq &> /dev/null; then
        jq --arg tag "$node_tag" '[.[] | select(.tag != $tag)]' "$NODES_FILE" > "$NODES_FILE.tmp" && mv "$NODES_FILE.tmp" "$NODES_FILE"
        jq --arg tag "$node_tag" '[.[] | select(.tag != $tag)]' "$DOMAIN_FILE" > "$DOMAIN_FILE.tmp" && mv "$DOMAIN_FILE.tmp" "$DOMAIN_FILE"
        
        echo -e "${GREEN}Đã xóa node có tag: $node_tag${NC}"
        
        if [ -n "$node_port" ] && [[ "$node_port" =~ ^[0-9]+$ ]]; then
            close_firewall_port "$node_port"
        fi

        build_config_json
        restart_singbox
    else
        echo -e "${RED}Thiếu công cụ jq để xử lý JSON.${NC}"
    fi
    sleep 2
}

# Menu chính của module
while true; do
    clear
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}||${NC}                    ${YELLOW}QUẢN LÝ THÔNG TIN NODE                  ${BLUE}||${NC}"
    echo -e "${BLUE}================================================================${NC}"
    echo -e " ${GREEN}1.${NC} Danh sách Link kết nối"
    echo -e " ${GREEN}2.${NC} Thêm Node mới"
    echo -e " ${GREEN}3.${NC} Cập nhật Node"
    echo -e " ${GREEN}4.${NC} Xóa Node"
    echo -e " ${RED}0.${NC} Quay lại Menu chính"
    echo -e "${CYAN}================================================================${NC}"
    read -p " Vui lòng chọn chức năng [0-4]: " choice

    case $choice in
        1)
            list_nodes "raw"
            read -n 1 -s -r -p "Nhấn phím bất kỳ để tiếp tục..."
            ;;
        2)
            add_node_menu
            ;;
        3)
            update_node
            ;;
        4)
            delete_node
            ;;
        0)
            break
            ;;
        *)
            echo -e "${RED}Lựa chọn không hợp lệ!${NC}"
            sleep 1
            ;;
    esac
done