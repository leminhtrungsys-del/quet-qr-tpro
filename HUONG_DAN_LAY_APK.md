# Lấy file APK để test trên điện thoại

Máy chủ của Claude không tải được Flutter/Android SDK (mạng bị giới hạn),
nên mình dùng **GitHub Actions** để build APK miễn phí trên máy chủ của
GitHub — giống hệt cách bạn đã làm với app "Tchat". Toàn bộ đã được viết
sẵn trong `.github/workflows/build-apk.yml`, bạn chỉ cần đẩy code lên.

## Bước 1: Tạo repo mới trên GitHub
1. Vào https://github.com/new
2. Đặt tên repo, ví dụ `quet-qr-tpro` (Public hoặc Private đều được — Actions
   miễn phí cho cả hai với tài khoản cá nhân).
3. **Không** tích "Add a README file" (để repo trống).
4. Bấm Create repository.

## Bước 2: Đẩy code lên
Mở terminal tại thư mục `qr_scanner_app` (thư mục bạn đang có), chạy:

```bash
git init
git add .
git commit -m "Initial commit: Quet QR Tpro"
git branch -M main
git remote add origin https://github.com/<ten-tai-khoan-cua-ban>/quet-qr-tpro.git
git push -u origin main
```

(Thay `<ten-tai-khoan-cua-ban>` bằng username GitHub của bạn — ví dụ
`leminhtrungsys-del`.)

## Bước 3: Theo dõi build
1. Vào tab **Actions** trên trang repo GitHub.
2. Sẽ thấy job "Build APK" đang chạy (mất khoảng 5–8 phút).
3. Khi thấy dấu ✅ màu xanh, cuộn xuống mục **Artifacts**, tải file
   `quet-qr-tpro-apk` (là file .zip chứa `QuetQRTpro-test.apk`).

## Bước 4: Cài lên điện thoại
1. Giải nén file zip vừa tải để lấy `QuetQRTpro-test.apk`.
2. Chuyển file này vào điện thoại Android (qua USB, Zalo gửi cho chính
   mình, Google Drive, v.v.).
3. Mở file trên điện thoại để cài. Vì đây là bản build thử (ký bằng debug
   key, chưa phải bản phát hành chính thức trên Play Store), Android sẽ
   hỏi **"Cho phép cài đặt từ nguồn không xác định"** — bạn bấm cho phép.

## Nếu Actions báo lỗi (build thất bại)
Bấm vào lần chạy bị lỗi → xem log ở bước nào đỏ → gửi mình đoạn log đó
(copy paste hoặc chụp màn hình), mình sẽ sửa lại workflow ngay. Vài lỗi
thường gặp:
- **Lỗi ở bước "Locate generated Kotlin package"**: phiên bản Flutter mới
  đổi cấu trúc thư mục — gửi log để mình chỉnh lại đường dẫn.
- **Lỗi ở bước build liên quan `google_mlkit_barcode_scanning` /
  `camera`**: thường do minSdk chưa đúng — mình sẽ kiểm tra lại patch.
- **Timeout / hết phút Actions miễn phí**: tài khoản cá nhân được 2000
  phút/tháng miễn phí, một lần build chỉ tốn ~6–8 phút nên hiếm khi hết.

## Lưu ý quan trọng
File APK này dùng **ID quảng cáo TEST của Google** (không phải ID AdMob
thật của bạn) — mục đích chỉ để bạn test giao diện, quét mã, tạo QR, đổi
ngôn ngữ... Trước khi đăng lên Google Play chính thức, làm theo checklist
đầy đủ trong `SETUP.md` (thay ID AdMob thật, ký bằng keystore riêng của
bạn, khai Privacy Policy, v.v.) — file APK build qua workflow debug-signed
này **không thể** dùng để đăng Play Store.
