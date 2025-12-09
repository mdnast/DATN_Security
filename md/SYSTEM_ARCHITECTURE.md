# Kiến trúc Hệ thống GuardMail

Hệ thống GuardMail được thiết kế theo mô hình 3 lớp (3-Layer Architecture) để đảm bảo tính tách biệt, dễ bảo trì và mở rộng.

## 1. Lớp Frontend (Mobile App)
Đây là lớp giao diện người dùng, nơi người dùng tương tác trực tiếp với ứng dụng.

| Thành phần | Công nghệ / Thư viện | Mô tả |
| :--- | :--- | :--- |
| **Framework** | **Flutter** | Framework chính để phát triển ứng dụng đa nền tảng (Android/iOS). |
| **Ngôn ngữ** | **Dart** | Ngôn ngữ lập trình chính. |
| **Giao diện (UI)** | **Material Design 3** | Hệ thống thiết kế mới nhất của Google cho giao diện hiện đại. |
| **State Management** | **Provider / ValueNotifier** | Quản lý trạng thái ứng dụng (Theme, Locale, Authentication). |
| **Hiển thị Email** | `flutter_widget_from_html` | Hiển thị nội dung HTML của email an toàn và đẹp mắt. |
| **Biểu đồ** | `fl_chart` | Vẽ biểu đồ thống kê an toàn email. |
| **Bảo mật sinh trắc học** | `local_auth` | Xác thực người dùng bằng vân tay hoặc FaceID. |

## 2. Lớp Backend (Services & Data)
Lớp này xử lý logic nghiệp vụ, lưu trữ dữ liệu và xác thực người dùng. Trong GuardMail, "Backend" bao gồm các dịch vụ đám mây (BaaS) và lưu trữ cục bộ.

| Thành phần | Công nghệ / Thư viện | Mô tả |
| :--- | :--- | :--- |
| **Nền tảng Backend** | **Firebase** | Nền tảng Backend-as-a-Service (BaaS) chính. |
| **Xác thực (Auth)** | `firebase_auth`, `google_sign_in` | Quản lý đăng nhập, xác thực qua Google. |
| **Thông báo (Push)** | `firebase_messaging`, `flutter_local_notifications` | Gửi và nhận thông báo đẩy, thông báo cục bộ. |
| **Lưu trữ cục bộ** | `shared_preferences` | Lưu trữ cấu hình (Theme, Locale) và lịch sử quét (Scan History) dưới dạng JSON. |
| **Lưu trữ bảo mật** | `flutter_secure_storage` | Lưu trữ token và dữ liệu nhạy cảm an toàn. |
| **Tác vụ nền** | `workmanager` | Thực hiện các tác vụ kiểm tra email định kỳ dưới nền ngay cả khi tắt ứng dụng. |

## 3. Lớp API & Extensions (External Integrations)
Lớp này kết nối với các dịch vụ bên ngoài để thực hiện các tính năng nâng cao như phân tích AI, gửi/nhận email và xác thực bot.

| Thành phần | Công nghệ / Thư viện | Mô tả |
| :--- | :--- | :--- |
| **AI Analysis** | **Google Gemini API** (`google_generative_ai`) | Trí tuệ nhân tạo dùng để phân tích nội dung email, phát hiện lừa đảo và tóm tắt. |
| **Email API** | **Gmail API** (`googleapis`) | Kết nối trực tiếp với Gmail để đọc/gửi thư thông qua OAuth2. |
| **Email Protocol** | **IMAP / SMTP** (`enough_mail`) | Giao thức chuẩn để kết nối với các nhà cung cấp email khác. |
| **Bot Protection** | **reCAPTCHA Enterprise** (`recaptcha_enterprise_flutter`, `webview_flutter`) | Bảo vệ ứng dụng khỏi bot và spam (sử dụng WebView để hiển thị Captcha). |
| **Chia sẻ** | `share_plus` | Chia sẻ báo cáo hoặc nội dung email qua các ứng dụng khác. |
| **File System** | `path_provider`, `file_picker` | Truy cập hệ thống tệp tin để lưu/mở file đính kèm. |
