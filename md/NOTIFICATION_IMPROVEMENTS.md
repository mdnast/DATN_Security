# Cải Tiến Hệ Thống Thông Báo Email

## 📋 Tổng Quan Các Cải Tiến

### 1. ✅ Lưu Kết Quả Phân Tích
**Vấn đề:** Khi background service phân tích email và gửi thông báo, kết quả không được lưu vào database. Khi user mở chi tiết email, không thấy kết quả phân tích.

**Giải pháp:** 
- Background service (`background_email_service.dart`) và Quick checker (`quick_email_checker.dart`) bây giờ lưu kết quả phân tích vào `ScanHistoryService`
- Khi user mở chi tiết email, `EmailDetailScreen` sẽ load kết quả từ scan history

**Files đã sửa:**
- `lib/services/background_email_service.dart`
- `lib/services/quick_email_checker.dart`

### 2. 🔔 Navigation Từ Notification
**Vấn đề:** Khi tap vào notification, không có gì xảy ra hoặc không mở đúng email.

**Giải pháp:**
- Thêm `GlobalKey<NavigatorState>` trong `main.dart`
- `NotificationService` sử dụng navigator key để navigate đến `EmailDetailScreen`
- Email data được cache và load lại khi tap notification

**Files đã sửa:**
- `lib/main.dart` - Thêm navigator key
- `lib/services/notification_service.dart` - Thêm navigation handler

### 3. 💾 Email Cache System
**Vấn đề:** Notification chỉ chứa một phần thông tin email, không đủ để hiển thị chi tiết.

**Giải pháp:**
- Tạo email cache system sử dụng `FlutterSecureStorage`
- Khi phân tích email, lưu full email data vào cache với key `email_cache_{email_id}`
- Khi tap notification, load email từ cache

**Files đã sửa:**
- `lib/services/background_email_service.dart` - Thêm `_saveEmailCache()`
- `lib/services/quick_email_checker.dart` - Thêm `_saveEmailCache()`

---

## 🔧 Chi Tiết Kỹ Thuật

### 1. Background Email Service (`background_email_service.dart`)

#### Thay đổi:
```dart
// TRƯỚC: Chỉ gửi notification
await _analyzeAndNotify(email, analysisService, notificationService);

// SAU: Lưu kết quả + cache + gửi notification
await _analyzeAndNotify(
  email, 
  analysisService, 
  notificationService, 
  scanHistoryService,  // ✅ Thêm
  storage              // ✅ Thêm
);
```

#### Trong `_analyzeAndNotify()`:
```dart
// ✅ Lưu kết quả phân tích
await scanHistoryService.saveScanResult(result);

// ✅ Lưu email cache
await _saveEmailCache(storage, email);

// ✅ Thêm action flag vào notification data
data: {
  'email_id': email.id,
  'from': email.from,
  'subject': email.subject,
  'snippet': email.snippet,
  'body': email.body ?? '',
  'date': email.date.toIso8601String(),
  'action': 'open_email_detail', // ✅ Flag để navigate
  ...
}
```

### 2. Notification Service (`notification_service.dart`)

#### Thay đổi chính:
```dart
// ✅ 1. Thêm GlobalKey để navigate
static GlobalKey<NavigatorState>? _navigatorKey;

static void setNavigatorKey(GlobalKey<NavigatorState> key) {
  _navigatorKey = key;
}

// ✅ 2. Handle notification tap
void _onNotificationTapped(NotificationResponse response) async {
  if (response.payload != null) {
    final data = jsonDecode(response.payload!);
    if (data['action'] == 'open_email_detail') {
      await _navigateToEmailDetail(data);
    }
  }
}

// ✅ 3. Navigate đến EmailDetailScreen
Future<void> _navigateToEmailDetail(Map<String, dynamic> data) async {
  // Load email từ cache
  final emailCacheJson = await _storage.read(key: 'email_cache_$emailId');
  
  // Tạo EmailMessage object
  final email = EmailMessage(...);
  
  // Navigate
  await Navigator.push(
    _navigatorKey!.currentContext!,
    MaterialPageRoute(
      builder: (context) => EmailDetailScreen(email: email),
    ),
  );
}

// ✅ 4. Thêm payload vào local notification
await _localNotifications.show(
  notification.id.hashCode,
  notification.title,
  notification.body,
  details,
  payload: jsonEncode(notification.data), // ✅ Thêm payload
);
```

### 3. Main App (`main.dart`)

#### Thay đổi:
```dart
// ✅ 1. Tạo GlobalKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  // ...
  
  // ✅ 2. Set navigator key cho NotificationService
  NotificationService.setNavigatorKey(navigatorKey);
  
  runApp(const MyApp());
}

// ✅ 3. Set navigatorKey cho MaterialApp
return MaterialApp(
  navigatorKey: navigatorKey, // ✅ Quan trọng!
  // ...
);
```

### 4. Quick Email Checker (`quick_email_checker.dart`)

Tương tự như `background_email_service.dart`:
- Lưu kết quả vào `ScanHistoryService`
- Lưu email cache
- Thêm action flag vào notification

---

## 🚀 Cách Hoạt Động

### Flow Khi Có Email Mới (Background):

```
1. WorkManager chạy background task (mỗi 15 phút)
   ↓
2. BackgroundEmailService fetch emails mới
   ↓
3. Phân tích email bằng EmailAnalysisService
   ↓
4. LƯU kết quả vào ScanHistoryService ✅
   ↓
5. LƯU email vào cache ✅
   ↓
6. Gửi notification với full data + action flag ✅
   ↓
7. User tap notification
   ↓
8. NotificationService load email từ cache
   ↓
9. Navigate đến EmailDetailScreen ✅
   ↓
10. EmailDetailScreen load scan result từ history ✅
```

### Flow Khi User Check Email Thủ Công:

```
1. User tap "Check Email Ngay" trong HomeScreen
   ↓
2. QuickEmailChecker fetch emails mới
   ↓
3. Phân tích email
   ↓
4. LƯU kết quả + cache + gửi notification
   ↓
5. User tap notification → mở EmailDetailScreen với kết quả phân tích
```

---

## 📱 Testing

### Test Case 1: Background Notification
```
1. Mở app
2. Đăng nhập
3. Đóng app (minimize)
4. Đợi 1-2 phút (hoặc send email test)
5. Nhận notification
6. Tap vào notification
7. ✅ Expect: App mở và navigate đến email detail với kết quả phân tích
```

### Test Case 2: Quick Check
```
1. Mở app
2. Tap "Check Email Ngay" trong Settings
3. Nhận notification
4. Tap vào notification
5. ✅ Expect: Navigate đến email detail với kết quả phân tích
```

### Test Case 3: Email Detail Persistence
```
1. Mở app
2. Check email mới (có notification)
3. Tap vào notification → xem email detail
4. Back về home
5. Vào Email List → tap vào cùng email đó
6. ✅ Expect: Vẫn thấy kết quả phân tích (không phải analyze lại)
```

---

## 🐛 Troubleshooting

### Notification không hiển thị khi đóng app
**Nguyên nhân:** WorkManager periodic task có minimum 15 phút (Android limitation)

**Giải pháp:**
- Foreground monitoring (khi app mở): 10 giây
- Background monitoring (khi app đóng): 15 phút
- Có thể giảm xuống bằng cách dùng Foreground Service (cần thêm notification channel)

### Tap notification không mở app
**Kiểm tra:**
1. `AndroidManifest.xml` có đủ permissions chưa?
2. `main.dart` đã set `navigatorKey` chưa?
3. `NotificationService.setNavigatorKey()` được gọi chưa?
4. Notification có `payload` chưa?

### Email detail không có kết quả phân tích
**Kiểm tra:**
1. `_scanHistoryService.saveScanResult(result)` được gọi chưa?
2. Xem logs: "✅ Analysis result saved to history"
3. Check `SharedPreferences` có data không

---

## 🔮 Cải Tiến Tiếp Theo

### 1. Foreground Service
Để app chạy ngầm tốt hơn:
```dart
// Thêm vào AndroidManifest.xml
<service
    android:name=".ForegroundEmailService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="dataSync" />
```

### 2. Real-time với Gmail Push Notifications
Thay vì poll mỗi 15 phút, dùng Gmail Push API để nhận notification realtime.

### 3. Notification Channels
Tạo nhiều channels:
- Phishing Alerts (High priority, sound)
- Suspicious Emails (Medium priority)
- Safe Emails (Low priority, silent)

### 4. Rich Notifications
Thêm actions vào notification:
```dart
actions: [
  AndroidNotificationAction('view', 'Xem chi tiết'),
  AndroidNotificationAction('delete', 'Xóa'),
  AndroidNotificationAction('mark_safe', 'Đánh dấu an toàn'),
]
```

---

## 📚 Tài Liệu Tham Khảo

- [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications)
- [WorkManager](https://pub.dev/packages/workmanager)
- [Flutter Navigation](https://docs.flutter.dev/cookbook/navigation)
- [Android Background Work](https://developer.android.com/guide/background)

---

## ✅ Summary

**Đã hoàn thành:**
1. ✅ Lưu kết quả phân tích vào database
2. ✅ Navigation từ notification đến email detail
3. ✅ Email cache system
4. ✅ Background service improvements

**Kết quả:**
- User tap notification → mở đúng email
- Email detail hiển thị kết quả phân tích (không cần analyze lại)
- Background service hoạt động tốt hơn
- App có thể chạy ngầm để monitor email
