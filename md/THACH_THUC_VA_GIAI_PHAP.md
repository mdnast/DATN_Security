# Các Thách Thức và Giải Pháp Trong Dự Án GuardMail

Tài liệu này tổng hợp các thách thức kỹ thuật chính đã gặp phải trong quá trình phát triển dự án GuardMail và các giải pháp đã (hoặc đang) được áp dụng để khắc phục.

## 1. Hiển Thị Nội Dung Email Phức Tạp (Email Rendering)

### Thách thức
*   **Định dạng HTML đa dạng**: Email marketing và newsletter thường sử dụng HTML/CSS cũ (table-based layouts) hoặc phức tạp mà các widget Flutter cơ bản không hỗ trợ tốt.
*   **Hình ảnh nội tuyến (Inline Images)**: Nhiều email đính kèm hình ảnh dưới dạng `cid:` (Content-ID) thay vì URL công khai, khiến thẻ `<img>` không hiển thị được trực tiếp.
*   **Hiệu năng**: Render các email dài có thể gây giật lag (jank) khi cuộn.
*   **Chế độ tối (Dark Mode)**: Ép màu nội dung email sang giao diện tối mà không làm vỡ các thành phần đồ họa là rất khó.

### Giải pháp
*   **Hybrid Rendering**: Sử dụng `flutter_widget_from_html` cho nội dung đơn giản để tối ưu hiệu năng, và fallback sang `webview_flutter` cho các email có cấu trúc phức tạp.
*   **Preprocessing**: Viết thuật toán tiền xử lý chuỗi HTML trước khi render để:
    *   Tìm và thay thế các thẻ `src="cid:..."` bằng dữ liệu base64 từ tệp đính kèm.
    *   Tiêm (inject) CSS tùy chỉnh để điều chỉnh font chữ và màu sắc phù hợp với Theme của ứng dụng.
*   **Lazy Loading**: Tải hình ảnh không đồng bộ để không chặn luồng UI chính.

## 2. Tích Hợp AI Phân Tích & Bảo Mật (Gemini AI Integration)

### Thách thức
*   **Độ tin cậy của AI**: Đôi khi AI trả về kết quả ảo giác (hallucination) hoặc không tuân thủ định dạng JSON yêu cầu, gây lỗi khi parse dữ liệu.
*   **Ngôn ngữ**: Đảm bảo AI luôn phản hồi bằng Tiếng Việt ngay cả khi nội dung email là Tiếng Anh.
*   **Độ trễ**: Gọi API phân tích từng email tốn thời gian, ảnh hưởng trải nghiệm người dùng.
*   **Context Limit**: Một số email quá dài vượt quá giới hạn token của Gemini.

### Giải pháp
*   **Prompt Engineering**: Thiết kế System Prompt chặt chẽ, sử dụng kỹ thuật "Few-Shot Prompting" (cung cấp ví dụ mẫu) để ép AI trả về đúng cấu trúc JSON và ngôn ngữ Tiếng Việt.
*   **Batch Processing**: (Đang phát triển) Gửi danh sách email theo lô để phân tích, thay vì gửi từng cái.
*   **Feedback Loop**: Xây dựng cơ chế cho phép người dùng phản hồi kết quả sai -> Gửi phản hồi này lại vào prompt lần sau để AI "học" và sửa sai (Re-analysis with user feedback).
*   **Text Truncation**: Cắt bớt phần chữ ký hoặc nội dung HTML dư thừa, chỉ gửi phần văn bản thuần (plain text) quan trọng cho AI.

## 3. Bảo Mật Thông Tin & Quản Lý API Key

### Thách thức
*   **Hardcoded Secrets**: Việc để lộ API Key (Gemini, Supabase Anon Key) trong mã nguồn (`lib/main.dart`) là rủi ro bảo mật nghiêm trọng nếu mã nguồn bị lộ.
*   **Quản lý phiên (Session)**: Đồng bộ trạng thái đăng nhập và quyền Admin giữa các thiết bị.

### Giải pháp
*   **Environment Variables**: Di chuyển toàn bộ key nhạy cảm sang tệp `.env` và sử dụng thư viện `flutter_dotenv` để đọc lúc runtime. Thêm `.env` vào `.gitignore`.
*   **Backend Proxy (Nâng cao)**: Thay vì gọi trực tiếp API từ App, nên gọi qua Supabase Edge Functions hoặc Backend riêng để ẩn hoàn toàn Key.
*   **Secure Storage**: Sử dụng `flutter_secure_storage` để lưu Token đăng nhập thay vì `shared_preferences` (dễ bị đọc trộm trên máy đã root).

## 4. Đồng Bộ Dữ Liệu Realtime (Supabase/Firebase)

### Thách thức
*   **Trạng thái phê duyệt (Approval Flow)**: Người dùng đã được Admin duyệt trên Dashboard nhưng App không cập nhật ngay lập tức, vẫn kẹt ở màn hình "Pending".
*   **Discrepancy**: Sự không nhất quán giữa tài liệu (Firebase) và thực tế triển khai (Supabase) gây bối rối khi bảo trì.

### Giải pháp
*   **Realtime Subscription**: Sử dụng tính năng Realtime của Supabase (hoặc Firestore snapshots) để lắng nghe thay đổi trên bảng `users`. Ngay khi trường `status` đổi thành `approved`, App tự động chuyển màn hình mà không cần user reload.
*   **Architecture Update**: Cập nhật lại tài liệu kiến trúc để phản ánh đúng công nghệ đang dùng (Supabase cho DB/Auth).

## 5. Tối Ưu Môi Trường Phát Triển

### Thách thức
*   **Lỗi Ổ Cứng**: Các thư mục `build/` và cache của Flutter/Gradle chiếm dụng rất nhiều dung lượng, gây lỗi build.
*   **Xung đột thư viện**: Các phiên bản package không tương thích (`dependency hell`).

### Giải pháp
*   **Maintenance Scripts**: Thường xuyên chạy `flutter clean` và xoá các thư mục build cũ.
*   **Version Pinning**: Cố định phiên bản trong `pubspec.yaml` để tránh các bản cập nhật tự động gây lỗi (breaking changes).

## 6. Các Giới Hạn Hiện Tại (Limitations)

### Thách thức
*   **Phụ thuộc vào Internet**: Tính năng phân tích AI và kiểm tra danh sách đen yêu cầu kết nối mạng ổn định. Chế độ offline chỉ xem được các email đã lưu cache.
*   **Chi phí API**: Việc sử dụng Gemini Pro/Flash và các API Google Cloud có thể phát sinh chi phí lớn nếu mở rộng quy mô (cần tối ưu quota).
*   **Độ trễ phân tích**: Với các email cực dài hoặc kèm nhiều file đính kèm, phản hồi từ AI có thể mất vài giây, gây trễ trải nghiệm.
*   **Quyền riêng tư tuyệt đối**: Dù đã ẩn danh hóa, nhưng dữ liệu vẫn phải gửi lên Cloud để xử lý. Chưa có giải pháp chạy Local LLM hoàn toàn trên thiết bị (On-device AI) hiệu quả cho điện thoại cấu hình thấp.

### Giải pháp (Kế hoạch tương lai)
*   **Offline Mode**: Tích hợp mô hình AI nhỏ gọn (như MediaPipe LLM) chạy trực tiếp trên thiết bị (On-device) cho các tác vụ phân tích cơ bản khi không có mạng.
*   **Caching Strategy**: Tối ưu hóa bộ nhớ cache để lưu kết quả phân tích cũ, tránh gọi API lặp lại cho cùng một email.
