# Prompt Template cho Gemini AI - Phân tích Email Phishing

## Cấu trúc Prompt

Bạn là một chuyên gia bảo mật email và an ninh mạng. Nhiệm vụ của bạn là phân tích nội dung email dưới đây để đánh giá nguy cơ lừa đảo (phishing).

**LƯU Ý QUAN TRỌNG:** Email này đã được làm mờ các thông tin cá nhân (tên, số điện thoại, địa chỉ, v.v.) để bảo vệ quyền riêng tư. Hãy tập trung vào cấu trúc, ngôn ngữ, kỹ thuật lừa đảo và ngữ cảnh chung.

**HÃY PHÂN TÍCH EMAIL SAU:**

---
{Đặt toàn bộ nội dung email ĐÃ ĐƯỢC LÀM MỜ vào đây}
---

**ĐỊNH DẠNG ĐẦU RA BẮT BUỘC (JSON):**
```json
{
  "risk_score": 0-100,
  "risk_level": "Low" | "Medium" | "High" | "Critical",
  "summary": "Tóm tắt ngắn gọn về mức độ đe dọa và các kỹ thuật lừa đảo chính được sử dụng.",
  "detailed_analysis": {
    "sender_analysis": "Phân tích người gửi và sự đáng tin cậy.",
    "content_analysis": "Phân tích ngôn ngữ, giọng điệu, và các yếu tố xã hội được sử dụng.",
    "technical_analysis": "Phân tích các liên kết, đính kèm (nếu có) và kỹ thuật lừa đảo.",
    "context_analysis": "Phân tích câu chuyện hoặc tình huống mà email tạo ra. Đây là phần quan trọng vì bạn có toàn bộ ngữ cảnh."
  },
  "red_flags": [
    "Danh sách các dấu hiệu cảnh báo"
  ],
  "recommendations": [
    "Khuyến nghị hành động"
  ]
}
```

## Hướng dẫn sử dụng

### 1. Trong code (gemini_analysis_service.dart)

```dart
String _buildPrompt(String emailContent) {
  return '''
Bạn là một chuyên gia bảo mật email và an ninh mạng. Nhiệm vụ của bạn là phân tích nội dung email dưới đây để đánh giá nguy cơ lừa đảo (phishing).

**LƯU Ý QUAN TRỌNG:** Email này đã được làm mờ các thông tin cá nhân (tên, số điện thoại, địa chỉ, v.v.) để bảo vệ quyền riêng tư. Hãy tập trung vào cấu trúc, ngôn ngữ, kỹ thuật lừa đảo và ngữ cảnh chung.

**HÃY PHÂN TÍCH EMAIL SAU:**

---
$emailContent
---

**ĐỊNH DẠNG ĐẦU RA BẮT BUỘC (JSON):**
{
  "risk_score": 0-100,
  "risk_level": "Low" | "Medium" | "High" | "Critical",
  "summary": "Tóm tắt ngắn gọn về mức độ đe dọa và các kỹ thuật lừa đảo chính được sử dụng.",
  "detailed_analysis": {
    "sender_analysis": "Phân tích người gửi và sự đáng tin cậy.",
    "content_analysis": "Phân tích ngôn ngữ, giọng điệu, và các yếu tố xã hội được sử dụng.",
    "technical_analysis": "Phân tích các liên kết, đính kèm (nếu có) và kỹ thuật lừa đảo.",
    "context_analysis": "Phân tích câu chuyện hoặc tình huống mà email tạo ra."
  },
  "red_flags": [
    // Danh sách các dấu hiệu cảnh báo
  ],
  "recommendations": [
    // Khuyến nghị hành động
  ]
}
''';
}
```

### 2. Các tiêu chí phân tích

#### Risk Score (0-100):
- **0-25**: Low Risk - Email an toàn
- **26-50**: Medium Risk - Có một số dấu hiệu đáng ngờ
- **51-75**: High Risk - Nhiều dấu hiệu phishing
- **76-100**: Critical Risk - Rõ ràng là phishing

#### Detailed Analysis:
1. **sender_analysis**: Kiểm tra độ tin cậy của người gửi
2. **content_analysis**: Đánh giá nội dung, ngôn ngữ, cảm xúc
3. **technical_analysis**: Kiểm tra link, kỹ thuật lừa đảo
4. **context_analysis**: Phân tích ngữ cảnh tổng thể

#### Red Flags: Các dấu hiệu cảnh báo phổ biến
- Domain giả mạo
- Yêu cầu thông tin nhạy cảm
- Tạo cảm giác khẩn cấp
- Lỗi chính tả/ngữ pháp
- Link nghi ngờ

### 3. Ví dụ Response từ Gemini

#### Email An toàn:
```json
{
  "risk_score": 15,
  "risk_level": "Low",
  "summary": "Email từ nguồn hợp pháp, không có dấu hiệu lừa đảo rõ ràng.",
  "detailed_analysis": {
    "sender_analysis": "Domain chính thức, địa chỉ email khớp với tổ chức.",
    "content_analysis": "Nội dung chuyên nghiệp, không có yêu cầu nhạy cảm.",
    "technical_analysis": "Không có link đáng ngờ hoặc đính kèm độc hại.",
    "context_analysis": "Email thông báo thông thường, không tạo áp lực."
  },
  "red_flags": [],
  "recommendations": [
    "Email có vẻ an toàn",
    "Vẫn nên kiểm tra kỹ trước khi click link"
  ]
}
```

#### Email Phishing:
```json
{
  "risk_score": 85,
  "risk_level": "Critical",
  "summary": "Email lừa đảo sử dụng kỹ thuật giả mạo ngân hàng, yêu cầu xác minh tài khoản khẩn cấp.",
  "detailed_analysis": {
    "sender_analysis": "Domain không khớp với ngân hàng chính thức, có dấu hiệu typosquatting.",
    "content_analysis": "Tạo cảm giác khẩn cấp với đe dọa khóa tài khoản, ngôn ngữ không chuyên nghiệp.",
    "technical_analysis": "Link redirect đến trang web giả mạo, URL không phải domain chính thức.",
    "context_analysis": "Email tạo áp lực buộc người dùng hành động nhanh mà không suy nghĩ."
  },
  "red_flags": [
    "Domain giả mạo ngân hàng",
    "Yêu cầu thông tin đăng nhập",
    "Đe dọa khóa tài khoản",
    "Link đến website không chính thức",
    "Lỗi chính tả và ngữ pháp"
  ],
  "recommendations": [
    "KHÔNG click vào bất kỳ link nào trong email",
    "KHÔNG cung cấp thông tin cá nhân hoặc tài khoản",
    "Xóa email ngay lập tức",
    "Liên hệ trực tiếp với ngân hàng qua kênh chính thức",
    "Báo cáo email này cho nhà cung cấp dịch vụ"
  ]
}
```

## Lưu ý khi implement

### 1. Xử lý Response
```dart
Future<Map<String, dynamic>> _parseGeminiResponse(String response) async {
  try {
    // Remove markdown code blocks if present
    String cleanedResponse = response
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    
    return json.decode(cleanedResponse);
  } catch (e) {
    print('Error parsing Gemini response: $e');
    return {};
  }
}
```

### 2. Fallback khi Gemini lỗi
```dart
if (geminiResult == null || geminiResult.isEmpty) {
  // Sử dụng phương pháp heuristic
  return _fallbackAnalysis(emailData);
}
```

### 3. Làm mờ dữ liệu trước khi gửi
```dart
String anonymizedContent = await _anonymizationService.anonymizeEmail(emailContent);
String prompt = _buildPrompt(anonymizedContent);
```

## Best Practices

1. **Luôn làm mờ dữ liệu cá nhân** trước khi gửi lên Gemini
2. **Validate JSON response** từ Gemini trước khi sử dụng
3. **Có fallback mechanism** khi Gemini không available
4. **Cache results** để giảm số lượng API calls
5. **Monitor API usage** để tránh vượt quota
6. **Log errors** để debug khi có vấn đề

## Testing

### Test với email mẫu:
1. Email an toàn (newsletter, thông báo chính thức)
2. Email spam đơn giản
3. Email phishing tinh vi (giả mạo ngân hàng)
4. Email phishing có kỹ thuật social engineering

### Kiểm tra:
- Risk score có chính xác không?
- Red flags có đầy đủ không?
- Recommendations có hữu ích không?
- Response time có chấp nhận được không?
