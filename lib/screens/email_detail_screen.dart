import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../models/scan_result.dart';
import '../services/email_analysis_service.dart';
import '../services/scan_history_service.dart';
import '../services/notification_service.dart';
import 'email_ai_chat_screen.dart';
import 'compose_email_screen.dart';

enum _EmailDetailMenuAction { reply, forward, compose }

class EmailDetailScreen extends StatefulWidget {
  final EmailMessage email;

  const EmailDetailScreen({super.key, required this.email});

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  final EmailAnalysisService _analysisService = EmailAnalysisService();
  final ScanHistoryService _scanHistoryService = ScanHistoryService();
  final NotificationService _notificationService = NotificationService();
  
  ScanResult? _scanResult;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _checkPreviousAnalysis();
  }

  Future<void> _checkPreviousAnalysis() async {
    final history = await _scanHistoryService.getScanHistory();
    final scansForEmail =
        history.where((s) => s.emailId == widget.email.id).toList()
          ..sort((a, b) => b.scanDate.compareTo(a.scanDate));
    final latestScan = scansForEmail.isNotEmpty ? scansForEmail.first : null;

    if (!mounted || latestScan == null) return;

    setState(() {
      _scanResult = latestScan;
    });
  }

  Future<void> _analyzeEmail() async {
    if (!mounted) return;
    setState(() => _isAnalyzing = true);

    try {
      final result = await _analysisService.analyzeEmail(widget.email);
      
      await _scanHistoryService.saveScanResult(result);
      
      if (result.isPhishing) {
        await _notificationService.showNotification(
          title: '🚨 Phát hiện email phishing!',
          body: 'Email từ ${widget.email.from} có dấu hiệu lừa đảo',
          type: 'phishing',
        );
      } else if (result.isSuspicious) {
        await _notificationService.showNotification(
          title: '⚠️ Email nghi ngờ',
          body: 'Email từ ${widget.email.from} cần xem xét kỹ hơn',
          type: 'security',
        );
      } else {
        await _notificationService.showNotification(
          title: '✅ Email an toàn',
          body: 'Email từ ${widget.email.from} đã được kiểm tra và an toàn',
          type: 'safe',
        );
      }

      if (mounted) {
        setState(() {
          _scanResult = result;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Phân tích hoàn tất!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi phân tích: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface = Theme.of(context).textTheme.bodyMedium?.color ?? const Color(0xFF202124);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WardMail',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: onSurface,
              ),
            ),
            const SizedBox(width: 6),
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF1877F2),
                shape: BoxShape.circle,
              ),
              child: Padding(
                padding: EdgeInsets.all(2.0),
                child: Icon(
                  Icons.check,
                  size: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Hỏi AI về email',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EmailAiChatScreen(email: widget.email),
                ),
              );
            },
          ),
          PopupMenuButton<_EmailDetailMenuAction>(
            onSelected: (action) {
              switch (action) {
                case _EmailDetailMenuAction.reply:
                  _handleReply();
                  break;
                case _EmailDetailMenuAction.forward:
                  _handleForward();
                  break;
                case _EmailDetailMenuAction.compose:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ComposeEmailScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _EmailDetailMenuAction.reply,
                child: ListTile(
                  leading: Icon(Icons.reply),
                  title: Text('Trả lời'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _EmailDetailMenuAction.forward,
                child: ListTile(
                  leading: Icon(Icons.forward),
                  title: Text('Chuyển tiếp'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _EmailDetailMenuAction.compose,
                child: ListTile(
                  leading: Icon(Icons.edit),
                  title: Text('Soạn email mới'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (_scanResult != null) _buildAnalysisResult(),
            _buildEmailContent(),
            const SizedBox(height: 80),
          ],
        ),
      ),
      floatingActionButton: _buildAnalyzeFab(),
    );
  }

  void _handleReply() {
    final quoted = _buildQuotedBody();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(
          initialTo: widget.email.from,
          initialSubject: widget.email.subject.startsWith('Re: ')
              ? widget.email.subject
              : 'Re: ${widget.email.subject}',
          initialBody: '\n\n$quoted',
        ),
      ),
    );
  }

  void _handleForward() {
    final quoted = _buildQuotedBody();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ComposeEmailScreen(
          initialSubject: widget.email.subject.startsWith('Fwd: ')
              ? widget.email.subject
              : 'Fwd: ${widget.email.subject}',
          initialBody: '\n\n$quoted',
        ),
      ),
    );
  }

  String _buildQuotedBody() {
    final originalBody = widget.email.body ?? widget.email.snippet;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(widget.email.date);
    final from = widget.email.from;
    final subject = widget.email.subject;

    final quotedLines = originalBody
        .split('\n')
        .map((line) => '> $line')
        .join('\n');

    return '---\nOn $dateStr, $from wrote:\nSubject: $subject\n\n$quotedLines';
  }

  Widget? _buildAnalyzeFab() {
    // Cho phép phân tích lần đầu hoặc phân tích lại nếu kết quả hiện tại là 'unknown'
    final bool canAnalyze = _scanResult == null || _scanResult!.result == 'unknown';
    if (!canAnalyze) return null;

    return FloatingActionButton.extended(
      onPressed: _isAnalyzing ? null : _analyzeEmail,
      backgroundColor: const Color(0xFF4285F4),
      icon: _isAnalyzing
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.security, color: Colors.white),
      label: Text(
        _isAnalyzing
            ? 'Đang phân tích...'
            : (_scanResult == null ? 'Phân tích Email' : 'Phân tích lại Email'),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildAnalysisResult() {
    if (_scanResult == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    String statusDescription;

    if (_scanResult!.isPhishing) {
      statusColor = const Color(0xFFEA4335);
      statusText = 'NGUY HIỂM';
      statusIcon = Icons.dangerous;
      statusDescription = 'Email này có dấu hiệu lừa đảo. Không nên mở link hoặc tải file đính kèm.';
    } else if (_scanResult!.isSuspicious) {
      statusColor = const Color(0xFFFBBC04);
      statusText = 'NGHI NGỜ';
      statusIcon = Icons.warning_amber;
      statusDescription = 'Email này có một số dấu hiệu đáng ngờ. Hãy cẩn thận khi tương tác.';
    } else {
      statusColor = const Color(0xFF34A853);
      statusText = 'AN TOÀN';
      statusIcon = Icons.check_circle;
      statusDescription = 'Email này đã được kiểm tra và có vẻ an toàn.';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getConfidenceLabel(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusDescription,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
          ),
          if (_scanResult!.detectedThreats.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Mối đe dọa phát hiện:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _scanResult!.detectedThreats.map((threat) => 
                GestureDetector(
                  onTap: () => _showThreatDetail(threat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFFEA4335).withOpacity(0.16)
                          : const Color(0xFFEA4335).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEA4335).withOpacity(isDark ? 0.6 : 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.bug_report, size: 14, color: Color(0xFFEA4335)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            threat,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white : const Color(0xFFB31412),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.touch_app,
                          size: 12,
                          color: const Color(0xFFEA4335).withOpacity(0.7),
                        ),
                      ],
                    ),
                  ),
                ),
              ).toList(),
            ),
          ],
          // Hiển thị kết quả Gemini AI nếu có
          if (_scanResult!.analysisDetails['usedGeminiAI'] == true) ...[
            const SizedBox(height: 16),
            _buildGeminiResults(),
          ],
          const SizedBox(height: 12),
          Text(
            'Phân tích lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(_scanResult!.scanDate)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailContent() {
    final bodyText = _decodeHtmlEntities(widget.email.body ?? widget.email.snippet);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Thông tin Email',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          _buildSenderRow(),
          const SizedBox(height: 12),
          _buildInfoRow('Tiêu đề:', widget.email.subject),
          const SizedBox(height: 12),
          _buildInfoRow(
            'Ngày:',
            DateFormat('dd/MM/yyyy HH:mm').format(widget.email.date),
          ),
          const Divider(height: 24),
          const Text(
            'Nội dung:',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F6368),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Text(
              bodyText,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _decodeHtmlEntities(String input) {
    if (input.isEmpty) return input;

    var result = input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");

    // Numeric entities: &#NNN;
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (m) {
        try {
          final code = int.parse(m.group(1)!);
          return String.fromCharCode(code);
        } catch (_) {
          return m.group(0)!;
        }
      },
    );

    return result;
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSenderRow() {
    final from = widget.email.from.trim();
    final initial = from.isNotEmpty ? from[0].toUpperCase() : '?';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFFE8F0FE),
          child: Text(
            initial,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4285F4),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                from,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(widget.email.date),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeminiResults() {
    final geminiData = _scanResult!.analysisDetails['gemini'] as Map<String, dynamic>?;
    if (geminiData == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final bodyColor = theme.textTheme.bodyMedium?.color;

    final reasons = geminiData['reasons'] as List<dynamic>? ?? [];
    final recommendations = geminiData['recommendations'] as List<dynamic>? ?? [];
    final detailedAnalysis = geminiData['detailedAnalysis'] as Map<String, dynamic>? ?? {};
    
    // Lấy risk score và xác định màu sắc
    final riskScore = geminiData['riskScore']?.toInt() ?? 0;
    Color scoreColor;
    Color scoreBgColor;
    
    if (riskScore >= 70) {
      // Nguy hiểm (70-100)
      scoreColor = Colors.white;
      scoreBgColor = const Color(0xFFEA4335); // Đỏ
    } else if (riskScore >= 40) {
      // Nghi ngờ (40-69)
      scoreColor = Colors.black87;
      scoreBgColor = const Color(0xFFFBBC04); // Vàng
    } else {
      // An toàn (0-39)
      scoreColor = Colors.white;
      scoreBgColor = const Color(0xFF34A853); // Xanh
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: isDark
                ? null
                : LinearGradient(
                    colors: [Colors.purple[50]!, Colors.blue[50]!],
                  ),
            color: isDark ? surface : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? theme.colorScheme.primary.withOpacity(0.4)
                  : Colors.purple[200]!,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_awesome,
                color: isDark ? theme.colorScheme.primary : Colors.purple[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Phân tích bởi Gemini AI',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$riskScore/100',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Lý do đánh giá:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...reasons.map((reason) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 6, right: 8),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.purple[700],
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    reason.toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: bodyColor?.withOpacity(0.8),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],

        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Khuyến nghị:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          ...recommendations.map((rec) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? surface : Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark
                    ? theme.colorScheme.primary.withOpacity(0.5)
                    : Colors.blue[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.tips_and_updates,
                  size: 16,
                  color: isDark ? theme.colorScheme.primary : Colors.blue[700],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rec.toString(),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).textTheme.bodyMedium?.color),
                  ),
                ),
              ],
            ),
          )),
        ],

        if (detailedAnalysis.isNotEmpty) ...[
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text(
              'Phân tích chi tiết',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: [
              ...detailedAnalysis.entries.map((entry) => 
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          '${entry.key}:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  void _showThreatDetail(String threat) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.bug_report, color: Colors.red[700], size: 24),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Chi tiết mối đe dọa',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              threat,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.5,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  String _getConfidenceLabel() {
    final confidencePercent = (_scanResult!.confidenceScore * 100).toInt();
    
    if (_scanResult!.isPhishing) {
      // Email nguy hiểm → hiển thị "Độ nguy hiểm"
      return 'Độ nguy hiểm: $confidencePercent%';
    } else if (_scanResult!.isSuspicious) {
      // Email nghi ngờ → hiển thị "Mức độ nghi ngờ"
      return 'Mức độ nghi ngờ: $confidencePercent%';
    } else {
      // Email an toàn → hiển thị "Độ an toàn"
      return 'Độ an toàn: $confidencePercent%';
    }
  }
}