# Balanced Email Monitoring - Cân Bằng Giữa Real-time & Pin

## ✅ GIẢI PHÁP CUỐI CÙNG

### Vấn Đề:
1. **10 giây:** ❌ Quá nhanh → Lãng phí pin, spam notifications
2. **30 phút:** ❌ Quá chậm → Không nhận notification kịp thời

### Giải Pháp: **CÂN BẰNG**
```
✅ Foreground: Check mỗi 2 PHÚT (khi app mở)
✅ Background: Check mỗi 15 PHÚT (khi app đóng)
✅ Force check: 1 lần khi mở app (sau 5s)
✅ Manual: User có thể check bất kỳ lúc nào
```

---

## 🎯 MONITORING STRATEGY

### 1. **Khi App Đang Mở** (Foreground)
```
Check mỗi 2 PHÚT
   ↓
Tìm emails mới
   ↓
Phân tích AI
   ↓
Gửi notification
```

**Tại sao 2 phút?**
- ✅ Đủ nhanh để user nhận notification kịp thời
- ✅ Không lãng phí pin như 10 giây
- ✅ Không spam notifications
- ✅ Cân bằng giữa real-time và performance

### 2. **Khi App Đóng** (Background)
```
Check mỗi 15 PHÚT (minimum Android)
   ↓
Tìm emails mới
   ↓
Phân tích AI
   ↓
Gửi notification (ngay cả khi app đóng)
```

**Tại sao 15 phút?**
- ✅ Minimum interval Android cho phép cho WorkManager
- ✅ Đảm bảo user vẫn nhận notification khi app đóng
- ✅ Tiết kiệm pin hơn check liên tục

### 3. **Force Check Khi Mở App**
```
Mở app → Đợi 5s → Check 1 lần
```

**Tại sao?**
- ✅ Đảm bảo check ngay khi user mở app
- ✅ Không phải đợi đến chu kỳ tiếp theo

---

## 📊 SO SÁNH CÁC PHƯƠNG ÁN

| Phương án | Foreground | Background | Pin | Real-time | Kết quả |
|-----------|-----------|-----------|-----|-----------|---------|
| **10s / 15min** | 10s | 15min | ❌ Cao | ✅ Rất tốt | Lãng phí pin |
| **Tắt / 30min** | Tắt | 30min | ✅ Thấp | ❌ Chậm | Không kịp thời |
| **2min / 15min** ⭐ | 2min | 15min | ✅ Hợp lý | ✅ Tốt | **CÂN BẰNG** |

---

## 🔋 PIN USAGE COMPARISON

### 10 giây / 15 phút (CŨ):
```
Foreground: 6 lần/phút × 60 = 360 lần/giờ
Background: 4 lần/giờ
Tổng khi app mở: ~360 lần/giờ ❌
```

### 2 phút / 15 phút (MỚI):
```
Foreground: 30 lần/giờ
Background: 4 lần/giờ
Tổng khi app mở: ~30 lần/giờ ✅ (giảm 92%)
```

---

## ⏱️ NOTIFICATION TIMING

### Scenario: Email đến lúc 10:00

**Với 10s / 15min:**
```
Email đến: 10:00:00
App mở: Notification trong ~10 giây → 10:00:10 ✅
App đóng: Notification trong ~15 phút → 10:15:00 ✅
Pin usage: ❌ Cao
```

**Với Tắt / 30min:**
```
Email đến: 10:00:00
App mở: Notification trong ~5 giây → 10:00:05 ✅
App đóng: Notification trong ~30 phút → 10:30:00 ❌ Chậm
Pin usage: ✅ Thấp
```

**Với 2min / 15min (MỚI):**
```
Email đến: 10:00:00
App mở: Notification trong ~2 phút → 10:02:00 ✅✅
App đóng: Notification trong ~15 phút → 10:15:00 ✅
Pin usage: ✅ Hợp lý
```

---

## 🎛️ CÀI ĐẶT

### EmailMonitorService
```dart
// File: lib/services/email_monitor_service.dart
static const int _checkIntervalSeconds = 120; // ✅ 2 PHÚT (120s)
```

### BackgroundEmailService
```dart
// File: lib/services/background_email_service.dart
frequency: const Duration(minutes: 15), // ✅ 15 PHÚT
```

### HomeScreen
```dart
// File: lib/screens/home_screen.dart

// Bật cả foreground và background
await _emailMonitorService.startMonitoring();     // 2 min
await BackgroundEmailService.registerPeriodicTask(); // 15 min

// Force check khi mở app
Future.delayed(const Duration(seconds: 5), () {
  _checkEmailsNow();
});
```

---

## 🧪 TEST & VERIFY

### Test 1: Foreground Monitoring (2 phút)
```
1. Mở app → Login
2. Để app mở
3. Xem logs mỗi 2 phút:
   "Checking for new emails..."
4. ✅ Thấy check mỗi 2 phút
5. Send email test
6. ✅ Nhận notification trong ~2 phút
```

### Test 2: Background Monitoring (15 phút)
```
1. Mở app → Login
2. Đóng app (minimize)
3. Đợi 15-20 phút
4. Send email test
5. ✅ Nhận notification
6. Check logs: "=== BACKGROUND TASK STARTED ==="
```

### Test 3: Force Check (5 giây)
```
1. Mở app
2. Đợi 5 giây
3. ✅ Thấy: "🔄 Checking emails once on app open..."
4. ✅ Nhận notification nếu có email mới
```

---

## 🔍 DEBUG COMMANDS

### Check Foreground Monitoring
```bash
adb logcat | grep "Checking for new emails"

# Expected mỗi 2 phút:
Checking for new emails...
Found X emails total
🆕 Found Y NEW email(s)!
```

### Check Background Monitoring
```bash
adb logcat | grep "BACKGROUND TASK"

# Expected mỗi 15 phút:
=== BACKGROUND TASK STARTED ===
Task: emailCheckTask
Time: 2025-01-12 10:15:00
```

### Check WorkManager Status
```bash
adb shell dumpsys jobscheduler | grep workmanager
```

---

## 🎯 TÙY CHỈNH INTERVAL

### Nếu Muốn Real-time Hơn (1 phút)
```dart
// email_monitor_service.dart
static const int _checkIntervalSeconds = 60; // 1 PHÚT

// Trade-off: Pin usage cao hơn
```

### Nếu Muốn Tiết Kiệm Pin Hơn (5 phút)
```dart
// email_monitor_service.dart
static const int _checkIntervalSeconds = 300; // 5 PHÚT

// Trade-off: Notification chậm hơn
```

### Nếu Không Cần Foreground (Chỉ Background)
```dart
// home_screen.dart
// Comment out foreground monitoring
// await _emailMonitorService.startMonitoring();

// Chỉ dùng background (15 min)
await BackgroundEmailService.registerPeriodicTask();
```

---

## 💡 RECOMMENDATIONS

### Cho User Thường:
```
✅ Foreground: 2 phút
✅ Background: 15 phút
→ Cân bằng tốt nhất
```

### Cho User Cần Real-time:
```
✅ Foreground: 1 phút
✅ Background: 15 phút
→ Nhanh hơn nhưng tốn pin hơn
```

### Cho User Tiết Kiệm Pin:
```
✅ Foreground: 5 phút (hoặc tắt)
✅ Background: 15 phút
→ Tiết kiệm pin nhưng chậm hơn
```

---

## 🚀 ADVANCED: Real-time Push

Nếu cần **THẬT SỰ REAL-TIME** (notification ngay lập tức):

### Option 1: Gmail Push Notifications
```
Gmail → Cloud Pub/Sub → Cloud Function → FCM → App
```
**Pros:** Real-time instant
**Cons:** Phức tạp, cần Google Cloud setup

### Option 2: Firebase Cloud Messaging
```
Server monitor Gmail → FCM → App
```
**Pros:** Fast, reliable
**Cons:** Cần backend server

### Option 3: Giảm Interval Xuống Tối Thiểu
```
Foreground: 30 giây
Background: 15 phút (minimum Android)
```
**Pros:** Đơn giản, không cần backend
**Cons:** Pin usage cao hơn

---

## 📝 FILES ĐÃ SỬA

```
✅ lib/services/email_monitor_service.dart
   - Interval: 10s → 120s (2 phút)

✅ lib/services/background_email_service.dart
   - Frequency: 30 min → 15 min

✅ lib/screens/home_screen.dart
   - Bật lại foreground monitoring
   - Stop monitoring trong dispose()
   - Update logs
```

---

## ✅ CHECKLIST VERIFICATION

Sau khi build, verify:
- [ ] Mở app → thấy logs monitoring started
- [ ] Mỗi 2 phút → thấy "Checking for new emails"
- [ ] Send email test → nhận notification trong 2 phút
- [ ] Đóng app → background check vẫn chạy (15 min)
- [ ] Pin usage hợp lý (check Settings → Battery)
- [ ] Không spam notifications

---

## 🎉 SUMMARY

**Giải pháp cuối cùng:**
1. ✅ Foreground: 2 phút (khi app mở)
2. ✅ Background: 15 phút (khi app đóng)
3. ✅ Force check: 1 lần khi mở app
4. ✅ Manual check: Bất kỳ lúc nào

**Kết quả:**
- ✅ Nhận notification trong 2-15 phút
- ✅ Pin usage giảm 92% so với 10s
- ✅ Không spam notifications
- ✅ Cân bằng giữa real-time và performance

**Perfect balance! 🎯**
