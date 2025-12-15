# Các Công Nghệ Bảo Mật Trong Dự Án GuardMail

Tài liệu này mô tả chi tiết các công nghệ và cơ chế bảo mật được áp dụng trong GuardMail để bảo vệ dữ liệu người dùng, đảm bảo quyền riêng tư và ngăn chặn các mối đe dọa.

## 1. Xác Thực & Định Danh (Authentication & Identity)

### 1.1. OAuth 2.0 & Google Sign-In
*   **Thư viện**: `google_sign_in`, `firebase_auth`, `googleapis_auth`
*   **Cơ chế**: Sử dụng giao thức chuẩn OAuth 2.0 để xác thực người dùng thông qua tài khoản Google.
    *   **Lợi ích**: Không lưu trữ mật khẩu người dùng trực tiếp trên ứng dụng hoặc server của GuardMail. Giảm thiểu rủi ro lộ mật khẩu.
    *   **Scope**: Chỉ yêu cầu các quyền hạn tối thiểu cần thiết (Gmail Read/Send) và token được làm mới (refresh) tự động.

### 1.2. Xác Thực Sinh Trắc Học (Biometric Authentication)
*   **Thư viện**: `local_auth`
*   **Cơ chế**: Tích hợp xác thực vân tay (Fingerprint) hoặc nhận diện khuôn mặt (FaceID) ngay trên thiết bị.
*   **Ứng dụng**: Yêu cầu xác thực lại khi mở ứng dụng hoặc truy cập các cài đặt nhạy cảm, tạo thêm một lớp bảo mật vật lý.

## 2. Bảo Mật Dữ Liệu & Lưu Trữ (Data Security & Storage)

### 2.1. Quản Lý Secrets (Secrets Management)
*   **Thư viện**: `flutter_dotenv`
*   **Cơ chế**: Các khóa API nhạy cảm (Google Gemini API Key, Supabase Key, OAuth Client ID) không được hardcode trong mã nguồn. Chúng được lưu trong tệp `.env` và được tải vào biến môi trường tại runtime.
*   **Lợi ích**: Ngăn chặn việc vô tình lộ khóa API khi đẩy mã nguồn lên GitHub. Tệp `.env` đã được thêm vào `.gitignore`.

### 2.2. Lưu Trữ An Toàn (Secure Storage)
*   **Thư viện**: `flutter_secure_storage`
*   **Cơ chế**: Sử dụng Android Keystore (trên Android) và iOS Keychain (trên iOS) để lưu trữ các dữ liệu nhạy cảm như:
    *   Access Token & Refresh Token của Gmail.
    *   Session Token của người dùng.
*   **Khác biệt**: Dữ liệu cấu hình không quan trọng (Theme, Language) mới lưu ở `shared_preferences`.

### 2.3. Ẩn Danh Hóa Dữ Liệu (Data Anonymization)
*   **Module**: `AnonymizationService` (`lib/services/anonymization_service.dart`)
*   **Cơ chế**: Trước khi gửi nội dung email lên AI (Gemini) để phân tích:
    *   Tự động phát hiện và thay thế các thông tin định danh cá nhân (PII) như Email, Số điện thoại, Tên riêng bằng các ký tự thay thế (ví dụ: `[EMAIL]`, `[PHONE]`).
*   **Mục đích**: Bảo vệ quyền riêng tư người dùng, đảm bảo dữ liệu gửi đi phân tích không chứa thông tin nhạy cảm.

## 3. Bảo Mật Mạng & Kết Nối (Network Security)

### 3.1. HTTPS / TLS
*   **Cơ chế**: Mọi giao tiếp giữa ứng dụng và máy chủ (Google API, Supabase, Gemini) đều được mã hóa bằng giao thức HTTPS/TLS 1.2+.
*   **Lợi ích**: Ngăn chặn các cuộc tấn công nghe lén (Man-in-the-Middle) khi người dùng sử dụng Wifi công cộng.

### 3.2. Giới Hạn Quyền Gmail (Least Privilege)
*   **Cơ chế**: Khi xin quyền truy cập Gmail, ứng dụng chỉ định rõ các Scope cụ thể cần thiết. Token được cấp chỉ có hiệu lực trong thời gian ngắn (Access Token) và phải dùng Refresh Token (được lưu an toàn) để lấy mới.

## 4. Bảo Vệ Khỏi Các Mối Đe Dọa (Threat Protection)

### 4.1. AI Threat Detection (Gemini 2.5 Flash)
*   **Thư viện**: `google_generative_ai`
*   **Cơ chế**: Sử dụng mô hình ngôn ngữ lớn (LLM) để phân tích ngữ cảnh, phát hiện các dấu hiệu lừa đảo tinh vi (Social Engineering) mà các bộ lọc từ khóa truyền thống bỏ sót.
*   **Tính năng**: Chấm điểm rủi ro (Risk Score) và giải thích chi tiết lý do tại sao email bị đánh dấu là nguy hiểm.

### 4.2. Chống Bot (reCAPTCHA Enterprise)
*   **Thư viện**: `recaptcha_enterprise_flutter`
*   **Cơ chế**: Tích hợp Google reCAPTCHA Enterprise để phân biệt người dùng thật và bot tự động.
*   **Ứng dụng**: Bảo vệ các luồng quan trọng như Đăng ký, Đăng nhập (tùy chọn) hoặc Gửi phản hồi lượng lớn.

### 4.3. Sandoboxed Email Rendering
*   **Thư viện**: `flutter_widget_from_html` / `webview_flutter`
*   **Cơ chế**: Hiển thị nội dung HTML của email trong môi trường được kiểm soát.
    *   Tắt thực thi JavaScript mặc định trong nội dung email (ngăn chặn XSS).
    *   Chặn tải các hình ảnh tracking pixel nếu được cấu hình.
