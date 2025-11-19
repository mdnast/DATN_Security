# Debug Guide - Troubleshooting Auto-Start

## 🔍 Kiểm Tra Auto-Start Có Hoạt Động Không

### 1. Check Logs Khi Mở App

Khi bạn mở app và đăng nhập, hãy xem logs (sử dụng `adb logcat` hoặc Android Studio):

```bash
adb logcat | grep -E "EMAIL MONITORING|NOTIFICATION|WorkManager"
```

**Logs mong đợi:**
```
🚀 STARTING EMAIL MONITORING
📱 Starting foreground monitoring...
✅ Email monitor started - checking every 10 seconds
✅ Foreground email monitoring started (10s interval)
🌙 Registering background monitoring...
✅ Background email check registered - runs every 15 minutes
✅ Background email monitoring registered (15min interval)
🎉 EMAIL MONITORING STARTED SUCCESSFULLY
```

### 2. Kiểm Tra HomeScreen InitState

**File:** `lib/screens/home_screen.dart`

```dart
@override
void initState() {
  super.initState();
  _loadUserData();
  _loadNotificationCount();
  _startEmailMonitoring();  // ✅ Phải được gọi ở đây
}
```

### 3. Kiểm Tra EmailMonitorService

**File:** `lib/services/email_monitor_service.dart`

Xem logs:
```
=== STARTING EMAIL MONITOR ===
Email monitor started - checking every 10 seconds
Checking for new emails...
```

**Nếu KHÔNG thấy logs này → service KHÔNG start**

---

## ❌ Vấn Đề 1: Auto-Start Không Hoạt Động

### Nguyên Nhân Có Thể:
1. HomeScreen không được mở (user ở screen khác)
2. EmailMonitorService.startMonitoring() bị lỗi
3. Gmail credentials chưa được lưu
4. Internet không có

### Cách Fix:

#### Fix 1: Đảm bảo HomeScreen được mở sau login
```dart
// Trong AuthWrapper hoặc LoginScreen
// Sau khi login thành công:
Navigator.pushReplacementNamed(context, '/home');  // ✅ Đúng
// KHÔNG dùng: Navigator.pushNamed() mà không remove stack
```

#### Fix 2: Kiểm tra Gmail Service
```dart
// Thêm log trong EmailMonitorService
Future<void> startMonitoring() async {
  print('=== STARTING EMAIL MONITOR ===');
  
  try {
    // Test fetch emails
    final emails = await _gmailService.fetchEmails(maxResults: 1);
    print('✅ Gmail service working: found ${emails.length} emails');
  } catch (e) {
    print('❌ Gmail service error: $e');
    return;  // Dừng nếu không fetch được
  }
  
  // ... rest of code
}
```

#### Fix 3: Force start trong AuthWrapper
```dart
// lib/screens/auth_wrapper.dart
class _AuthWrapperState extends State<AuthWrapper> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final isLoggedIn = await _authService.isLoggedIn();
    
    if (isLoggedIn) {
      // ✅ Force start monitoring ngay khi đã login
      print('User already logged in, starting monitoring...');
      await AutoStartService.checkAndRestart();
    }
  }
}
```

---

## ❌ Vấn Đề 2: Notification Không Navigate

### Check List:

#### 1. Notification có data đúng không?
```dart
// Trong background_email_service.dart
await notificationService.showNotification(
  title: title,
  body: body,
  type: type,
  data: {
    'email_id': email.id,              // ✅ Phải có
    'from': email.from,                // ✅ Phải có
    'subject': email.subject,          // ✅ Phải có
    'snippet': email.snippet,          // ✅ Phải có
    'body': email.body ?? '',          // ✅ Phải có
    'date': email.date.toIso8601String(), // ✅ Phải có
    'action': 'open_email_detail',     // ✅ Quan trọng!
  },
);
```

#### 2. Notification tap handler có được setup không?
```dart
// main.dart
void main() async {
  // ...
  NotificationService.setNavigatorKey(navigatorKey);  // ✅ Phải có
  // ...
}

// MaterialApp
return MaterialApp(
  navigatorKey: navigatorKey,  // ✅ Phải có
  // ...
);
```

#### 3. Email cache có được lưu không?
```dart
// Check trong background_email_service.dart
Future<void> _saveEmailCache(...) {
  print('Saving email cache for ${email.id}');
  await _storage.write(key: 'email_cache_${email.id}', value: emailJson);
  print('✅ Email cache saved');
}
```

**Test email cache:**
```dart
// Trong Flutter debug console:
final storage = FlutterSecureStorage();
final keys = await storage.readAll();
print('Cached emails: ${keys.keys.where((k) => k.startsWith('email_cache_'))}');
```

---

## 🔧 Debug Commands

### 1. Check WorkManager Tasks
```bash
adb shell dumpsys jobscheduler | grep -A 20 "be.tramckrijte.workmanager"
```

### 2. Force Run WorkManager Task
```bash
# Trong Flutter debug console:
await BackgroundEmailService.registerPeriodicTask();
```

### 3. Test Notification Navigation
```dart
// Trong Flutter debug console:
final notification = NotificationModel(
  id: 'test',
  title: 'Test',
  body: 'Test body',
  type: 'test',
  timestamp: DateTime.now(),
  data: {
    'email_id': 'test_id',
    'from': 'test@test.com',
    'subject': 'Test subject',
    'snippet': 'Test snippet',
    'body': 'Test body',
    'date': DateTime.now().toIso8601String(),
    'action': 'open_email_detail',
  },
);

await NotificationService().showNotification(
  title: notification.title,
  body: notification.body,
  type: notification.type,
  data: notification.data,
);
```

---

## 📊 Expected Flow

### Lần Đầu Mở App:
```
1. App start
   ↓
2. main() → AutoStartService.checkAndRestart()
   → Chưa enable, auto enable
   → Register background task
   ↓
3. User login
   ↓
4. Navigate to HomeScreen
   ↓
5. HomeScreen.initState() → _startEmailMonitoring()
   ↓
6. EmailMonitorService.startMonitoring() (10s)
   BackgroundEmailService.registerPeriodicTask() (15min)
   ↓
7. ✅ Monitoring bắt đầu
```

### Sau Khi Reboot:
```
1. Device boot
   ↓
2. App auto-start (BOOT_COMPLETED)
   ↓
3. main() → AutoStartService.checkAndRestart()
   → Check last start time
   → Restart nếu >24h hoặc chưa start
   ↓
4. ✅ Background monitoring tiếp tục
```

### Khi Có Email Mới:
```
1. WorkManager task chạy (mỗi 15 phút)
   ↓
2. Fetch emails mới
   ↓
3. Phân tích AI
   ↓
4. Lưu kết quả vào ScanHistoryService ✅
   ↓
5. Lưu email vào cache ✅
   ↓
6. Gửi notification với full data ✅
   ↓
7. User tap notification
   ↓
8. Load email từ cache
   ↓
9. Navigate đến EmailDetailScreen ✅
   ↓
10. Load scan result từ history ✅
```

---

## 🎯 Quick Tests

### Test 1: Check Monitoring Status
```dart
// Trong HomeScreen
print('Is monitoring: ${_emailMonitorService.isMonitoring}');
```

Expected: `true` sau khi HomeScreen.initState() chạy

### Test 2: Manual Check
```dart
// Tap "Check Email Ngay" trong settings
// Xem logs:
=== QUICK CHECK & ANALYZE START ===
Fetching emails...
Found X emails total
🆕 Found Y NEW email(s)!
🔍 Analyzing: [subject]
✅ Analysis result saved to history
Email cache saved for [id]
✅ Notification sent
```

### Test 3: Notification Tap
```dart
// Khi tap vào notification trong Notification Screen
=== NOTIFICATION TAPPED IN LIST ===
Type: phishing
Data: {email_id: xxx, from: yyy, ...}
Email ID: xxx
✅ Email found in cache
✅ Navigating to EmailDetailScreen...
✅ Navigation completed
```

---

## 🚨 Common Errors

### Error 1: "Gmail service not authenticated"
**Fix:** User chưa login hoặc credentials expired
```dart
// Force re-login
await _authService.signOut();
// Login lại
```

### Error 2: "WorkManager task not registered"
**Fix:** 
```dart
await BackgroundEmailService.cancelAllTasks();
await BackgroundEmailService.registerPeriodicTask();
```

### Error 3: "Navigator context is null"
**Fix:** `navigatorKey` chưa được set
```dart
// main.dart
NotificationService.setNavigatorKey(navigatorKey);
```

### Error 4: "Email cache not found"
**Fix:** Notification data không có email info
```dart
// Fallback: tạo email từ notification data
email = EmailMessage(
  id: emailId,
  from: notification.data!['from'] ?? 'Unknown',
  // ...
);
```

---

## ✅ Verification Checklist

Sau khi fix, verify:
- [ ] Mở app → thấy logs monitoring start
- [ ] Đợi 10 giây → thấy logs checking emails
- [ ] Send email test → nhận notification trong 15 phút
- [ ] Tap notification → mở đúng email detail
- [ ] Email detail có kết quả phân tích
- [ ] Reboot device → monitoring auto-restart
- [ ] Check WorkManager tasks → thấy task đã register

---

## 📞 Need More Help?

Xem:
- `AUTO_START_GUIDE.md` - Chi tiết auto-start
- `NOTIFICATION_IMPROVEMENTS.md` - Chi tiết notification
- `QUICK_START.md` - Hướng dẫn sử dụng

Hoặc check logs với:
```bash
adb logcat | grep -E "EMAIL|NOTIFICATION|MONITOR|WorkManager"
```
