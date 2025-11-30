import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/email_message.dart';
import '../models/scan_result.dart';
import '../services/email_analysis_service.dart';
import '../services/scan_history_service.dart';
import '../services/notification_service.dart';
import '../services/feedback_service.dart';
import '../localization/app_localizations.dart';
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
  final FeedbackService _feedbackService = FeedbackService();
  final TextEditingController _feedbackController = TextEditingController();

  ScanResult? _scanResult;
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    _checkPreviousAnalysis();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
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
    final l = AppLocalizations.of(context);
    setState(() => _isAnalyzing = true);

    try {
      // Lấy feedback từ controller nếu có
      final feedback = _feedbackController.text.trim();

      final result = await _analysisService.analyzeEmail(
        widget.email,
        userFeedback: feedback.isNotEmpty ? feedback : null,
      );

      await _scanHistoryService.saveScanResult(result);

      final notificationData = {
        'email_id': widget.email.id,
        'from': widget.email.from,
        'subject': widget.email.subject,
        'snippet': widget.email.snippet,
        'body': widget.email.body ?? widget.email.snippet,
        'date': widget.email.date.toIso8601String(),
        'photoUrl': widget.email.photoUrl,
        'action': 'open_email_detail',
      };

      final from = widget.email.from;

      if (result.isPhishing) {
        await _notificationService.showNotification(
          title: l.t('notif_phishing_title'),
          body: l.t('notif_phishing_body').replaceFirst('{from}', from),
          type: 'phishing',
          data: notificationData,
        );
      } else if (result.isSuspicious) {
        await _notificationService.showNotification(
          title: l.t('notif_suspicious_title'),
          body: l.t('notif_suspicious_body').replaceFirst('{from}', from),
          type: 'security',
          data: notificationData,
        );
      } else {
        await _notificationService.showNotification(
          title: l.t('notif_safe_title'),
          body: l.t('notif_safe_body').replaceFirst('{from}', from),
          type: 'safe',
          data: notificationData,
        );
      }

      if (mounted) {
        setState(() {
          _scanResult = result;
        });

        // Nếu có feedback, thông báo đã re-analyze với feedback
        if (feedback.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã phân tích lại dựa trên phản hồi của bạn'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l.t('email_detail_analysis_done')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l
                  .t('email_detail_analysis_error')
                  .replaceFirst('{error}', e.toString()),
            ),
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

  // Derive safety checks from scan result to ensure consistency
  Map<String, dynamic> _deriveSafetyFromScanResult(
    ScanResult result,
    String locale,
  ) {
    // If email is dangerous/suspicious, some criteria must fail
    bool piiProtection = true;
    bool antiPhishing = true;
    bool informationAccuracy = true;
    bool professionalTone = true;
    bool compliance = true;

    if (result.isPhishing) {
      // Phishing emails fail anti-phishing and usually tone/accuracy
      antiPhishing = false;
      professionalTone = false;
      informationAccuracy = false;
    } else if (result.isSuspicious) {
      // Suspicious emails might fail 1-2 criteria
      if (result.detectedThreats.isNotEmpty) {
        // Check threat types to determine which criteria failed
        final threats = result.detectedThreats
            .map((t) => t.toLowerCase())
            .join(' ');
        if (threats.contains('phish') || threats.contains('lừa')) {
          antiPhishing = false;
        }
        if (threats.contains('spam') || threats.contains('rác')) {
          professionalTone = false;
        }
        if (threats.contains('pii') || threats.contains('nhạy cảm')) {
          piiProtection = false;
        }
      } else {
        // Default: fail tone for suspicious
        professionalTone = false;
      }
    }
    // If safe, all pass (default values)

    int passedCount = [
      piiProtection,
      antiPhishing,
      informationAccuracy,
      professionalTone,
      compliance,
    ].where((p) => p).length;

    return {
      'piiProtection': piiProtection,
      'antiPhishing': antiPhishing,
      'informationAccuracy': informationAccuracy,
      'professionalTone': professionalTone,
      'compliance': compliance,
      'passedCount': passedCount,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final onSurface =
        Theme.of(context).textTheme.bodyMedium?.color ??
        const Color(0xFF202124);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.t('app_title'),
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
                child: Icon(Icons.check, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: l.t('email_detail_ask_ai_tooltip'),
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
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _EmailDetailMenuAction.reply,
                child: ListTile(
                  leading: const Icon(Icons.reply),
                  title: Text(l.t('email_detail_menu_reply')),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _EmailDetailMenuAction.forward,
                child: ListTile(
                  leading: const Icon(Icons.forward),
                  title: Text(l.t('email_detail_menu_forward')),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: _EmailDetailMenuAction.compose,
                child: ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(l.t('email_detail_menu_compose')),
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
    final bool canAnalyze =
        _scanResult == null || _scanResult!.result == 'unknown';
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
            ? AppLocalizations.of(context).t('email_detail_analyzing')
            : (_scanResult == null
                  ? AppLocalizations.of(context).t('email_detail_analyze')
                  : AppLocalizations.of(context).t('email_detail_reanalyze')),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildAnalysisResult() {
    if (_scanResult == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    String statusDescription;

    if (_scanResult!.isPhishing) {
      statusColor = const Color(0xFFEA4335);
      statusText = l.t('email_detail_status_phishing');
      statusIcon = Icons.dangerous;
      statusDescription = l.t('email_detail_status_phishing_desc');
    } else if (_scanResult!.isSuspicious) {
      statusColor = const Color(0xFFFBBC04);
      statusText = l.t('email_detail_status_suspicious');
      statusIcon = Icons.warning_amber;
      statusDescription = l.t('email_detail_status_suspicious_desc');
    } else {
      statusColor = const Color(0xFF34A853);
      statusText = l.t('email_detail_status_safe');
      statusIcon = Icons.check_circle;
      statusDescription = l.t('email_detail_status_safe_desc');
    }

    // Get safety checks derived from actual scan result
    final safetyChecks = _deriveSafetyFromScanResult(_scanResult!, locale);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Status Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getConfidenceLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              statusDescription,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
                height: 1.4,
              ),
            ),
          ),

          // Safety Check Section (Inline)
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.security, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                locale == 'vi' ? 'Kiểm tra An toàn' : 'Safety Check',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: safetyChecks['passedCount'] == 5
                      ? Colors.green
                      : safetyChecks['passedCount'] >= 3
                      ? Colors.orange
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${safetyChecks['passedCount']}/5',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Safety Criteria (Compact List)
          _buildSafetyCriterion(
            locale == 'vi' ? 'Bảo vệ PII' : 'PII Protection',
            safetyChecks['piiProtection'] as bool,
          ),
          _buildSafetyCriterion(
            locale == 'vi' ? 'Chống Lừa đảo' : 'Anti-Phishing',
            safetyChecks['antiPhishing'] as bool,
          ),
          _buildSafetyCriterion(
            locale == 'vi' ? 'Độ chính xác' : 'Accuracy',
            safetyChecks['informationAccuracy'] as bool,
          ),
          _buildSafetyCriterion(
            locale == 'vi' ? 'Văn phong' : 'Tone',
            safetyChecks['professionalTone'] as bool,
          ),
          _buildSafetyCriterion(
            locale == 'vi' ? 'Tuân thủ' : 'Compliance',
            safetyChecks['compliance'] as bool,
          ),

          // Feedback Section (Inline)
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.feedback_outlined,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l.t('feedback_section_title'),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Compact Feedback Input
          TextField(
            controller: _feedbackController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: l.t('feedback_input_hint'),
              hintStyle: TextStyle(
                fontSize: 12,
                color: theme.brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: theme.brightness == Brightness.dark
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              filled: true,
              fillColor: theme.brightness == Brightness.dark
                  ? Colors.grey.shade900
                  : Colors.grey.shade50,
            ),
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isAnalyzing ? null : _analyzeEmail,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.orange,
                            ),
                          ),
                        )
                      : const Icon(Icons.refresh, size: 16),
                  label: Text(
                    _isAnalyzing
                        ? (locale == 'vi'
                              ? 'Đang phân tích...'
                              : 'Analyzing...')
                        : l.t('feedback_reanalyze_button'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Colors.orange.shade600),
                    foregroundColor: Colors.orange.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final feedback = _feedbackController.text.trim();
                    if (feedback.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l.t('feedback_empty_message')),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    await _feedbackService.saveFeedback(
                      emailId: widget.email.id,
                      feedback: feedback,
                      analysisResult: _scanResult?.result ?? 'unknown',
                    );

                    _feedbackController.clear();

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(l.t('feedback_submitted')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.send, size: 16),
                  label: Text(
                    l.t('feedback_submit_button'),
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          // Gemini AI Results
          if (_scanResult!.analysisDetails['usedGeminiAI'] == true) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _buildGeminiResults(),
          ],

          // Timestamp
          const SizedBox(height: 12),
          Text(
            l
                .t('email_detail_analyzed_at')
                .replaceFirst(
                  '{time}',
                  DateFormat('dd/MM/yyyy HH:mm').format(_scanResult!.scanDate),
                ),
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyCriterion(String title, bool passed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle : Icons.cancel,
            color: passed ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildEmailContent() {
    final bodyText = _decodeHtmlEntities(
      widget.email.body ?? widget.email.snippet,
    );
    final l = AppLocalizations.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.t('email_detail_info_title'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          _buildSenderRow(),
          const SizedBox(height: 12),
          _buildInfoRow(l.t('email_detail_info_subject'), widget.email.subject),
          const SizedBox(height: 12),
          _buildInfoRow(
            l.t('email_detail_info_date'),
            DateFormat('dd/MM/yyyy HH:mm').format(widget.email.date),
          ),
          const Divider(height: 24),
          Text(
            l.t('email_detail_info_content'),
            style: const TextStyle(
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

    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      try {
        final code = int.parse(m.group(1)!);
        return String.fromCharCode(code);
      } catch (_) {
        return m.group(0)!;
      }
    });

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
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeminiResults() {
    final geminiData =
        _scanResult!.analysisDetails['gemini'] as Map<String, dynamic>?;
    if (geminiData == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final bodyColor = theme.textTheme.bodyMedium?.color;

    final reasons = geminiData['reasons'] as List<dynamic>? ?? [];
    final recommendations =
        geminiData['recommendations'] as List<dynamic>? ?? [];
    final detailedAnalysis =
        geminiData['detailedAnalysis'] as Map<String, dynamic>? ?? {};
    final l = AppLocalizations.of(context);

    final riskScore = geminiData['riskScore']?.toInt() ?? 0;
    Color scoreColor;
    Color scoreBgColor;

    if (riskScore >= 70) {
      scoreColor = Colors.white;
      scoreBgColor = const Color(0xFFEA4335);
    } else if (riskScore >= 40) {
      scoreColor = Colors.black87;
      scoreBgColor = const Color(0xFFFBBC04);
    } else {
      scoreColor = Colors.white;
      scoreBgColor = const Color(0xFF34A853);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
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
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                l.t('gemini_analysis_title'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: scoreBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$riskScore/100',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (reasons.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            l.t('gemini_analysis_reasons_title'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 8),
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.purple[700],
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      reason.toString(),
                      style: TextStyle(
                        fontSize: 12,
                        color: bodyColor?.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (recommendations.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            l.t('gemini_analysis_recommendations_title'),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          ...recommendations.map(
            (rec) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
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
                    size: 14,
                    color: isDark
                        ? theme.colorScheme.primary
                        : Colors.blue[700],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      rec.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],

        if (detailedAnalysis.isNotEmpty) ...[
          const SizedBox(height: 10),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              l.t('gemini_analysis_details_title'),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            children: [
              ...detailedAnalysis.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          '${entry.key}:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry.value.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
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

  String _getConfidenceLabel() {
    final confidencePercent = (_scanResult!.confidenceScore * 100).toInt();
    final l = AppLocalizations.of(context);
    final percentStr = confidencePercent.toString();

    if (_scanResult!.isPhishing) {
      return l
          .t('email_detail_confidence_phishing')
          .replaceFirst('{percent}', percentStr);
    } else if (_scanResult!.isSuspicious) {
      return l
          .t('email_detail_confidence_suspicious')
          .replaceFirst('{percent}', percentStr);
    } else {
      return l
          .t('email_detail_confidence_safe')
          .replaceFirst('{percent}', percentStr);
    }
  }
}
