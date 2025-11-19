# Stop Continuous Email Checking

## ✅ ĐÃ THAY ĐỔI

### TRƯỚC (Check Liên Tục):
```
❌ Foreground: Check mỗi 10 giây (khi app mở)
❌ Background: Check mỗi 15 phút (khi app đóng)
❌ Result: Spam notifications, lãng phí pin
```

### SAU (Check Thông Minh):
```
✅ Mở app: Check 1 lần duy nhất (sau 5s)
✅ Background: Check mỗi 30 phút (giảm từ 15 phút)
✅ Manual: User có thể ấn "Check Email Ngay"
✅ Result: Tiết kiệm pin, không spam
```

---

## 🎯 KHI NÀO CHECK EMAIL?

### 1. **Khi Mở App** (1 lần)
```
User mở app → HomeScreen
   ↓
Đợi 5 giây
   ↓
Check emails 1 lần
   ↓
Phân tích AI
   ↓
Gửi notification nếu có email mới
   ↓
XONG (không check liên tục)
```

### 2. **Background Check** (Mỗi 30 phút)
```
WorkManager task chạy mỗi 30 phút
   ↓
Check emails từ Gmail
   ↓
Phân tích AI
   ↓
Gửi notification nếu có email mới
```

### 3. **Manual Check** (Khi user ấn nút)
```
User ấn "Check Email Ngay" trong Settings
   ↓
Check ngay lập tức
   ↓
Phân tích AI
   ↓
Gửi notification
```

---

## 📊 SO SÁNH

### Frequency:
**TRƯỚC:**
- Foreground: 10s × 60 = **6 lần/phút**
- Background: **4 lần/giờ** (mỗi 15 phút)
- **Tổng: ~370 lần/giờ** (nếu app mở suốt)

**SAU:**
- Mở app: **1 lần**
- Background: **2 lần/giờ** (mỗi 30 phút)
- **Tổng: ~2-3 lần/giờ** (giảm 99%)

### Pin Usage:
**TRƯỚC:** ❌ Cao (check liên tục)
**SAU:** ✅ Thấp (chỉ check khi cần)

### Notification:
**TRƯỚC:** ❌ Spam (mỗi 10s nếu có email)
**SAU:** ✅ Hợp lý (chỉ khi thật sự có email mới)

---

## 🔧 THAY ĐỔI CODE

### 1. HomeScreen - Tắt Foreground Monitoring
**File:** `lib/screens/home_screen.dart`

**TRƯỚC:**
```dart
// Foreground monitoring (check mỗi 10 giây)
await _emailMonitorService.startMonitoring();
print('✅ Foreground email monitoring started (10s interval)');

// Background monitoring (mỗi 15 phút)
await BackgroundEmailService.registerPeriodicTask();
```

**SAU:**
```dart
// ❌ TẮT foreground monitoring - KHÔNG CHECK LIÊN TỤC
// Chỉ check khi:
// 1. Mở app → 1 lần (sau 5s)
// 2. Background (30 phút)
// 3. Manual (button)

print('📱 Foreground monitoring: DISABLED');

// Background monitoring (30 phút)
await BackgroundEmailService.registerPeriodicTask();
```

### 2. Background Service - Tăng Interval
**File:** `lib/services/background_email_service.dart`

**TRƯỚC:**
```dart
frequency: const Duration(minutes: 15), // 15 phút
```

**SAU:**
```dart
frequency: const Duration(minutes: 30), // ✅ 30 PHÚT
```

### 3. Force Check - Giữ Nguyên
**File:** `lib/screens/home_screen.dart`

```dart
// ✅ Check 1 lần khi mở app (sau 5s)
Future.delayed(const Duration(seconds: 5), () {
  if (mounted && !_isDisposed) {
    _checkEmailsNow(); // Check 1 lần duy nhất
  }
});
```

---

## 🎛️ TÙY CHỈNH INTERVAL

### Muốn Check Ít Hơn? (1 giờ)
```dart
// background_email_service.dart
frequency: const Duration(hours: 1), // ✅ 1 GIỜ
```

### Muốn Check Nhiều Hơn? (15 phút)
```dart
// background_email_service.dart
frequency: const Duration(minutes: 15), // 15 phút (min Android)
```

**Lưu ý:** Android không cho phép < 15 phút

---

## 💡 REAL-TIME EMAIL NOTIFICATION (Advanced)

Nếu bạn muốn **THẬT SỰ REAL-TIME** (nhận notification ngay khi có email), cần dùng **Gmail Push Notifications**:

### Cách Hoạt Động:
```
Gmail server
   ↓
Email mới đến
   ↓
Gmail gửi notification đến Cloud Pub/Sub
   ↓
Pub/Sub trigger Cloud Function
   ↓
Cloud Function gửi FCM notification đến app
   ↓
App nhận notification → check và phân tích email
```

### Setup (Phức Tạp):
1. **Gmail API Push Notifications**
   - Enable Gmail API Push
   - Setup Cloud Pub/Sub
   - Watch Gmail inbox

2. **Cloud Function**
   - Tạo Cloud Function listen Pub/Sub
   - Parse email notification
   - Gửi FCM notification

3. **App Handle FCM**
   - Nhận FCM notification
   - Trigger email check & analysis

**Chi phí:** Free tier Google Cloud (có giới hạn)

---

## 🧪 TEST

### Test 1: Check Khi Mở App
```
1. Mở app
2. Đợi 5 giây
3. ✅ Thấy: "🔄 Checking emails once on app open..."
4. ✅ Nhận notification nếu có email mới
5. ❌ KHÔNG thấy check liên tục sau đó
```

### Test 2: Background Check
```
1. Mở app → Login
2. Đóng app (minimize)
3. Đợi 30 phút
4. ✅ Background check chạy (xem logs)
5. ✅ Nhận notification nếu có email mới
```

### Test 3: Manual Check
```
1. Mở app
2. Vào Settings (3 chấm)
3. Tap "Check Email Ngay"
4. ✅ Check ngay lập tức
5. ✅ Nhận notification
```

---

## 📱 USER EXPERIENCE

### TRƯỚC:
```
❌ App check liên tục (10s)
❌ Pin hao nhanh
❌ Spam notifications
❌ Lãng phí resources
```

### SAU:
```
✅ Check thông minh (khi cần)
✅ Tiết kiệm pin
✅ Notification hợp lý
✅ Tối ưu resources
```

---

## ⚙️ SETTINGS (Có Thể Thêm)

Có thể thêm settings cho user tùy chỉnh:

```dart
// Settings screen
SwitchListTile(
  title: Text('Background Monitoring'),
  subtitle: Text('Check email mỗi 30 phút'),
  value: _backgroundEnabled,
  onChanged: (value) async {
    if (value) {
      await BackgroundEmailService.registerPeriodicTask();
    } else {
      await BackgroundEmailService.cancelAllTasks();
    }
  },
);

// Slider cho interval
Slider(
  label: 'Check mỗi ${_interval} phút',
  min: 15,
  max: 120,
  divisions: 7,
  value: _interval,
  onChanged: (value) {
    setState(() => _interval = value);
    // Update WorkManager frequency
  },
);
```

---

## 🔍 LOGS DEBUG

### Xem Khi Nào Check:
```bash
# Filter logs
adb logcat | grep -E "CHECKING|Background task"

# Expected:
🔄 Checking emails once on app open...
=== CHECKING EMAILS NOW ===
Found 2 new emails
...
(sau 30 phút)
=== BACKGROUND TASK STARTED ===
Task: emailCheckTask
Checking for new emails...
```

---

## 📝 FILES ĐÃ SỬA

```
✅ lib/screens/home_screen.dart
   - Tắt foreground monitoring
   - Giữ force check khi mở app
   - Update comments

✅ lib/services/background_email_service.dart
   - Tăng frequency: 15 min → 30 min
   - Update logs

✅ STOP_CONTINUOUS_CHECK.md (này)
   - Documentation đầy đủ
```

---

## 🎉 KẾT QUẢ

**App giờ:**
1. ✅ KHÔNG check liên tục (10s) nữa
2. ✅ Chỉ check khi mở app (1 lần)
3. ✅ Background check mỗi 30 phút
4. ✅ Manual check khi user muốn
5. ✅ Tiết kiệm pin
6. ✅ Không spam notifications
7. ✅ Vẫn nhận được email mới trong 30 phút

**Nếu muốn thật sự real-time:**
- Setup Gmail Push Notifications (phức tạp)
- Hoặc giảm background interval xuống 15 phút (min Android)
- Hoặc user mở app để check

---

## 🚀 BUILD & TEST

```bash
flutter clean
flutter pub get
flutter run
```

**Test checklist:**
- [ ] Mở app → check 1 lần (5s)
- [ ] Không thấy check liên tục sau đó
- [ ] Đóng app → background check (30 min)
- [ ] Manual check hoạt động
- [ ] Notification chỉ khi có email mới
- [ ] Pin usage thấp hơn

---

🎉 **DONE! App giờ không check liên tục, chỉ check khi thật sự cần!**
