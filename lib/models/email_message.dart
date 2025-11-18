class EmailMessage {
  final String id;
  final String from;
  final String subject;
  final String snippet;
  final DateTime date;
  final bool isRead;
  final String? body;
  final String? photoUrl;
  
  EmailMessage({
    required this.id,
    required this.from,
    required this.subject,
    required this.snippet,
    required this.date,
    this.isRead = false,
    this.body,
    this.photoUrl,
  });

  factory EmailMessage.fromJson(Map<String, dynamic> json) {
    return EmailMessage(
      id: json['id'] ?? '',
      from: json['from'] ?? '',
      subject: json['subject'] ?? '',
      snippet: json['snippet'] ?? '',
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      isRead: json['isRead'] ?? false,
      body: json['body'],
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from': from,
      'subject': subject,
      'snippet': snippet,
      'date': date.toIso8601String(),
      'isRead': isRead,
      'body': body,
      'photoUrl': photoUrl,
    };
  }
}
