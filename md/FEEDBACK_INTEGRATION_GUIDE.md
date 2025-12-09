# Hướng dẫn tích hợp Feedback Widget

## Tổng quan
Tôi đã tạo thành công widget feedback riêng biệt tại `lib/widgets/email_feedback_widget.dart`. 
Bây giờ bạn chỉ cần thêm 2 đoạn code nhỏ vào file `lib/screens/email_detail_screen.dart`.

## Các file đã tạo

### 1. FeedbackService
- **File**: `lib/services/feedback_service.dart` ✅ Đã tạo
- **Chức năng**: Lưu trữ và quản lý feedback của người dùng

### 2. Localization
- **File**: `lib/localization/app_localizations.dart` ✅ Đã cập nhật
- **Keys đã thêm**:
  - `feedback_section_title`
  - `feedback_input_hint`
  - `feedback_reanalyze_button`
  - `feedback_submit_button`
  - `feedback_submitted`
  - `feedback_reanalyzing`
  - `feedback_history_title`
  - `feedback_you`
  - `feedback_empty_message`

### 3. EmailFeedbackWidget
- **File**: `lib/widgets/email_feedback_widget.dart` ✅ Đã tạo
- **Chức năng**: Widget UI hoàn chỉnh cho feedback section

## Cách tích hợp vào EmailDetailScreen

### Bước 1: Thêm import
Mở file `lib/screens/email_detail_screen.dart` và thêm dòng sau vào phần import (sau dòng 8):

```dart
import '../widgets/email_feedback_widget.dart';
```

Sau khi thêm, phần import sẽ trông như thế này:
```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../models/scan_result.dart';
import '../services/email_analysis_service.dart';
import '../services/scan_history_service.dart';
import '../services/notification_service.dart';
import '../localization/app_localizations.dart';
import '../widgets/email_feedback_widget.dart';  // ← THÊM DÒNG NÀY
import 'email_ai_chat_screen.dart';
import 'compose_email_screen.dart';
```

### Bước 2: Thêm widget vào UI
Tìm đến dòng 239-246 trong file `email_detail_screen.dart`, bạn sẽ thấy:

```dart
body: SingleChildScrollView(
  child: Column(
    children: [
      if (_scanResult != null) _buildAnalysisResult(),
      _buildEmailContent(),
      const SizedBox(height: 80),
    ],
  ),
),
```

Thay đổi thành:

```dart
body: SingleChildScrollView(
  child: Column(
    children: [
      if (_scanResult != null) _buildAnalysisResult(),
      _buildEmailContent(),
      EmailFeedbackWidget(              // ← THÊM 4 DÒNG NÀY
        emailId: widget.email.id,
        onReanalyze: _analyzeEmail,
      ),
      const SizedBox(height: 80),
    ],
  ),
),
```

## Kiểm tra

Sau khi thêm code, chạy lệnh:

```bash
flutter run
```

Feedback widget sẽ xuất hiện ở cuối email detail screen với:
- ✅ Input field để nhập feedback
- ✅ Nút "Re-analyze" để phân tích lại email
- ✅ Nút "Send Feedback" để gửi feedback
- ✅ Hiển thị lịch sử feedback đã gửi
- ✅ Hỗ trợ dark mode
- ✅ UI đẹp với gradient và animation

## Tính năng

1. **Nhập feedback**: Người dùng có thể nhập ý kiến về kết quả phân tích
2. **Re-analyze**: Trigger phân tích lại email với feedback mới
3. **Lịch sử**: Hiển thị tất cả feedback đã gửi cho email này
4. **Lưu trữ local**: Feedback được lưu an toàn với FlutterSecureStorage
5. **Theme-aware**: Tự động thích ứng với light/dark mode

## Troubleshooting

Nếu gặp lỗi import, đảm bảo:
1. File `lib/widgets/email_feedback_widget.dart` tồn tại
2. Đã thêm đúng import statement
3. Chạy `flutter pub get` nếu cần

## Demo UI

Widget sẽ hiển thị với:
- Header có icon feedback và title
- Input area với avatar và text field
- 2 buttons: Re-analyze (màu cam) và Send Feedback (màu xanh)
- Feedback history với avatar, tên, thời gian và nội dung

Chúc bạn thành công! 🎉
