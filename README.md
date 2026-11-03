# NAST Sing-box VVC

README này được cập nhật theo đúng các menu và thao tác thực tế hiện có trong dự án, dựa trên các file trong thư mục modules và entry point main.sh.

## Mục tiêu

Dự án này là một hệ thống quản lý dịch vụ Sing-box bằng giao diện dòng lệnh, hỗ trợ:
- Quản lý node proxy
- Tạo và xoá node theo loại giao thức
- Khởi động, dừng, khởi động lại Sing-box
- Quản lý SSL Cloudflare
- Cập nhật hệ thống / gỡ cài đặt

## Yêu cầu

- Hệ điều hành Linux (Ubuntu/Debian/CentOS/AlmaLinux...)
- Quyền root hoặc sudo
- Kết nối internet để cài đặt và xin SSL
- Sing-box core và các công cụ phụ trợ như jq, curl, openssl

## Cài đặt nhanh

Chạy trên VPS:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/Vivancang592/nat_singbox_vvc/main/install.sh)
```

Hoặc clone mã nguồn rồi chạy:

```bash
sudo -i
git clone https://github.com/Vivancang592/nat_singbox_vvc.git /root/nast-singbox-vvc
cd /root/nast-singbox-vvc
bash install.sh
```

Sau khi cài đặt xong, chạy:

```bash
vvc
```

---

## Menu chính thực tế

Khi chạy lệnh vvc, menu chính hiển thị như sau:

```text
========================================================================
||                      MENU NAST SING-BOX VVC                      ||
========================================================================
 Tác Giả: Vietnamvpn    | Singbox Core: [Phiên bản]
 Trạng Thái: [ĐANG CHẠY/ĐÃ DỪNG] | Website: https://linksub24h.com
========================================================================
 1. Quản Lý Node Server    | 4. Cập Nhật Hệ Thống
 2. Quản Lý Sing-Box       | 5. Gỡ Cài Đặt Hệ Thống
 3. Quản Lý SSL Cloudflare | 0. Thoát Khỏi Hệ Thống
========================================================================
```

### Chức năng của từng mục

1. Quản Lý Node Server
   - Xem link kết nối
   - Thêm node mới
   - Cập nhật node
   - Xoá node
   - Quay lại menu chính

2. Quản Lý Sing-Box
   - Khởi động Sing-box
   - Dừng Sing-box
   - Khởi động lại Sing-box
   - Xem nhật ký hoạt động
   - Quay lại menu chính

3. Quản Lý SSL Cloudflare
   - Đăng ký chứng chỉ SSL qua Cloudflare
   - Xem danh sách chứng chỉ trong thư mục certs
   - Quay lại menu chính

4. Cập Nhật Hệ Thống
   - Chạy script cập nhật của dự án

5. Gỡ Cài Đặt Hệ Thống
   - Xoá toàn bộ hệ thống và dữ liệu
   - Có cảnh báo có xác nhận rõ ràng

0. Thoát khỏi hệ thống

---

## Quản lý node

Khi chọn 1 trong menu chính, bạn vào submenu node:

```text
================================================================
||                    QUẢN LÝ THÔNG TIN NODE                  ||
================================================================
 1. Danh sách Link kết nối
 2. Thêm Node mới
 3. Cập nhật Node
 4. Xóa Node
 0. Quay lại Menu chính
================================================================
```

### 1) Danh sách Link kết nối
- Hiển thị toàn bộ node đang có
- Tạo link URI cho từng node theo giao thức tương ứng
- Nếu không có node nào, hệ thống sẽ báo chưa có node

### 2) Thêm Node mới
Bạn sẽ được chọn loại giao thức:

```text
================================================================
||                 CHỌN GIAO THỨC CHO NODE                     ||
================================================================
 1. VLESS REALITY (TCP)
 2. VLESS WebSocket TLS
 3. VLESS gRPC REALITY
 4. Hysteria 2
 5. TUIC
 0. Quay lại
================================================================
```

Các loại node hỗ trợ thực tế trong module:
- VLESS REALITY (TCP)
- VLESS WebSocket TLS
- VLESS gRPC REALITY
- Hysteria 2
- TUIC

### Quy trình thêm node

Khi tạo node, hệ thống sẽ tự động hỏi hoặc sinh các giá trị sau:
- Port: nhập thủ công hoặc để trống để chọn ngẫu nhiên
- SNI: nhập thủ công hoặc để trống để tự tạo ngẫu nhiên
- Domain: nhập thủ công hoặc để trống sẽ lấy IP VPS
- Tag: nhập thủ công hoặc để trống để tự động theo quốc gia + port
- Chứng chỉ SSL: nếu cần cho WebSocket/Hysteria2/TUIC, hệ thống sẽ tự dò trong thư mục certs
- Public key / Private key / Short ID / UUID / Password: tự động sinh nếu cần

Sau khi thêm node thành công, hệ thống sẽ:
- ghi dữ liệu vào file nodes.json
- build lại config.json
- khởi động lại dịch vụ Sing-box

### 3) Cập nhật Node
- Hiển thị danh sách node
- Chọn số thứ tự node cần sửa
- Có thể cập nhật:
  - Tag
  - Domain
  - Port
  - Chứng chỉ SSL
- Sau khi cập nhật, hệ thống build config lại và restart Sing-box

### 4) Xóa Node
- Có thể xoá từng node theo số thứ tự
- Hoặc xoá tất cả node nếu chọn để trống
- Hệ thống sẽ đóng port tương ứng trên firewall và reload cấu hình mới

### 5) Đồng bộ node từ link Subscription
- Chọn mục `5. Cập nhật Node từ link Subscription`, nhập link HTTPS; lần sau có thể nhấn Enter để dùng lại link đã lưu.
- Hệ thống tải lại toàn bộ danh sách URI từ subscription (hỗ trợ nội dung thô hoặc Base64), loại bỏ URI trùng và lưu riêng trong `data/subscription_nodes.txt`.
- Chọn mục `1. Danh sách Link kết nối` để xem cả link node server hiện có lẫn các URI vừa đồng bộ. Chạy lại mục 5 để lấy phiên bản mới nhất sau khi subscription thay đổi.
- Nếu tải lỗi hoặc nội dung không có URI được hỗ trợ, danh sách cũ được giữ nguyên. Link và dữ liệu subscription chỉ lưu cục bộ trong `data/`.
- Node subscription là thông tin kết nối máy khách, không phải cấu hình inbound của VPS. Vì vậy chúng không ghi đè `nodes.json`, không thay đổi cấu hình Sing-box hoặc khởi động lại dịch vụ; các chức năng tạo/cập nhật/xóa node server hiện có vẫn hoạt động độc lập.

---

## Quản lý Sing-box

Khi chọn 2 trong menu chính, bạn vào menu:

```text
===============================================================
              QUẢN LÝ HỆ THỐNG SING-BOX
===============================================================
 Trạng thái hiện tại : ... | Phiên bản Sing-box : ...
===============================================================
 1. Khởi động Sing-box
 2. Dừng Sing-box
 3. Khởi động lại Sing-box
 4. Xem nhật ký hoạt động
 0. Quay lại menu chính
===============================================================
```

### Chức năng

1. Khởi động Sing-box
   - Chạy systemctl start sing-box
   - Kiểm tra trạng thái sau khi khởi động

2. Dừng Sing-box
   - Chạy systemctl stop sing-box

3. Khởi động lại Sing-box
   - Chạy systemctl restart sing-box

4. Xem nhật ký hoạt động
   - Dùng journalctl -u sing-box -n 50 --no-pager

---

## Quản lý SSL Cloudflare

Khi chọn 3 trong menu chính, bạn vào menu:

```text
=================================================
           XIN CHỨNG CHỈ SSL CLOUDFLARE
=================================================
 1. Đăng ký chứng chỉ SSL qua Cloudflare
 2. Xem danh sách chứng chỉ hiện có
 0. Quay lại menu chính
=================================================
```

### Mục 1: Đăng ký chứng chỉ SSL
Hệ thống sẽ yêu cầu:
- Tên miền
- Cloudflare Account Email
- Cloudflare Global API Key hoặc API Token

Sau đó sẽ:
- kiểm tra cài đặt acme.sh
- cấu hình môi trường CF_Key và CF_Email
- xin chứng chỉ bằng dns_cf
- lưu 파일 cert/key riêng theo tên miền trong thư mục certs

Ví dụ lưu file:
- certs/sub.domain.com.crt
- certs/sub.domain.com.key

### Mục 2: Xem danh sách chứng chỉ
- Hiển thị các file .crt có trong thư mục certs
- In thông tin Subject và Not After bằng openssl

---

## Quy trình thao tác phổ biến

### Thêm node mới

```bash
vvc
# Chọn: 1
# Chọn: 2
# Chọn giao thức: 1, 2, 3, 4 hoặc 5
# Nhập Port hoặc để trống để tự chọn ngẫu nhiên
# Nhập Domain hoặc để trống để lấy IP VPS
# Nhập SNI hoặc để trống để tự sinh
# Nhập Tag hoặc để trống để tạo tự động
# Hệ thống sẽ sinh key, UUID, password nếu cần
```

### Khởi động lại dịch vụ

```bash
vvc
# Chọn: 2
# Chọn: 3
```

### Xem log

```bash
vvc
# Chọn: 2
# Chọn: 4
```

### Xin SSL mới

```bash
vvc
# Chọn: 3
# Chọn: 1
# Nhập domain, email Cloudflare, API key/token
```

---

## Cấu trúc dự án chính

```text
/root/nast-singbox-vvc/
├── install.sh
├── main.sh
├── update.sh
├── modules/
│   ├── nodes.sh
│   ├── ssl.sh
│   ├── system.sh
│   └── utils.sh
├── templates/
│   ├── config.base.json
│   ├── inbound_hy2.json
│   ├── inbound_tuic.json
│   └── vless/
├── data/
│   ├── nodes.json
│   ├── domain.json
│   ├── users.json
│   └── config.json
├── certs/
│   └── ...
└── README.md
```

---

## Lưu ý quan trọng

- Dùng quyền root khi chạy vvc.
- Khi thêm node, hệ thống sẽ tự động mở port trên firewall nếu phát hiện có công cụ như ufw, iptables hoặc firewalld.
- Khi xoá node, hệ thống sẽ đóng port tương ứng và rebuild config cho Sing-box.
- Khi thêm node mới, script sẽ tự động restart dịch vụ để áp dụng cấu hình mới.
- Dữ liệu nodes, domain, users được lưu trong data/ và được dùng để build config.json.

---

## Tóm tắt nhanh

Nếu muốn thao tác nhanh nhất:
1. Chạy `vvc`
2. Chọn 1 để quản lý node
3. Chọn 2 để thêm node mới
4. Chọn 2 ở menu chính để khởi động hoặc khởi động lại Sing-box
5. Chọn 3 để tạo SSL Cloudflare

Đây là đúng quy trình hiện có trong các file module của dự án.

---

## Lưu ý quan trọng

- Dùng quyền root khi chạy `vvc`.
- Khi thêm node, hệ thống sẽ tự động mở port trên firewall nếu phát hiện công cụ như ufw, iptables hoặc firewalld.
- Khi xoá node, hệ thống sẽ đóng port tương ứng và rebuild cấu hình mới.
- Khi tạo node mới, script sẽ tự động khởi động lại dịch vụ để áp dụng cấu hình mới.
- Dữ liệu node, domain và user được lưu trong thư mục `data/` và dùng để build `config.json`.

---

## Hỗ trợ nhanh

Nếu gặp lỗi, hãy kiểm tra log bằng lệnh:

```bash
journalctl -u sing-box -e
```

Nếu cần cập nhật hệ thống, vào menu chính rồi chọn:

```text
4. Cập Nhật Hệ Thống
```

vvc

# 3. Thêm node từ menu
# Chọn: 1 → 1 → Nhập thông tin
```

**Xong! Hệ thống sẵn sàng sử dụng.** 🎉

---

## 📊 Thống Kê

- ✅ 5 loại node
- ✅ 4 file tài liệu (500+ KB)
- ✅ 100+ lệnh bash
- ✅ 10+ templates config
- ✅ Hỗ trợ 3 loại firewall
- ✅ Tương thích Linux chung

---

## 📄 License

MIT License - Tự do sử dụng cho mục đích cá nhân & thương mại.

Xem chi tiết: [LICENSE](LICENSE)

---

**Version:** 1.0  
**Last Updated:** 2024-01-01  
**Maintained By:** Vietnamvpn Community

---

**Bạn chưa biết bắt đầu từ đâu?** → Đọc [QUICK_START.md](QUICK_START.md) ngay! ⚡
