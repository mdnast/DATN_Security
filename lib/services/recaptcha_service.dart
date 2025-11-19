import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import '../localization/app_localizations.dart';

class RecaptchaWidget extends StatefulWidget {
  final ValueChanged<String> onVerified;

  const RecaptchaWidget({super.key, required this.onVerified});

  @override
  State<RecaptchaWidget> createState() => _RecaptchaWidgetState();
}

class _RecaptchaWidgetState extends State<RecaptchaWidget> {
  String? _token;

  Future<void> _openCaptcha() async {
    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _RecaptchaFullScreenPage(),
      ),
    );

    if (token != null && token.isNotEmpty && mounted) {
      setState(() {
        _token = token;
      });
      widget.onVerified(token);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isVerified = _token != null && _token!.isNotEmpty;

    return OutlinedButton.icon
    (
      onPressed: _openCaptcha,
      icon: Icon(
        isVerified ? Icons.check_circle : Icons.verified_user,
        color: isVerified ? Colors.green : const Color(0xFF4285F4),
      ),
      label: Text(
        isVerified
            ? l.t('recaptcha_verified')
            : l.t('recaptcha_not_robot'),
        style: const TextStyle(fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        side: const BorderSide(color: Color(0xFF4285F4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _RecaptchaFullScreenPage extends StatefulWidget {
  const _RecaptchaFullScreenPage();

  @override
  State<_RecaptchaFullScreenPage> createState() => _RecaptchaFullScreenPageState();
}

class _RecaptchaFullScreenPageState extends State<_RecaptchaFullScreenPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'Recaptcha',
        onMessageReceived: (JavaScriptMessage message) {
          if (!mounted) return;
          Navigator.of(context).pop(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      );

    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString('assets/recaptcha.html');
    await _controller.loadHtmlString(
      html,
      baseUrl: 'https://guardmail.local',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('recaptcha_title')),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}


