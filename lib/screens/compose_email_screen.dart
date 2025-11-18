import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/gmail_service.dart';
import '../models/email_attachment.dart';

class ComposeEmailScreen extends StatefulWidget {
  final String? initialTo;
  final String? initialSubject;
  final String? initialBody;

  const ComposeEmailScreen({
    super.key,
    this.initialTo,
    this.initialSubject,
    this.initialBody,
  });

  @override
  State<ComposeEmailScreen> createState() => _ComposeEmailScreenState();
}

class _ComposeEmailScreenState extends State<ComposeEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();
  final GmailService _gmailService = GmailService();
  bool _isSending = false;
  final List<PlatformFile> _attachments = [];

  @override
  void initState() {
    super.initState();
    _toController.text = widget.initialTo ?? '';
    _subjectController.text = widget.initialSubject ?? '';
    _bodyController.text = widget.initialBody ?? '';
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);

    try {
      final attachmentModels = _attachments
          .where((file) => file.bytes != null)
          .map((file) => EmailAttachment(
                fileName: file.name,
                mimeType: _guessMimeType(file.name),
                data: file.bytes!,
              ))
          .toList();

      await _gmailService.sendEmail(
        to: _toController.text.trim(),
        subject: _subjectController.text.trim(),
        body: _bodyController.text,
        attachments: attachmentModels.isEmpty ? null : attachmentModels,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã gửi email'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi email: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _previewAttachment(PlatformFile file) {
    final data = file.bytes;
    if (data == null) return;

    final name = file.name.toLowerCase();
    final isImage =
        name.endsWith('.png') || name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.gif');
    final isText = name.endsWith('.txt') || name.endsWith('.csv');

    if (isImage) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(file.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Flexible(
                child: InteractiveViewer(
                  child: Image.memory(data, fit: BoxFit.contain),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      );
      return;
    }

    String? textContent;
    if (isText) {
      try {
        textContent = String.fromCharCodes(data);
      } catch (_) {
        textContent = null;
      }
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(file.name),
        content: SizedBox(
          width: 400,
          child: (isText && textContent != null)
              ? SingleChildScrollView(
                  child: Text(
                    textContent,
                    maxLines: 30,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : const Text('Không thể hiển thị trước nội dung file này. Bạn vẫn có thể gửi kèm file.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _attachments.addAll(
          result.files.where((file) => file.bytes != null),
        );
      });
    }
  }

  String _guessMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.csv')) return 'text/csv';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.xlsx')) {
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    }
    return 'application/octet-stream';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Soạn email'),
        actions: [
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _isSending ? null : _sendEmail,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _toController,
                decoration: const InputDecoration(
                  labelText: 'Người nhận',
                  hintText: 'ví dụ: user@gmail.com',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Vui lòng nhập email người nhận';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _subjectController,
                decoration: const InputDecoration(
                  labelText: 'Chủ đề',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickAttachments,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Đính kèm file'),
                  ),
                  const SizedBox(width: 12),
                  if (_attachments.isNotEmpty)
                    Expanded(
                      child: Text(
                        '${_attachments.length} file đã chọn',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              if (_attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: List.generate(_attachments.length, (index) {
                      final file = _attachments[index];
                      return InkWell(
                        onTap: () => _previewAttachment(file),
                        child: Chip(
                          label: Text(
                            file.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() {
                              _attachments.removeAt(index);
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: TextFormField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung',
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  keyboardType: TextInputType.multiline,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
