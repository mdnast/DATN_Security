## WardMail – Tổng quan hệ thống & công nghệ sử dụng

## 1. Kiến trúc tổng thể

WardMail là ứng dụng **client‑centric**, toàn bộ giao diện và phần lớn xử lý chạy trên thiết bị người dùng (Flutter). Ứng dụng **không có backend tự xây riêng** trong repo này mà sử dụng các dịch vụ **Backend‑as‑a‑Service (BaaS)** và **API bên thứ ba** như Firebase và Google Cloud.

```text
Thiết bị người dùng (Android / Windows)
        │
        ▼
    WardMail (Flutter App)
        │
        ├── Firebase Authentication (xác thực người dùng)
        ├── Firebase Cloud Messaging (thông báo đẩy)
        ├── Google APIs (Gmail API, OAuth 2.0)
        ├── Google Generative AI – Gemini (phân tích email, đánh giá phishing)
        └── reCAPTCHA Enterprise (chống bot, lạm dụng)
```

Ứng dụng giao tiếp trực tiếp với các dịch vụ này qua **HTTPS/TLS**, dữ liệu lưu cục bộ trên thiết bị ở mức tối thiểu, chủ yếu là **token, cấu hình và file báo cáo**.

---

## 2. Frontend – Ứng dụng Flutter (client)

### 2.1 Công nghệ chính frontend

| Lớp / Khu vực          | Công nghệ / Package                    | Mục đích |
|------------------------|----------------------------------------|----------|
| UI framework           | **Flutter** (Dart 3.x)                | Xây dựng UI đa nền tảng (Android, Windows) |
| Thiết kế giao diện     | Material Design 3                     | Giao diện hiện đại, nhất quán |
| Đa ngôn ngữ            | `flutter_localizations`, module `localization/` | Hỗ trợ nhiều ngôn ngữ (VD: Việt/Anh) |
| Màn hình & điều hướng  | Thư mục `screens/`, `widgets/`        | Tổ chức các màn hình, widget dùng lại |
| Dashboard & biểu đồ    | `fl_chart`                            | Vẽ biểu đồ thống kê, xu hướng phishing |
| Hiển thị HTML          | `webview_flutter`                     | Render nội dung email HTML |
| PDF & CSV              | `pdf`, `csv`                          | Xuất báo cáo ra file PDF/CSV |
| Chia sẻ                | `share_plus`                          | Chia sẻ báo cáo/file qua app khác |
| Làm việc với file      | `file_picker`, `path_provider`        | Chọn, lưu, đọc đường dẫn file cục bộ |
| Lưu cấu hình nhẹ       | `shared_preferences`                  | Lưu theme, ngôn ngữ, một số setting không nhạy cảm |
| Định dạng thời gian    | `intl`                                | Định dạng ngày/giờ, đa ngôn ngữ |

### 2.2 Vai trò của frontend

Frontend (WardMail app) chịu trách nhiệm:

- Hiển thị toàn bộ giao diện: **đăng nhập, danh sách email, chi tiết email, kết quả phân tích AI, dashboard thống kê, cài đặt, báo cáo, v.v.**
- Gọi tới **Firebase, Google APIs, Gemini, IMAP** thông qua các service trong thư mục `services/`.
- Quản lý dữ liệu cục bộ: lưu **token**, cấu hình người dùng, file báo cáo đã xuất, trạng thái phân tích…

---

## 3. Backend logic trong ứng dụng (Service Layer)

Mặc dù WardMail không có server backend riêng, phần **backend logic** (business logic) được tổ chức rõ ràng trong thư mục `lib/services/`. Đây là **tầng xử lý trung gian** giữa UI và các dịch vụ cloud/bên thứ ba.

### 3.1 Nhóm xác thực, cấu hình & khởi động

| Service                          | Chức năng chính |
|----------------------------------|-----------------|
| `auth_service.dart`              | Đóng gói logic đăng ký/đăng nhập, đăng xuất, gửi email xác minh, reset mật khẩu, lấy người dùng hiện tại từ Firebase Auth. |
| `biometric_service.dart`         | Quản lý bật/tắt xác thực sinh trắc học, gọi `local_auth` để kiểm tra vân tay/Face ID, kết hợp với trạng thái đăng nhập. |
| `recaptcha_service.dart`         | Tạo, hiển thị và xác thực reCAPTCHA Enterprise cho các luồng nhạy cảm (đăng ký, đăng nhập nhiều lần thất bại...). |
| `auto_start_service.dart`        | Xử lý logic tự khởi động, đăng ký tác vụ nền phù hợp với nền tảng (Windows/Android) nếu có cấu hình. |
| `locale_service.dart`            | Quản lý ngôn ngữ ứng dụng, lưu lựa chọn vào `shared_preferences`, cập nhật `localization`. |
| `theme_service.dart`             | Quản lý theme (sáng/tối), lưu cấu hình, phát sự kiện đổi theme cho UI. |

### 3.2 Nhóm email & giám sát nền

| Service                          | Chức năng chính |
|----------------------------------|-----------------|
| `gmail_service.dart`             | Kết nối Gmail API (qua `googleapis`), lấy danh sách email, metadata, nội dung; map dữ liệu về model nội bộ. |
| `background_email_service.dart`  | Định nghĩa các tác vụ nền để kiểm tra email mới, đồng bộ dữ liệu định kỳ (kết hợp `workmanager`). |
| `email_monitor_service.dart`     | Điều phối quy trình theo dõi email: quét hộp thư, phát hiện email mới, gọi phân tích AI, cập nhật lịch sử quét, kích hoạt thông báo. |
| `scan_history_service.dart`      | Quản lý lịch sử quét email (kết quả phân tích, mức rủi ro, thời gian), cung cấp dữ liệu cho dashboard và báo cáo. |

### 3.3 Nhóm AI, phân tích & ẩn danh hóa

| Service                          | Chức năng chính |
|----------------------------------|-----------------|
| `gemini_analysis_service.dart`   | Làm việc với `google_generative_ai`: chuẩn hóa nội dung email, gọi mô hình Gemini, parse kết quả (mức rủi ro, gợi ý) về dạng mà app sử dụng. |
| `email_analysis_service.dart`    | Kết hợp dữ liệu từ Gmail/IMAP, rule nội bộ và kết quả từ Gemini để tính toán **điểm rủi ro**, gán nhãn (an toàn / nghi ngờ / nguy hiểm). |
| `auto_analysis_settings_service.dart` | Quản lý cấu hình tự động phân tích (tần suất, điều kiện, giới hạn), lưu vào local storage và cung cấp cho các service nền. |
| `anonymization_service.dart`     | Ẩn hoặc làm mờ một số trường nhạy cảm (VD: địa chỉ email đầy đủ, một phần nội dung) trước khi gửi sang AI hoặc hiển thị trong báo cáo, giúp giảm lộ thông tin. |

### 3.4 Nhóm thông báo, báo cáo & xuất dữ liệu

| Service                          | Chức năng chính |
|----------------------------------|-----------------|
| `notification_service.dart`      | Tạo, cấu hình và gửi **thông báo cục bộ**; kết hợp với FCM để xử lý payload push từ Firebase. |
| `export_service.dart`            | Gom dữ liệu lịch sử quét, thống kê; sinh file **PDF/CSV** bằng `pdf`, `csv`, lưu ra ổ đĩa (`path_provider`) và cung cấp cho `share_plus`. |

Các service này tạo thành **tầng backend trong app**: UI chỉ gọi vào service, còn service chịu trách nhiệm làm việc với Firebase, Google APIs, IMAP, AI, lưu trữ, thông báo…

---

## 4. Bên thứ ba / Dịch vụ cloud

Lớp **bên thứ ba** trong kiến trúc WardMail bao gồm các dịch vụ cloud và hệ thống bên ngoài mà ứng dụng gọi tới (không thuộc codebase WardMail). Có thể chia thành 3 nhóm chính: **Firebase**, **Google Cloud APIs** và **máy chủ email/notification khác**.

### 4.1 Firebase (BaaS)

| Dịch vụ Firebase                          | Package sử dụng                         | Chức năng trong WardMail |
|-------------------------------------------|-----------------------------------------|---------------------------|
| **Firebase Authentication**               | `firebase_auth`, `firebase_core`        | Đăng ký/đăng nhập Email & Password, đăng nhập Google, xác minh email, reset mật khẩu |
| **Firebase Cloud Messaging (FCM)**        | `firebase_messaging`                    | Gửi/nhận thông báo đẩy khi phát hiện email nguy hiểm, nhắc người dùng kiểm tra email |

> Ghi chú: Hiện tại repo **không dùng** Firestore / Realtime Database / Cloud Functions, nhưng kiến trúc cho phép mở rộng về sau nếu cần backend tùy biến.

### 4.2 Google Cloud APIs (AI & email)

| API / Dịch vụ                              | Package                                  | Mô tả backend |
|-------------------------------------------|-------------------------------------------|----------------|
| **Gmail API**                             | `googleapis`, `googleapis_auth`          | Backend email của Google – cung cấp endpoint REST để WardMail đọc danh sách email, metadata, nội dung, header… |
| **OAuth 2.0 & Google Sign‑In**            | `google_sign_in`, `googleapis_auth`      | Hệ thống xác thực SSO của Google – đóng vai trò identity provider cho WardMail |
| **Generative AI (Gemini)**                | `google_generative_ai`                   | Backend AI – mô hình Gemini trên hạ tầng Google Cloud, dùng để phân tích nội dung email và đánh giá nguy cơ phishing |
| **reCAPTCHA Enterprise**                  | `recaptcha_enterprise_flutter`           | Backend chống bot – validate token reCAPTCHA từ client, giảm tấn công tự động |

Ở góc nhìn hệ thống, các dịch vụ này đóng vai trò **bên thứ ba cung cấp chức năng email, AI, xác thực và chống bot** cho WardMail.

### 4.3 Máy chủ email & notification khác

| Thành phần / Giao thức        | Package / Hệ thống             | Vai trò backend |
|-------------------------------|---------------------------------|-----------------|
| **Máy chủ IMAP (nhà cung cấp mail)** | `enough_mail` (client trong app) | Backend email cho các hộp thư không phải Gmail (VD: mail công ty, provider khác) |
| **HTTP REST APIs (nếu bổ sung)**     | `http`                         | Cho phép tích hợp thêm dịch vụ bên ngoài (VD: API quét URL, sandbox file…) |
| **Local notifications layer**        | `flutter_local_notifications`  | Xử lý hiển thị thông báo cục bộ, đứng giữa app và hệ điều hành |
| **Background task scheduler**        | `workmanager`                  | Lên lịch job nền: đồng bộ email, làm mới thống kê, gửi thông báo định kỳ… |

> Nếu trong tương lai cần backend riêng (ví dụ Node.js/Express, NestJS, .NET, Spring Boot…), kiến trúc có thể mở rộng thêm **API Gateway** ở giữa: WardMail gọi tới backend riêng, backend mới gọi sang các dịch vụ bên thứ ba.

---

## 5. Cơ chế & công nghệ bảo mật

Bảo mật trong WardMail được thiết kế theo nhiều lớp: **xác thực**, **bảo vệ dữ liệu**, **bảo mật đường truyền** và **cơ chế an toàn ở tầng ứng dụng**.

### 4.1 Xác thực & định danh (Authentication & Identity)

| Khía cạnh                        | Công nghệ / Chi tiết |
|----------------------------------|-----------------------|
| Xác thực người dùng              | **Firebase Authentication** (Email/Password, Google Sign‑In) |
| Lưu trữ mật khẩu                 | Do Firebase quản lý; ứng dụng **không** lưu mật khẩu dưới bất kỳ dạng nào |
| Phiên đăng nhập, token           | Firebase ID Token / Refresh Token, lưu trong `flutter_secure_storage` |
| Xác thực sinh trắc học           | `local_auth` – dùng vân tay / Face ID để khóa/mở ứng dụng |
| Chống bot, tấn công tự động      | `recaptcha_enterprise_flutter` – tích hợp reCAPTCHA Enterprise tại các luồng nhạy cảm |

### 4.2 Bảo vệ dữ liệu & lưu trữ (Data Protection & Storage)

| Khu vực                          | Công nghệ / Thực hành |
|----------------------------------|------------------------|
| Lưu token / thông tin nhạy cảm  | `flutter_secure_storage` – mã hóa, lưu trong keystore/Keychain của hệ điều hành |
| Cấu hình không nhạy cảm         | `shared_preferences` – chỉ dùng cho dữ liệu như theme, ngôn ngữ, tuỳ chọn hiển thị |
| Báo cáo PDF/CSV                  | Lưu trong thư mục ứng dụng lấy qua `path_provider`, tuân theo sandbox OS |
| Nội dung email                   | Lấy trực tiếp từ Gmail/IMAP; **không** đưa về server riêng, xử lý chủ yếu trên client + API Google |

### 4.3 Bảo mật đường truyền (Transport Security)

| Kênh truyền                     | Cơ chế bảo mật |
|---------------------------------|-----------------|
| Giao tiếp với Firebase          | Bắt buộc dùng **HTTPS/TLS** do Firebase cung cấp |
| Giao tiếp với Google Cloud APIs | Bắt buộc dùng **HTTPS/TLS** (Gmail API, Gemini, reCAPTCHA…) |
| Kết nối IMAP                    | Sử dụng **IMAP over TLS/SSL** (nếu server hỗ trợ), tránh plaintext |

### 4.4 Cơ chế bảo mật ở tầng ứng dụng

- **Khóa ứng dụng bằng sinh trắc học** khi mở lại từ background hoặc theo cấu hình người dùng.
- **Phân loại rủi ro email** (an toàn / nghi ngờ / nguy hiểm) dựa trên phân tích AI để cảnh báo người dùng trước khi bấm vào link.
- **Thông báo cục bộ + đẩy** khi phát hiện email nguy hiểm, giúp người dùng phản ứng nhanh.
- **Không lưu email trên server tự quản lý**, giảm bề mặt tấn công và gánh nặng tuân thủ.

---

## 6. Bảng tổng hợp công nghệ

### 6.1 Stack công nghệ theo 3 lớp: Frontend – Backend – Bên thứ ba

#### 6.1.1 Frontend (UI & client)

| Nhóm                | Công nghệ chính |
|---------------------|-----------------|
| UI & layout         | Flutter, Dart, Material Design 3 |
| Màn hình & widget   | Thư mục `screens/`, `widgets/` |
| Biểu đồ & dashboard | `fl_chart` |
| Hiển thị HTML       | `webview_flutter` |
| Báo cáo & file      | `pdf`, `csv`, `file_picker`, `path_provider`, `share_plus` |
| Đa ngôn ngữ & hiển thị | `flutter_localizations`, `intl`, module `localization/` |
| Cấu hình cục bộ nhẹ | `shared_preferences` |

#### 6.1.2 Backend (logic trong app)

| Nhóm logic          | Service / Công nghệ |
|---------------------|---------------------|
| Xác thực & cấu hình | `auth_service`, `biometric_service`, `recaptcha_service`, `auto_start_service`, `locale_service`, `theme_service` |
| Email & giám sát    | `gmail_service`, `background_email_service`, `email_monitor_service`, `scan_history_service` |
| AI & phân tích      | `gemini_analysis_service`, `email_analysis_service`, `auto_analysis_settings_service`, `anonymization_service` |
| Thông báo & báo cáo | `notification_service`, `export_service` |
| Dịch vụ thiết bị    | `local_auth`, `flutter_secure_storage`, `flutter_local_notifications`, `workmanager` |

#### 6.1.3 Bên thứ ba / Cloud & hệ thống ngoài

| Nhóm                | Công nghệ / Dịch vụ |
|---------------------|---------------------|
| Firebase            | Firebase Authentication, Firebase Cloud Messaging |
| Google Cloud APIs   | Gmail API, Generative AI (Gemini), reCAPTCHA Enterprise, OAuth 2.0 / Google Sign‑In |
| Máy chủ email khác  | IMAP servers (qua `enough_mail`) |
| HTTP dịch vụ ngoài  | `http` + REST APIs (nếu tích hợp thêm) |

### 6.2 Công nghệ liên quan đến bảo mật

| Nhóm bảo mật              | Công nghệ / Dịch vụ |
|---------------------------|---------------------|
| Xác thực & SSO           | Firebase Authentication, Google Sign‑In |
| Chống bot, lạm dụng       | reCAPTCHA Enterprise |
| Lưu trữ thông tin nhạy cảm| `flutter_secure_storage`, keystore/Keychain hệ điều hành |
| Bảo vệ truy cập ứng dụng  | `local_auth` (vân tay, Face ID) |
| Bảo mật đường truyền      | HTTPS/TLS (Firebase, Google APIs, IMAP over TLS/SSL) |
| Bảo mật thông báo         | Firebase Cloud Messaging + local notifications |

