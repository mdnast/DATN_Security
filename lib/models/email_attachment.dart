class EmailAttachment {
  final String fileName;
  final String mimeType;
  final List<int> data;

  EmailAttachment({
    required this.fileName,
    required this.mimeType,
    required this.data,
  });
}
