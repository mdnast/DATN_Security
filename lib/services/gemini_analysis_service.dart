import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'locale_service.dart';

class GeminiAnalysisService {
  // API Key - NÊN LƯU TRONG .env HOẶC SECURE STORAGE
  // Tạm thời hardcode để test, sau này cần di chuyển ra ngoài
  static const String _apiKey = 'AIzaSyBcFkPZWI0npRvYiQ55tZHSG_cm79Vv_5A';
  // API key dành riêng cho chatbot (hỏi đáp), nên thay bằng key mới của bạn
  static const String _chatApiKey = 'AIzaSyAgvmioOQ87JgTFgIftoFAwF5T02v5_NkE';

  // Danh sách models để fallback nếu model chính lỗi
  static const List<String> _availableModels = [
    'gemini-2.5-flash', // Model mới nhất, nhanh nhất (stable 2025)
    'gemini-2.0-flash-001', // Model fallback cũ hơn
    'gemini-1.5-flash', // Model cũ nhất
  ];

  late GenerativeModel _model;
  String _currentModel = _availableModels[0];

  GeminiAnalysisService() {
    _model = GenerativeModel(model: _currentModel, apiKey: _apiKey);
  }

  /// Trợ lý Gmail chung: trả lời câu hỏi về cách dùng Gmail, bảo mật, spam...
  Future<String> askGeneralGmailQuestion(String question) async {
    final locale = LocaleService().locale.value ?? const Locale('vi');
    final isEnglish = locale.languageCode == 'en';
    int maxRetries = _availableModels.length;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        final chatModel = GenerativeModel(
          model: _currentModel,
          apiKey: _chatApiKey.isNotEmpty ? _chatApiKey : _apiKey,
        );

        final prompt = isEnglish
            ? '''
You are an assistant specialized in Gmail.

Your tasks:
- Explain how to use Gmail, manage the inbox, filter spam, report phishing, and secure the account.
- Provide step-by-step, easy-to-understand guidance suitable for normal users.
- You may explain how to recognize phishing emails IN GENERAL, but you do not need specific email content.
- NEVER ask the user for passwords, verification codes, OTPs, security codes, login links, or card/account information.

User question:
"""
$question
"""

Answer in clear, concise English and focus on practical guidance.
'''
            : '''
Bạn là trợ lý chuyên về Gmail.

Nhiệm vụ của bạn:
- Giải thích cách sử dụng Gmail, quản lý hộp thư, lọc spam, báo cáo phishing, bảo mật tài khoản.
- Đưa ra hướng dẫn từng bước, dễ hiểu, phù hợp người dùng bình thường.
- Có thể giải thích cách nhận diện email lừa đảo NÓI CHUNG, nhưng không cần nội dung email cụ thể.
- KHÔNG bao giờ yêu cầu người dùng cung cấp mật khẩu, mã xác minh, OTP, mã bảo mật, link đăng nhập, hoặc thông tin thẻ/tài khoản.

Câu hỏi của người dùng:
"""
$question
"""

Trả lời bằng tiếng Việt, rõ ràng, gọn gàng, tập trung vào hướng dẫn thực tế.
''';

        final response = await chatModel.generateContent([
          Content.text(prompt),
        ]);
        final text = response.text?.trim();

        if (text == null || text.isEmpty) {
          throw Exception('Không nhận được phản hồi từ Gemini AI');
        }

        return text;
      } catch (e) {
        if (attempt < maxRetries - 1) {
          _switchToFallbackModel();
          attempt++;
          continue;
        } else {
          throw Exception('Lỗi khi hỏi trợ lý Gmail: $e');
        }
      }
    }

    throw Exception('Unexpected error in askGeneralGmailQuestion');
  }

  Future<String> askQuestionAboutEmail({
    required String subject,
    required String body,
    required String from,
    required String question,
  }) async {
    final locale = LocaleService().locale.value ?? const Locale('vi');
    final isEnglish = locale.languageCode == 'en';
    int maxRetries = _availableModels.length;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        final chatModel = GenerativeModel(
          model: _currentModel,
          apiKey: _chatApiKey.isNotEmpty ? _chatApiKey : _apiKey,
        );

        final prompt = isEnglish
            ? '''
You are an email security assistant.

FROM: $from
SUBJECT: $subject
BODY:
$body

User question about this email:
"$question"

Answer in clear and concise English, prioritizing analysis of links/URLs in the email:
- Assess how safe/dangerous the email is, especially based on the sender domain and any URLs in the content.
- Point out specific URLs or domains that look suspicious (if any) and why.
- Provide 1–3 concrete steps the user should take (for example: do not click links, verify the domain, report spam, etc.).
If the information is not sufficient to conclude, say that clearly.
'''
            : '''
Bạn là trợ lý an toàn email.

FROM: $from
SUBJECT: $subject
BODY:
$body

Câu hỏi của người dùng về email này:
"$question"

Trả lời bằng tiếng Việt, rõ ràng và ngắn gọn, ưu tiên phân tích các đường link/URL trong email:
- Đánh giá mức độ an toàn/nguy hiểm của email, đặc biệt dựa trên domain người gửi và các URL trong nội dung.
- Chỉ ra cụ thể URL hoặc domain nào đáng ngờ (nếu có) và lý do.
- Đưa ra 1-3 bước cụ thể người dùng nên làm (ví dụ: không bấm link, kiểm tra domain, báo cáo spam...).
Nếu thông tin chưa đủ để kết luận, hãy nói rõ điều đó.
''';

        final response = await chatModel.generateContent([
          Content.text(prompt),
        ]);
        final text = response.text?.trim();

        if (text == null || text.isEmpty) {
          throw Exception('Không nhận được phản hồi từ Gemini AI');
        }

        return text;
      } catch (e) {
        if (attempt < maxRetries - 1) {
          _switchToFallbackModel();
          attempt++;
          continue;
        } else {
          throw Exception('Lỗi khi hỏi Gemini về email: $e');
        }
      }
    }

    throw Exception('Unexpected error in askQuestionAboutEmail');
  }

  /// Thử đổi sang model khác nếu model hiện tại lỗi
  void _switchToFallbackModel() {
    final currentIndex = _availableModels.indexOf(_currentModel);
    if (currentIndex < _availableModels.length - 1) {
      _currentModel = _availableModels[currentIndex + 1];
      _model = GenerativeModel(model: _currentModel, apiKey: _apiKey);
      print('Switched to fallback model: $_currentModel');
    } else {
      throw Exception('Đã thử tất cả models nhưng đều lỗi');
    }
  }

  /// Gửi email lên Gemini để phân tích phishing
  Future<GeminiAnalysisResult> analyzeEmail({
    required String subject,
    required String body,
    required String from,
    String? userFeedback,
  }) async {
    int maxRetries = _availableModels.length; // Thử tất cả models
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        print('=== GEMINI ANALYSIS START (Model: $_currentModel) ===');
        print('Attempt: ${attempt + 1}/$maxRetries');
        print(
          'Subject: ${subject.substring(0, subject.length > 50 ? 50 : subject.length)}...',
        );
        if (userFeedback != null && userFeedback.isNotEmpty) {
          print('User Feedback included: $userFeedback');
        }

        final prompt = _buildAnalysisPrompt(
          subject: subject,
          body: body,
          from: from,
          userFeedback: userFeedback,
        );

        print('=== DEBUG: GENERATED PROMPT ===');
        print(prompt);
        print('===============================');

        print('Sending request to Gemini...');
        final response = await _model.generateContent([Content.text(prompt)]);

        print('Response received!');
        print('Response text length: ${response.text?.length ?? 0}');

        if (response.text == null || response.text!.isEmpty) {
          print('ERROR: Empty response from Gemini');
          throw Exception('Không nhận được phản hồi từ Gemini AI');
        }

        print('Parsing response...');
        final result = _parseGeminiResponse(response.text!);

        // Nếu kết quả có classification unknown, có thể do lỗi parse - thử lại với prompt đơn giản hơn
        if (result.classification == 'unknown' && result.confidence < 50) {
          print(
            'First attempt resulted in unknown classification, retrying with simpler prompt...',
          );
          return await _retryWithSimplePrompt(
            subject: subject,
            body: body,
            from: from,
          );
        }

        print('=== ANALYSIS SUCCESS ===');
        return result;
      } catch (e) {
        print('=== GEMINI ERROR (Attempt ${attempt + 1}) ===');
        print('Current Model: $_currentModel');
        print('Error: $e');

        // Nếu còn model để thử, switch sang model khác
        if (attempt < maxRetries - 1) {
          try {
            _switchToFallbackModel();
            print('Retrying with fallback model: $_currentModel');
            attempt++;
            continue;
          } catch (switchError) {
            // Hết models để thử
            throw Exception('Đã thử tất cả models nhưng đều lỗi: $e');
          }
        } else {
          // Đã thử hết, throw error cuối cùng
          throw Exception('Lỗi khi phân tích với Gemini: $e');
        }
      }
    }

    // Không bao giờ tới đây, nhưng Dart yêu cầu return
    throw Exception('Unexpected error in analyzeEmail');
  }

  /// Thử lại với prompt đơn giản hơn, chỉ yêu cầu thông tin cơ bản
  Future<GeminiAnalysisResult> _retryWithSimplePrompt({
    required String subject,
    required String body,
    required String from,
  }) async {
    final simplePrompt =
        '''
Chỉ trả về MỘT JSON hợp lệ, không markdown, không text khác.

FROM:$from
SUBJECT:$subject
BODY:$body

JSON:
{
  "risk_score": 50,
  "risk_level": "Medium",
  "summary": "tóm tắt",
  "red_flags": [],
  "recommendations": []
}

Quy tắc:
- risk_score 0-100
- Không dùng dấu " trong string, nếu cần thì dùng '.
- Không xuống dòng trong string.
''';

    print('Sending simplified request...');
    final response = await _model.generateContent([Content.text(simplePrompt)]);

    if (response.text == null || response.text!.isEmpty) {
      throw Exception('Không nhận được phản hồi từ Gemini khi retry');
    }

    return _parseGeminiResponse(response.text!);
  }

  String _buildAnalysisPrompt({
    required String subject,
    required String body,
    required String from,
    String? userFeedback,
  }) {
    final locale = LocaleService().locale.value ?? const Locale('vi');
    final isEnglish = locale.languageCode == 'en';

    // Feedback section - Relaxed constraints, no "valid reason" required
    final feedbackSection = (userFeedback != null && userFeedback.isNotEmpty)
        ? (isEnglish
              ? '\n*** CRITICAL INSTRUCTION OVERRIDE ***\n'
                    'USER FEEDBACK: "$userFeedback"\n'
                    'INSTRUCTION: The user has explicitly reviewed this email. '
                    'You MUST trust the user\'s judgment for this re-analysis. '
                    'If the user says it is SAFE/NORMAL, set risk_score = 0 and risk_level = "Low". '
                    'If the user says it is DANGEROUS/PHISHING, set risk_score = 100 and risk_level = "Critical". '
                    'Ignore previous indicators if they contradict the user\'s explicit feedback.\n'
              : '\n*** CHỈ DẪN ƯU TIÊN CAO NHẤT ***\n'
                    'PHẢN HỒI CỦA NGƯỜI DÙNG: "$userFeedback"\n'
                    'CHỈ DẪN: Người dùng đã trực tiếp xem xét email này. '
                    'Bạn PHẢI tin tưởng đánh giá của người dùng trong lần phân tích lại này. '
                    'Nếu người dùng bảo là AN TOÀN/BÌNH THƯỜNG, hãy đặt risk_score = 0 và risk_level = "Low". '
                    'Nếu người dùng bảo là NGUY HIỂM/LỪA ĐẢO, hãy đặt risk_score = 100 và risk_level = "Critical". '
                    'Bỏ qua các dấu hiệu nghi ngờ trước đó nếu chúng mâu thuẫn với phản hồi của người dùng.\n')
        : '';

    return isEnglish
        ? '''
Analyze the email for phishing indicators and ONLY return ONE valid JSON object.

FROM:$from
SUBJECT:$subject
BODY:$body

$feedbackSection

Example JSON (keep the keys, change the values):
{
  "risk_score": 15,
  "risk_level": "Low",
  "summary": "short summary",
  "detailed_analysis": {
    "sender_analysis": "sender analysis",
    "content_analysis": "content analysis",
    "technical_analysis": "technical analysis",
    "context_analysis": "context analysis"
  },
  "red_flags": [],
  "recommendations": []
}

Rules:
- risk_score: number 0–100.
- risk_level: one of "Low", "Medium", "High", "Critical".
- Do not add any text outside the JSON.
'''
        : '''
Phân tích email có dấu hiệu phishing và CHỈ trả về MỘT JSON hợp lệ.

FROM:$from
SUBJECT:$subject
BODY:$body

$feedbackSection

JSON mẫu (giữ nguyên key, thay giá trị):
{
  "risk_score": 15,
  "risk_level": "Low",
  "summary": "tóm tắt ngắn gọn",
  "detailed_analysis": {
    "sender_analysis": "phân tích người gửi",
    "content_analysis": "phân tích nội dung",
    "technical_analysis": "phân tích kỹ thuật",
    "context_analysis": "phân tích bối cảnh"
  },
  "red_flags": [],
  "recommendations": []
}

Quy tắc:
- risk_score: số 0-100.
- risk_level: một trong "Low", "Medium", "High", "Critical".
- Không thêm text ngoài JSON.
''';
  }

  /// Làm sạch chuỗi JSON để tránh lỗi parsing - hỗ trợ tiếng Việt
  String _cleanJsonString(String jsonText) {
    // Loại bỏ các ký tự điều khiển không hợp lệ (trừ \n, \r, \t)
    jsonText = jsonText.replaceAll(
      RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'),
      ' ',
    );

    // Sửa các newline không hợp lệ trong JSON string values
    // Tìm tất cả cặp dấu ngoặc kép và replace newline bên trong
    jsonText = _fixNewlinesInStrings(jsonText);

    // Sửa các dấu ngoặc kép chưa escape trong string values
    jsonText = _fixUnescapedQuotes(jsonText);

    return jsonText.trim();
  }

  /// Sửa newline không hợp lệ trong JSON strings
  String _fixNewlinesInStrings(String text) {
    final buffer = StringBuffer();
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < text.length; i++) {
      final char = text[i];

      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }

      if (char == '\\') {
        buffer.write(char);
        escaped = true;
        continue;
      }

      if (char == '"') {
        inString = !inString;
        buffer.write(char);
        continue;
      }

      // Nếu đang trong string và gặp newline, thay bằng khoảng trắng
      if (inString && (char == '\n' || char == '\r')) {
        buffer.write(' ');
      } else {
        buffer.write(char);
      }
    }

    return buffer.toString();
  }

  /// Cố gắng sửa dấu ngoặc kép chưa escape trong string
  /// Chỉ xử lý các trường hợp rõ ràng để tránh phá JSON hợp lệ
  String _fixUnescapedQuotes(String text) {
    // Pattern phức tạp để detect unescaped quotes
    // Cách đơn giản: nếu có pattern ": "text "more text", sửa thành ": "text 'more text"

    // Thay thế " thành ' nếu nó xuất hiện giữa một cặp dấu ngoặc kép của value
    // Ví dụ: "content": "Nội dung tạo cảm giác "hết han" và dễ dọa"
    // Sửa thành: "content": "Nội dung tạo cảm giác 'hết han' và dễ dọa"

    final pattern = RegExp(r':\s*"([^"]*)"([^"]*)"([^"]*)"([^,}\]]*)');

    String result = text;
    int maxIterations = 10; // Giới hạn để tránh infinite loop
    int iteration = 0;

    while (pattern.hasMatch(result) && iteration < maxIterations) {
      result = result.replaceAllMapped(pattern, (match) {
        // Nếu có dấu " giữa chuỗi, convert thành '
        final part1 = match.group(1);
        final part2 = match.group(2);
        final part3 = match.group(3);
        final part4 = match.group(4);

        // Check xem có phải trường hợp cần fix không
        if (part2 != null &&
            part2.trim().isNotEmpty &&
            !part2.startsWith(',') &&
            !part2.startsWith('}') &&
            !part2.startsWith(']')) {
          // Đây có thể là unescaped quote
          return ': "$part1 $part2 $part3"$part4';
        }

        return match.group(0)!;
      });
      iteration++;
    }

    return result;
  }

  GeminiAnalysisResult _parseGeminiResponse(String responseText) {
    try {
      // Loại bỏ markdown code block nếu có
      String jsonText = responseText.trim();
      if (jsonText.startsWith('```json')) {
        jsonText = jsonText.substring(7);
      }
      if (jsonText.startsWith('```')) {
        jsonText = jsonText.substring(3);
      }
      if (jsonText.endsWith('```')) {
        jsonText = jsonText.substring(0, jsonText.length - 3);
      }
      jsonText = jsonText.trim();

      // Làm sạch JSON - xử lý các vấn đề thường gặp
      jsonText = _cleanJsonString(jsonText);

      // Log để debug
      print(
        'Gemini JSON Response: ${jsonText.substring(0, jsonText.length > 500 ? 500 : jsonText.length)}...',
      );

      final Map<String, dynamic> json = jsonDecode(jsonText);

      // Parse với format mới (risk_score, risk_level, red_flags)
      final riskScore = (json['risk_score'] ?? json['riskScore'] ?? 0)
          .toDouble();
      final riskLevel =
          json['risk_level'] ?? json['classification'] ?? 'unknown';

      // ✅ FIX: Dùng risk_score làm tiêu chí CHÍNH để phân loại
      // Không tin vào risk_level vì Gemini có thể trả về không nhất quán
      String classification = 'unknown';
      if (riskScore < 26) {
        classification = 'safe'; // 0-25: An toàn
      } else if (riskScore < 51) {
        classification = 'suspicious'; // 26-50: Nghi ngờ
      } else {
        classification = 'phishing'; // 51-100: Nguy hiểm
      }

      // Log để debug nếu có mâu thuẫn
      final expectedRiskLevel = riskScore < 26
          ? 'Low'
          : (riskScore < 51
                ? 'Medium'
                : (riskScore < 76 ? 'High' : 'Critical'));
      if (riskLevel != expectedRiskLevel) {
        print('⚠️ WARNING: Mismatch detected!');
        print('  - Gemini risk_level: $riskLevel');
        print('  - Actual risk_score: $riskScore');
        print('  - Expected risk_level: $expectedRiskLevel');
        print('  - Using risk_score-based classification: $classification');
      }

      // Parse detailed_analysis
      Map<String, String> detailedAnalysis = {};
      if (json['detailed_analysis'] != null) {
        final analysis = json['detailed_analysis'];
        detailedAnalysis = {
          'sender': analysis['sender_analysis']?.toString() ?? '',
          'content': analysis['content_analysis']?.toString() ?? '',
          'technical': analysis['technical_analysis']?.toString() ?? '',
          'context': analysis['context_analysis']?.toString() ?? '',
        };
      }

      // Parse reasons từ summary nếu có
      List<String> reasons = [];
      if (json['summary'] != null) {
        reasons.add(json['summary'].toString());
      }

      return GeminiAnalysisResult(
        riskScore: riskScore,
        classification: classification,
        confidence: 85.0, // Giá trị mặc định vì format mới không có confidence
        reasons: reasons,
        phishingIndicators: json['red_flags'] != null
            ? List<String>.from(json['red_flags'])
            : [],
        recommendations: json['recommendations'] != null
            ? List<String>.from(json['recommendations'])
            : [],
        detailedAnalysis: detailedAnalysis,
        rawResponse: responseText,
      );
    } catch (e, stackTrace) {
      // Log chi tiết để debug
      print('Error parsing Gemini response: $e');
      print('Stack trace: $stackTrace');
      print(
        'Raw response: ${responseText.substring(0, responseText.length > 1000 ? 1000 : responseText.length)}',
      );

      // Thử phân tích một phần nếu có thể
      String errorMessage = 'Lỗi phân tích JSON';
      if (e is FormatException) {
        errorMessage = 'Định dạng JSON không hợp lệ';
        // Thử trích xuất thông tin cơ bản từ text
        final riskScoreMatch = RegExp(
          r'"risk_score"\s*:\s*(\d+)',
        ).firstMatch(responseText);
        final summaryMatch = RegExp(
          r'"summary"\s*:\s*"([^"]*)"',
        ).firstMatch(responseText);

        if (riskScoreMatch != null) {
          final extractedScore =
              double.tryParse(riskScoreMatch.group(1) ?? '50') ?? 50;
          final extractedSummary =
              summaryMatch?.group(1) ?? 'Không thể phân tích đầy đủ';

          print(
            'Extracted partial data: score=$extractedScore, summary=$extractedSummary',
          );

          return GeminiAnalysisResult(
            riskScore: extractedScore,
            classification: extractedScore < 30
                ? 'safe'
                : (extractedScore < 60 ? 'suspicious' : 'phishing'),
            confidence: 50,
            reasons: [extractedSummary],
            phishingIndicators: [],
            recommendations: ['Phân tích không hoàn chỉnh - nên kiểm tra lại'],
            detailedAnalysis: {},
            rawResponse: responseText,
          );
        }
      }

      // Nếu không parse được gì, trả về kết quả mặc định
      return GeminiAnalysisResult(
        riskScore: 50,
        classification: 'unknown',
        confidence: 30,
        reasons: ['$errorMessage - vui lòng thử lại'],
        phishingIndicators: [],
        recommendations: ['Cần xem xét thủ công'],
        detailedAnalysis: {},
        rawResponse: responseText,
      );
    }
  }

  /// Test Gemini API connection
  Future<bool> testConnection() async {
    try {
      print('Testing Gemini API connection...');
      final response = await _model.generateContent([
        Content.text('{"status":"ok"}'),
      ]);

      print('Test response: ${response.text}');
      return response.text != null && response.text!.isNotEmpty;
    } catch (e) {
      print('Test connection failed: $e');
      return false;
    }
  }
}

class GeminiAnalysisResult {
  final double riskScore; // 0-100
  final String classification; // safe, suspicious, phishing
  final double confidence; // 0-100
  final List<String> reasons;
  final List<String> phishingIndicators;
  final List<String> recommendations;
  final Map<String, String> detailedAnalysis;
  final String rawResponse;

  GeminiAnalysisResult({
    required this.riskScore,
    required this.classification,
    required this.confidence,
    required this.reasons,
    required this.phishingIndicators,
    required this.recommendations,
    required this.detailedAnalysis,
    required this.rawResponse,
  });

  // ✅ FIX: Chỉ dựa vào classification, không override bằng riskScore
  // Vì classification đã được tính từ riskScore ở bước parse
  bool get isPhishing => classification == 'phishing';
  bool get isSuspicious => classification == 'suspicious';
  bool get isSafe => classification == 'safe';

  Map<String, dynamic> toJson() {
    return {
      'riskScore': riskScore,
      'classification': classification,
      'confidence': confidence,
      'reasons': reasons,
      'phishingIndicators': phishingIndicators,
      'recommendations': recommendations,
      'detailedAnalysis': detailedAnalysis,
      'rawResponse': rawResponse,
    };
  }

  factory GeminiAnalysisResult.fromJson(Map<String, dynamic> json) {
    return GeminiAnalysisResult(
      riskScore: (json['riskScore'] ?? 0).toDouble(),
      classification: json['classification'] ?? 'unknown',
      confidence: (json['confidence'] ?? 0).toDouble(),
      reasons: json['reasons'] != null
          ? List<String>.from(json['reasons'])
          : [],
      phishingIndicators: json['phishingIndicators'] != null
          ? List<String>.from(json['phishingIndicators'])
          : [],
      recommendations: json['recommendations'] != null
          ? List<String>.from(json['recommendations'])
          : [],
      detailedAnalysis: json['detailedAnalysis'] != null
          ? Map<String, String>.from(json['detailedAnalysis'])
          : {},
      rawResponse: json['rawResponse'] ?? '',
    );
  }
}
