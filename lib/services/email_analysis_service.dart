import 'dart:math';
import '../models/email_message.dart';
import '../models/scan_result.dart';
import 'anonymization_service.dart';
import 'gemini_analysis_service.dart';

class EmailAnalysisService {
  final AnonymizationService _anonymizationService = AnonymizationService();
  final GeminiAnalysisService _geminiService = GeminiAnalysisService();

  Future<ScanResult> analyzeEmail(EmailMessage email) async {
    // Reset anonymization service cho email mới
    _anonymizationService.reset();
    
    final threats = <String>[];
    double riskScore = 0.0;
    String result = 'unknown';
    
    // Kết quả Gemini
    GeminiAnalysisResult? geminiResult;
    Map<String, dynamic>? anonymizationInfo;
    final senderDomain = _extractDomain(email.from);

    try {
      print('========================================');
      print('STARTING EMAIL ANALYSIS');
      print('From: ${email.from}');
      print('Subject: ${email.subject}');
      print('========================================');
      // Bước 1: Làm mờ dữ liệu cá nhân
      print('Step 1: Anonymizing email...');
      anonymizationInfo = _anonymizationService.anonymizeEmail(
        subject: email.subject,
        body: email.body ?? email.snippet,
        from: email.from,
      );
      print('Anonymization complete');

      // Bước 2: Gửi email đã làm mờ lên Gemini
      print('Step 2: Sending to Gemini...');
      final anonymizedBody = _truncate(anonymizationInfo['body'] as String);
      geminiResult = await _geminiService.analyzeEmail(
        anonymizedSubject: anonymizationInfo['subject'],
        anonymizedBody: anonymizedBody,
        anonymizedFrom: anonymizationInfo['from'],
      );
      print('Gemini analysis complete!');
      print('Risk Score: ${geminiResult.riskScore}');
      print('Classification: ${geminiResult.classification}');

      // Sử dụng 100% kết quả từ Gemini
      riskScore = geminiResult.riskScore / 100.0;
      result = geminiResult.classification;
      threats.addAll(geminiResult.phishingIndicators);
      
    } catch (e, stackTrace) {
      // Nếu Gemini lỗi, trả về kết quả unknown với thông tin chi tiết
      print('========================================');
      print('GEMINI ANALYSIS FAILED');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('========================================');
      
      riskScore = 0.5;
      result = 'unknown';
      
      // Thêm error message chi tiết để debug
      String errorMessage = 'Lỗi phân tích AI';
      if (e.toString().contains('API')) {
        errorMessage = 'Lỗi API Gemini - kiểm tra API key';
      } else if (e.toString().contains('JSON') || e.toString().contains('Format')) {
        errorMessage = 'Lỗi định dạng JSON từ AI';
      } else if (e.toString().contains('network') || e.toString().contains('connect')) {
        errorMessage = 'Lỗi kết nối mạng';
      }
      
      threats.add('$errorMessage: ${e.toString().substring(0, e.toString().length > 100 ? 100 : e.toString().length)}');
    }

    // Đảm bảo riskScore trong khoảng 0-1
    riskScore = min(1.0, max(0.0, riskScore));

    // Confidence score = độ chắc chắn về kết quả phân tích
    // - Nếu riskScore = 0.1 (10% nguy hiểm = rất an toàn) → confidence = 90% an toàn
    // - Nếu riskScore = 0.9 (90% nguy hiểm) → confidence = 90% nguy hiểm
    // Logic: Nếu < 50% thì đảo ngược (1 - riskScore), nếu >= 50% giữ nguyên
    final confidenceScore = riskScore >= 0.5 
        ? riskScore 
        : 1.0 - riskScore;

    // Tạo analysis details
    final analysisDetails = {
      'senderDomain': senderDomain,
      'riskScore': riskScore,
      'analysisDate': DateTime.now().toIso8601String(),
      'analysisMethod': 'Gemini AI',
      'usedGeminiAI': true,
    };

    // Thêm kết quả Gemini nếu có
    if (geminiResult != null) {
      analysisDetails['gemini'] = {
        'riskScore': geminiResult.riskScore,
        'classification': geminiResult.classification,
        'confidence': geminiResult.confidence,
        'reasons': geminiResult.reasons,
        'recommendations': geminiResult.recommendations,
        'detailedAnalysis': geminiResult.detailedAnalysis,
      };
    }

    // Thêm thông tin anonymization nếu có
    if (anonymizationInfo != null) {
      analysisDetails['anonymization'] = {
        'entityCount': anonymizationInfo['entityCount'],
        'hasPersonalData': (anonymizationInfo['entityCount'] as Map).values.any((count) => count > 0),
      };
    }

    return ScanResult(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      emailId: email.id,
      from: email.from,
      subject: email.subject,
      scanDate: DateTime.now(),
      result: result,
      confidenceScore: confidenceScore,
      detectedThreats: threats.toSet().toList(),
      analysisDetails: analysisDetails,
    );
  }

  Future<String> askAiAboutEmail(EmailMessage email, String question) async {
    _anonymizationService.reset();

    final anonymizationInfo = _anonymizationService.anonymizeEmail(
      subject: email.subject,
      body: email.body ?? email.snippet,
      from: email.from,
    );

    final anonymizedBody = _truncate(anonymizationInfo['body'] as String);

    final answer = await _geminiService.askQuestionAboutEmail(
      anonymizedSubject: anonymizationInfo['subject'],
      anonymizedBody: anonymizedBody,
      anonymizedFrom: anonymizationInfo['from'],
      question: question,
    );

    return answer;
  }

  String _truncate(String text, {int maxChars = 2000}) {
    if (text.length <= maxChars) return text;
    return text.substring(0, maxChars);
  }

  String _extractDomain(String email) {
    final match = RegExp(r'@([a-zA-Z0-9.-]+)').firstMatch(email);
    return match?.group(1)?.toLowerCase() ?? '';
  }
}