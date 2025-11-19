# Fix: setState() Called After dispose()

## ❌ Vấn Đề

**Lỗi:**
```
FlutterError (setState() called after dispose(): 
_HomeScreenState#b968e(lifecycle state: defunct, not mounted)
```

**Nguyên nhân:**
1. `Future.delayed()` trong initState() vẫn chạy sau khi dispose
2. Async operations (fetch emails) hoàn thành sau khi widget đã dispose
3. setState() được gọi trên widget không còn trong tree

---

## ✅ Giải Pháp

### 1. **Thêm `_isDisposed` Flag**
```dart
bool _isDisposed = false;

@override
void dispose() {
  _isDisposed = true;  // ✅ Mark as disposed
  _emailMonitorService.stopMonitoring();
  super.dispose();
}
```

### 2. **Double Check: `mounted && !_isDisposed`**
Trước EVERY setState():
```dart
if (mounted && !_isDisposed) {
  setState(() {
    // ... safe to update state
  });
}
```

### 3. **Check Trong Future.delayed()**
```dart
Future.delayed(const Duration(seconds: 5), () {
  if (mounted && !_isDisposed) {  // ✅ Double check
    _checkEmailsNow();
  } else {
    print('⚠️ HomeScreen disposed before force check');
  }
});
```

### 4. **Check Sau Async Operations**
```dart
try {
  final result = await someAsyncOperation();
  
  // ✅ Always check after await
  if (mounted && !_isDisposed) {
    setState(() {
      _data = result;
    });
  }
} catch (e) {
  // ✅ Check in error handling too
  if (mounted && !_isDisposed) {
    ScaffoldMessenger.of(context).showSnackBar(...);
  }
}
```

---

## 📋 Checklist: Đã Sửa

### HomeScreen (_home_screen.dart):
- [x] Thêm `_isDisposed` flag
- [x] dispose() → set `_isDisposed = true`
- [x] dispose() → stop EmailMonitorService
- [x] _loadUserData() → check before setState
- [x] _loadNotificationCount() → check before setState
- [x] _checkEmailsNow() → check ở đầu function
- [x] _checkEmailsNow() → check trước mọi setState
- [x] _checkEmailsNow() → check trong try/catch/finally
- [x] _toggleBiometric() → check before setState
- [x] Future.delayed() → double check

---

## 🔍 Pattern: Safe setState()

### Pattern 1: Đầu Function
```dart
Future<void> myFunction() async {
  // ✅ Check ngay đầu
  if (!mounted || _isDisposed) return;
  
  // ... rest of code
}
```

### Pattern 2: Trước setState()
```dart
if (mounted && !_isDisposed) {
  setState(() {
    // update state
  });
}
```

### Pattern 3: Sau Async
```dart
final data = await fetchData();

// ✅ Always check after await
if (!mounted || _isDisposed) return;

setState(() {
  _data = data;
});
```

### Pattern 4: Trong Callbacks
```dart
Future.delayed(duration, () {
  // ✅ Check trong callback
  if (mounted && !_isDisposed) {
    doSomething();
  }
});
```

---

## 🎯 Khi Nào Cần Check?

### ✅ PHẢI Check:
1. **Trước mọi setState()**
2. **Sau mọi await** (async operations)
3. **Trong callbacks** (Future.delayed, Timer, listeners)
4. **Trong try/catch/finally**
5. **Trước ScaffoldMessenger.of(context)**
6. **Trước Navigator operations**

### ⚠️ Không Cần Check:
1. Trong synchronous code (không có await)
2. Trong initState() (trước async operations)
3. Trong build() method

---

## 🐛 Debug Tips

### Xem Widget Lifecycle:
```dart
@override
void initState() {
  print('🟢 HomeScreen initState');
  super.initState();
}

@override
void dispose() {
  print('🔴 HomeScreen disposing');
  _isDisposed = true;
  super.dispose();
  print('🔴 HomeScreen disposed');
}
```

### Log Tất Cả setState:
```dart
void safeSetState(VoidCallback fn) {
  if (mounted && !_isDisposed) {
    print('✅ Safe setState called');
    setState(fn);
  } else {
    print('⚠️ Prevented setState after dispose');
  }
}

// Usage:
safeSetState(() {
  _data = newData;
});
```

---

## 🚫 Common Mistakes

### ❌ Mistake 1: Chỉ Check `mounted`
```dart
// ❌ WRONG
if (mounted) {
  setState(() => _data = data);
}
```

**Vấn đề:** `mounted` có thể vẫn `true` ngay sau dispose()

**✅ CORRECT:**
```dart
if (mounted && !_isDisposed) {
  setState(() => _data = data);
}
```

### ❌ Mistake 2: Không Check Sau Await
```dart
// ❌ WRONG
Future<void> loadData() async {
  final data = await fetchData();
  setState(() => _data = data);  // Widget có thể đã dispose!
}
```

**✅ CORRECT:**
```dart
Future<void> loadData() async {
  final data = await fetchData();
  
  if (!mounted || _isDisposed) return;  // ✅ Check sau await
  
  setState(() => _data = data);
}
```

### ❌ Mistake 3: Quên Cancel Timers
```dart
// ❌ WRONG
@override
void dispose() {
  super.dispose();
  // Timer vẫn chạy!
}
```

**✅ CORRECT:**
```dart
@override
void dispose() {
  _timer?.cancel();           // ✅ Cancel timer
  _subscription?.cancel();    // ✅ Cancel stream
  _controller.dispose();      // ✅ Dispose controllers
  _service.stopMonitoring();  // ✅ Stop services
  
  _isDisposed = true;
  super.dispose();
}
```

---

## 📊 Workflow: Safe Async Operations

```dart
class MyWidgetState extends State<MyWidget> {
  bool _isDisposed = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();  // Start async operation
  }
  
  Future<void> _loadData() async {
    // 1. ✅ Check at start
    if (!mounted || _isDisposed) return;
    
    try {
      // 2. Async operation
      final data = await fetchData();
      
      // 3. ✅ Check after await
      if (!mounted || _isDisposed) return;
      
      // 4. Safe setState
      setState(() {
        _data = data;
      });
      
      // 5. ✅ Check before showing snackbar
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data loaded')),
        );
      }
    } catch (e) {
      // 6. ✅ Check in error handling
      if (mounted && !_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      // 7. ✅ Check in finally
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  void dispose() {
    print('Disposing...');
    _isDisposed = true;
    super.dispose();
  }
}
```

---

## ✅ Result

**Sau khi fix:**
- ✅ Không còn lỗi "setState() called after dispose()"
- ✅ Memory leaks được tránh
- ✅ App stable hơn
- ✅ Không crash khi navigate nhanh

**Test:**
1. Mở HomeScreen
2. Navigate đi ngay (trước 5s)
3. ✅ Không có lỗi
4. Logs: "⚠️ HomeScreen disposed before force check"

---

## 📝 Files Đã Sửa

```
✅ lib/screens/home_screen.dart
   - Thêm _isDisposed flag
   - dispose() stop services
   - Check mounted && !_isDisposed ở mọi setState
   - Check trong Future.delayed
   - Check sau async operations

✅ DISPOSE_FIX.md (này)
   - Documentation về dispose pattern
```

---

## 🎓 Best Practices

### 1. Always Use Both Checks
```dart
if (mounted && !_isDisposed) {
  // Safe to use context and setState
}
```

### 2. Check After Every Await
```dart
await someOperation();
if (!mounted || _isDisposed) return;
```

### 3. Early Return
```dart
Future<void> myFunction() async {
  if (!mounted || _isDisposed) return;  // ✅ Early return
  
  // ... rest of code
}
```

### 4. Log For Debugging
```dart
if (!mounted || _isDisposed) {
  print('⚠️ Widget disposed, skipping operation');
  return;
}
```

### 5. Clean Up In Dispose
```dart
@override
void dispose() {
  // Cancel everything
  _timer?.cancel();
  _subscription?.cancel();
  _controller.dispose();
  _service.stop();
  
  // Mark as disposed
  _isDisposed = true;
  
  super.dispose();
}
```

---

🎉 **Done! Lỗi dispose đã được fix hoàn toàn!**
