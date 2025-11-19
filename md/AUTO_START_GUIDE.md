# Hướng Dẫn Auto-Start Email Monitoring

## 🚀 Tính Năng Tự Động

App WardMail giờ đã **TỰ ĐỘNG** monitor và phân tích email mà **KHÔNG CẦN** bạn phải làm gì!

### ✅ Đã Cài Đặt Sẵn

1. **Auto-start khi login**
   - Ngay khi bạn đăng nhập vào app
   - Background service tự động bật
   - Không hiển thị thông báo (chạy ngầm)

2. **Auto-start sau khi reboot**
   - Khi khởi động lại điện thoại
   - App tự động kiểm tra và restart background service
   - Đảm bảo monitoring luôn hoạt động

3. **Monitoring liên tục**
   - **Foreground** (app mở): Check mỗi 10 giây
   - **Background** (app đóng): Check mỗi 15 phút
   - Phân tích AI tự động
   - Gửi notification khi có email mới

---

## 🔧 Cách Hoạt Động

### Flow Tự Động:

```
📱 Mở App / Reboot Device
    ↓
✅ Auto-start service
    ↓
🔄 Monitor emails liên tục
    ↓
📧 Phát hiện email mới
    ↓
🤖 Phân tích AI tự động
    ↓
💾 Lưu kết quả vào database
    ↓
🔔 Gửi notification
    ↓
👆 Tap notification → Mở email detail
```

### Không Cần Làm Gì:
- ❌ Không cần ấn "Check Email Ngay"
- ❌ Không cần ấn "Test Thông Báo"
- ❌ Không cần bật bất kỳ setting nào
- ✅ Chỉ cần login và để app chạy!

---

## 📊 Thống Kê Monitoring

### Foreground (App Đang Mở)
- **Tần suất:** Mỗi 10 giây
- **Phương thức:** EmailMonitorService
- **Ưu điểm:** Realtime, phản hồi nhanh
- **Nhược điểm:** Tốn pin khi app mở

### Background (App Đóng/Minimize)
- **Tần suất:** Mỗi 15 phút
- **Phương thức:** WorkManager
- **Ưu điểm:** Tiết kiệm pin, chạy ổn định
- **Nhược điểm:** Không realtime (do Android limit)

---

## 🔋 Tối Ưu Pin

### Auto-start đã được tối ưu:
1. ✅ Sử dụng WorkManager (tiết kiệm pin)
2. ✅ Chỉ chạy khi có internet
3. ✅ Không chạy khi pin yếu (có thể config)
4. ✅ Batch processing (xử lý nhiều email cùng lúc)

### Để tiết kiệm pin tối đa:
```dart
// Trong BackgroundEmailService.registerPeriodicTask()
constraints: Constraints(
  networkType: NetworkType.connected,      // Chỉ chạy khi có mạng
  requiresBatteryNotLow: true,             // ✅ Không chạy khi pin yếu
  requiresCharging: false,                  // Chạy kể cả không sạc
),
```

---

## 🛠️ Quản Lý Auto-Start (Tùy Chọn)

Nếu bạn muốn **tắt** auto-start (ví dụ: để test), có thể dùng:

### Trong Code:
```dart
// Tắt auto-start
await AutoStartService.disableAutoStart();

// Bật lại auto-start
await AutoStartService.enableAutoStart();

// Kiểm tra trạng thái
bool isEnabled = await AutoStartService.isAutoStartEnabled();

// Force restart
await AutoStartService.startBackgroundService();
```

### Thêm UI Toggle (Optional):
Có thể thêm switch trong Settings để user bật/tắt:

```dart
// Trong HomeScreen settings
SwitchListTile(
  title: Text('Tự động monitor email'),
  subtitle: Text('Bật để app tự động phân tích email mới'),
  value: _autoStartEnabled,
  onChanged: (value) async {
    if (value) {
      await AutoStartService.enableAutoStart();
      await AutoStartService.startBackgroundService();
    } else {
      await AutoStartService.disableAutoStart();
    }
    setState(() => _autoStartEnabled = value);
  },
);
```

---

## 🐛 Troubleshooting

### App không tự động monitor sau khi reboot
**Kiểm tra:**
1. AndroidManifest.xml có permission `RECEIVE_BOOT_COMPLETED` chưa? ✅
2. App có bị Battery Optimization chặn không?
   - Vào Settings → Apps → WardMail → Battery → "Unrestricted"
3. WorkManager có đang hoạt động không?
   - Check logs: `adb logcat | grep WorkManager`

### Notification không hiện khi app đóng
**Nguyên nhân:** WorkManager chỉ chạy mỗi 15 phút (Android limitation)

**Giải pháp:**
1. Đợi 15 phút để WorkManager chạy lần tiếp theo
2. Hoặc dùng "Check Email Ngay" để force check ngay lập tức
3. Hoặc giữ app mở để dùng foreground monitoring (10s)

### App bị kill bởi hệ thống
**Một số máy Android aggressive kill apps:**
- Xiaomi (MIUI)
- Huawei (EMUI)
- Oppo/Realme (ColorOS)

**Giải pháp:**
1. Vào Settings → Apps → WardMail
2. Bật "Autostart"
3. Bật "Run in background"
4. Tắt "Battery optimization"

---

## 📱 Permissions Cần Thiết

### Đã có trong AndroidManifest.xml:
```xml
✅ RECEIVE_BOOT_COMPLETED    - Auto-start sau reboot
✅ WAKE_LOCK                 - Giữ CPU khi background task chạy
✅ INTERNET                  - Fetch emails
✅ POST_NOTIFICATIONS        - Hiển thị thông báo
✅ FOREGROUND_SERVICE        - Chạy foreground service
```

---

## 🎯 Best Practices

### Để App Hoạt Động Tốt Nhất:

1. **Đăng nhập ít nhất 1 lần**
   - Auto-start chỉ hoạt động sau khi user login
   - Gmail credentials cần được lưu

2. **Cho phép Background Activity**
   - Settings → Apps → WardMail → Battery → Unrestricted

3. **Không Force Stop App**
   - Force stop sẽ kill tất cả background tasks
   - App sẽ tự restart khi bạn mở lại

4. **Kiểm tra định kỳ**
   - Vào Notification Screen để xem lịch sử
   - Kiểm tra logs nếu có vấn đề

---

## 🔮 Cải Tiến Tiếp Theo

### Đã có:
- ✅ Auto-start on login
- ✅ Auto-restart on reboot
- ✅ Background monitoring with WorkManager
- ✅ Foreground monitoring
- ✅ AI analysis tự động
- ✅ Lưu kết quả vào database
- ✅ Navigation từ notification

### Có thể thêm:
- [ ] Foreground Service (notification always visible)
- [ ] Gmail Push API (realtime thay vì polling)
- [ ] Configurable monitoring interval
- [ ] Smart monitoring (học lịch sử nhận email)
- [ ] Battery usage optimization
- [ ] User toggle để bật/tắt auto-start

---

## 📚 Technical Details

### AutoStartService
```dart
class AutoStartService {
  // Kiểm tra và restart nếu cần
  static Future<void> checkAndRestart() async {
    final enabled = await isAutoStartEnabled();
    
    if (enabled) {
      final lastStart = await getLastStartTime();
      
      // Nếu đã >24h, restart
      if (lastStart == null || 
          DateTime.now().difference(lastStart).inHours > 24) {
        await startBackgroundService();
      }
    }
  }
}
```

### Gọi trong main():
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().initialize();
  await BackgroundEmailService.initialize();
  
  // ✅ Auto-check và restart
  await AutoStartService.checkAndRestart();
  
  runApp(const MyApp());
}
```

### Gọi trong HomeScreen.initState():
```dart
@override
void initState() {
  super.initState();
  _loadUserData();
  _loadNotificationCount();
  _startEmailMonitoring();  // ✅ Tự động start, không hiện snackbar
}
```

---

## ✅ Summary

**Điều bạn cần biết:**
1. ✅ App tự động monitor email khi login
2. ✅ Không cần ấn bất kỳ nút nào
3. ✅ Chạy ngầm hoàn toàn
4. ✅ Tự động restart sau reboot
5. ✅ Notification khi có email mới
6. ✅ Tap notification → mở email detail

**Bạn chỉ cần:**
- Đăng nhập
- Để app chạy
- Nhận notification!

🎉 Hoàn toàn tự động, không cần làm gì thêm!
