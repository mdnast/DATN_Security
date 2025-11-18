import 'package:flutter/material.dart';
import '../services/gemini_analysis_service.dart';

class GmailAiChatScreen extends StatefulWidget {
  final String? initialQuestion;

  const GmailAiChatScreen({super.key, this.initialQuestion});

  @override
  State<GmailAiChatScreen> createState() => _GmailAiChatScreenState();
}

class _GmailAiChatScreenState extends State<GmailAiChatScreen> {
  final GeminiAnalysisService _geminiService = GeminiAnalysisService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuestion != null &&
        widget.initialQuestion!.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _controller.text = widget.initialQuestion!;
        _sendMessage();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _isSending = true;
    });
    _controller.clear();
    _scrollToBottom();

    try {
      final answer = await _askGmailAssistant(text);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: answer, isUser: false));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(
          text: 'Không thể kết nối tới AI: ${e.toString()}',
          isUser: false,
          isError: true,
        ));
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<String> _askGmailAssistant(String question) async {
    int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      try {
        await _geminiService.testConnection();
        final answer = await _geminiService.askGeneralGmailQuestion(question);
        return answer;
      } catch (e) {
        attempt++;
        if (attempt >= maxRetries) rethrow;
      }
    }

    throw Exception('Không thể hỏi trợ lý Gmail');
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Chat AI Gmail',
          style: TextStyle(
            color: Color(0xFF202124),
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF5F6368)),
        elevation: 0,
      ),
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Text(
              'Chatbot này dùng để hỏi chung về Gmail: cách sử dụng, quản lý hộp thư, bảo mật tài khoản, '
              'nhận diện spam/phishing nói chung... Nếu muốn phân tích một email cụ thể, hãy dùng AI trong màn chi tiết email.',
              style: TextStyle(fontSize: 14, color: Color(0xFF202124)),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return Align(
                  alignment:
                      msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.8,
                    ),
                    decoration: BoxDecoration(
                      color: msg.isUser
                          ? const Color(0xFF4285F4)
                          : (msg.isError
                              ? Colors.red[50]
                              : Colors.white),
                      borderRadius: BorderRadius.circular(12).copyWith(
                        bottomLeft: msg.isUser
                            ? const Radius.circular(12)
                            : Radius.zero,
                        bottomRight: msg.isUser
                            ? Radius.zero
                            : const Radius.circular(12),
                      ),
                      border: msg.isUser
                          ? null
                          : Border.all(
                              color: msg.isError
                                  ? Colors.red[200]!
                                  : Colors.grey[300]!,
                            ),
                    ),
                    child: Text(
                      msg.text,
                      style: TextStyle(
                        color: msg.isUser
                            ? Colors.white
                            : (msg.isError
                                ? Colors.red[900]
                                : const Color(0xFF202124)),
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: 'Hỏi AI về cách dùng Gmail, bảo mật, spam/phishing...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _isSending ? null : _sendMessage,
                    icon: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    color: const Color(0xFF4285F4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}
