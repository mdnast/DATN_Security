import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:googleapis_auth/auth_io.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart'
    show Client, BaseClient, BaseRequest, StreamedResponse;
import '../models/email_message.dart';
import 'auth_service.dart';
import '../models/email_attachment.dart';

class GmailService {
  final AuthService _authService = AuthService();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Gmail API - For Google Sign-In users
  Future<List<EmailMessage>> fetchEmailsViaGmailApi({
    int maxResults = 20,
    String folder = 'inbox', // inbox, sent, trash
  }) async {
    try {
      final accessToken = await _authService.getGoogleAccessToken();
      if (accessToken == null) {
        throw Exception('No access token available');
      }

      // Create authenticated client
      final credentials = AccessCredentials(
        AccessToken(
          'Bearer',
          accessToken,
          DateTime.now().toUtc().add(const Duration(hours: 1)),
        ),
        null,
        [
          'https://www.googleapis.com/auth/gmail.readonly',
          'https://www.googleapis.com/auth/gmail.modify',
          'https://www.googleapis.com/auth/gmail.send',
        ],
      );

      final client = authenticatedClient(
        _GoogleAuthClient(accessToken),
        credentials,
      );

      final gmailApi = gmail.GmailApi(client);

      List<String> labelIds;
      switch (folder) {
        case 'sent':
          labelIds = ['SENT'];
          break;
        case 'trash':
          labelIds = ['TRASH'];
          break;
        default:
          labelIds = ['INBOX'];
      }

      // Get message list
      final messageList = await gmailApi.users.messages.list(
        'me',
        maxResults: maxResults,
        labelIds: labelIds,
      );

      final List<EmailMessage> emails = [];

      if (messageList.messages != null) {
        // Fetch all messages in PARALLEL - much faster!
        final futures = messageList.messages!
            .where((m) => m.id != null)
            .map(
              (message) => gmailApi.users.messages.get(
                'me',
                message.id!,
                format: 'metadata',
                metadataHeaders: ['From', 'Subject'],
              ),
            )
            .toList();

        // Wait for all API calls to complete at once
        final results = await Future.wait(futures);

        // Parse all results (and fetch avatar URLs) in parallel
        final parsedFutures = results.map(_parseGmailMessage).toList();
        final parsedMessages = await Future.wait(parsedFutures);

        for (final emailMessage in parsedMessages) {
          if (emailMessage != null) {
            emails.add(emailMessage);
          }
        }
      }

      client.close();
      return emails;
    } catch (error) {
      print('Error fetching emails via Gmail API: $error');
      rethrow;
    }
  }

  // Fetch single email with FULL content
  Future<EmailMessage?> fetchEmailDetails(String id) async {
    try {
      final loginMethod = await _authService.getLoginMethod();

      if (loginMethod == 'google') {
        final accessToken = await _authService.getGoogleAccessToken();
        if (accessToken == null) throw Exception('No access token available');

        final credentials = AccessCredentials(
          AccessToken(
            'Bearer',
            accessToken,
            DateTime.now().toUtc().add(const Duration(hours: 1)),
          ),
          null,
          ['https://www.googleapis.com/auth/gmail.readonly'],
        );

        final client = authenticatedClient(
          _GoogleAuthClient(accessToken),
          credentials,
        );

        final gmailApi = gmail.GmailApi(client);

        // Fetch FULL message format (default is 'full' which includes body)
        final message = await gmailApi.users.messages.get('me', id);

        client.close();
        return await _parseGmailMessage(message);
      } else {
        // IMAP implementation
        // For IMAP, we might need to reconnect and fetch specific UID
        // simplified: reuse fetchEmails logic or implement specific fetch if needed
        // Since `enough_mail` doesn't easily support fetching by random String ID
        // without keeping connection open or knowing sequence ID,
        // we might stick to what we have or re-fetch.
        // However, for this bug fix, let's try to support Google first or
        // assume IMAP logic needs similar care if it was broken.
        // Re-using fetchEmailsViaImap logic but filtering?
        // Valid IMAP ID is sequence ID usually which changes.
        // For now, let's implement for Google as that seems to be the main target.
        return null; // TODO: Implement specific IMAP fetch if strictly needed
      }
    } catch (e) {
      print('Error fetching email details: $e');
      return null;
    }
  }

  Future<void> sendEmail({
    required String to,
    required String subject,
    required String body,
    List<EmailAttachment>? attachments,
  }) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      ['https://www.googleapis.com/auth/gmail.send'],
    );

    final client = authenticatedClient(
      _GoogleAuthClient(accessToken),
      credentials,
    );

    final gmailApi = gmail.GmailApi(client);

    final messageBuffer = StringBuffer();

    String _encodeHeader(String value) {
      final hasNonAscii = value.runes.any((r) => r > 127);
      if (!hasNonAscii) return value;
      final encoded = base64.encode(utf8.encode(value));
      return '=?UTF-8?B?$encoded?=';
    }

    final encodedSubject = _encodeHeader(subject);

    if (attachments != null && attachments.isNotEmpty) {
      final boundary = 'guardmail_${DateTime.now().millisecondsSinceEpoch}';

      messageBuffer
        ..writeln('To: $to')
        ..writeln('Subject: $encodedSubject')
        ..writeln('MIME-Version: 1.0')
        ..writeln('Content-Type: multipart/mixed; boundary="$boundary"')
        ..writeln()
        ..writeln('--$boundary')
        ..writeln('Content-Type: text/plain; charset="utf-8"')
        ..writeln('Content-Transfer-Encoding: base64')
        ..writeln()
        ..writeln(base64.encode(utf8.encode(body)));

      for (final attachment in attachments) {
        final encodedData = base64.encode(attachment.data);
        messageBuffer
          ..writeln('--$boundary')
          ..writeln(
            'Content-Type: ${attachment.mimeType}; name="${attachment.fileName}"',
          )
          ..writeln(
            'Content-Disposition: attachment; filename="${attachment.fileName}"',
          )
          ..writeln('Content-Transfer-Encoding: base64')
          ..writeln()
          ..writeln(encodedData);
      }

      messageBuffer..writeln('--$boundary--');
    } else {
      messageBuffer
        ..writeln('To: $to')
        ..writeln('Subject: $encodedSubject')
        ..writeln('Content-Type: text/plain; charset="utf-8"')
        ..writeln()
        ..writeln(body);
    }

    final bytes = utf8.encode(messageBuffer.toString());
    final base64Email = base64UrlEncode(bytes).replaceAll('=', '');

    final message = gmail.Message()..raw = base64Email;

    await gmailApi.users.messages.send(message, 'me');

    client.close();
  }

  Future<void> moveToTrash(String messageId) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      ['https://www.googleapis.com/auth/gmail.modify'],
    );

    final client = authenticatedClient(
      _GoogleAuthClient(accessToken),
      credentials,
    );

    final gmailApi = gmail.GmailApi(client);
    await gmailApi.users.messages.trash('me', messageId);

    client.close();
  }

  Future<void> restoreFromTrash(String messageId) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('No access token available');
    }

    final credentials = AccessCredentials(
      AccessToken(
        'Bearer',
        accessToken,
        DateTime.now().toUtc().add(const Duration(hours: 1)),
      ),
      null,
      ['https://www.googleapis.com/auth/gmail.modify'],
    );

    final client = authenticatedClient(
      _GoogleAuthClient(accessToken),
      credentials,
    );

    final gmailApi = gmail.GmailApi(client);
    await gmailApi.users.messages.untrash('me', messageId);

    client.close();
  }

  Future<EmailMessage?> _parseGmailMessage(gmail.Message message) async {
    try {
      final headers = message.payload?.headers ?? [];

      String from = '';
      String subject = '';

      for (var header in headers) {
        if (header.name == 'From') {
          from = _decodeMimeHeader(header.value);
        } else if (header.name == 'Subject') {
          subject = _decodeMimeHeader(header.value);
        }
      }

      // Use internalDate (milliseconds since epoch) instead of parsing Date header
      DateTime messageDate = DateTime.now();
      if (message.internalDate != null) {
        try {
          messageDate = DateTime.fromMillisecondsSinceEpoch(
            int.parse(message.internalDate!),
            isUtc: false,
          );
        } catch (e) {
          print('Error parsing internalDate: $e');
        }
      }

      return EmailMessage(
        id: message.id ?? '',
        from: from,
        subject: subject,
        snippet: message.snippet ?? '',
        date: messageDate,
        isRead: !(message.labelIds?.contains('UNREAD') ?? false),
      );
    } catch (error) {
      print('Error parsing Gmail message: $error');
      return null;
    }
  }

  String _extractEmailAddress(String fromHeader) {
    final trimmed = fromHeader.trim();
    if (trimmed.isEmpty) return '';

    final match = RegExp(r'<([^>]+)>').firstMatch(trimmed);
    if (match != null && match.groupCount >= 1) {
      return match.group(1)!.trim();
    }

    return trimmed;
  }

  String _decodeMimeHeader(String? value) {
    if (value == null || value.isEmpty) return '';

    final encodedWordRegex = RegExp(
      r'=\?([^?]+)\?(B|Q)\?([^?]+)\?=',
      caseSensitive: false,
    );

    return value.replaceAllMapped(encodedWordRegex, (match) {
      final encoding = match.group(2)?.toUpperCase();
      final encodedText = match.group(3) ?? '';

      try {
        if (encoding == 'B') {
          final bytes = base64.decode(encodedText);
          return utf8.decode(bytes);
        } else if (encoding == 'Q') {
          // Quoted-printable (RFC 2047 variant)
          var text = encodedText.replaceAll('_', ' ');
          final buffer = StringBuffer();
          for (int i = 0; i < text.length; i++) {
            final char = text[i];
            if (char == '=' && i + 2 < text.length) {
              final hex = text.substring(i + 1, i + 3);
              final codeUnit = int.tryParse(hex, radix: 16);
              if (codeUnit != null) {
                buffer.writeCharCode(codeUnit);
                i += 2;
                continue;
              }
            }
            buffer.write(char);
          }
          return buffer.toString();
        }
      } catch (_) {
        // Fallback to raw value if decode fails
      }

      return match.group(0) ?? '';
    });
  }

  // IMAP - For Email/Password users
  Future<List<EmailMessage>> fetchEmailsViaImap({
    int maxResults = 20,
    String folder = 'inbox', // inbox, sent, trash
  }) async {
    try {
      final email = await _getStoredEmail();
      final appPassword = await _getStoredAppPassword();

      if (email == null || appPassword == null) {
        throw Exception('Email or App Password not configured');
      }

      final client = ImapClient(isLogEnabled: false);

      await client.connectToServer('imap.gmail.com', 993, isSecure: true);
      await client.login(email, appPassword);
      // Hiện tại: luôn đọc INBOX cho tài khoản IMAP
      await client.selectInbox();

      final fetchResult = await client.fetchRecentMessages(
        messageCount: maxResults,
        criteria: 'BODY.PEEK[]',
      );

      final List<EmailMessage> emails = [];

      for (var message in fetchResult.messages) {
        final emailMessage = _parseImapMessage(message);
        if (emailMessage != null) {
          emails.add(emailMessage);
        }
      }

      await client.logout();

      return emails;
    } catch (error) {
      print('Error fetching emails via IMAP: $error');
      rethrow;
    }
  }

  EmailMessage? _parseImapMessage(MimeMessage message) {
    try {
      return EmailMessage(
        id: message.sequenceId?.toString() ?? '',
        from: message.from?.first.email ?? '',
        subject: message.decodeSubject() ?? 'No Subject',
        snippet: message.decodeTextPlainPart()?.substring(0, 100) ?? '',
        date: message.decodeDate() ?? DateTime.now(),
        isRead: message.isSeen,
      );
    } catch (error) {
      print('Error parsing IMAP message: $error');
      return null;
    }
  }

  // Storage for IMAP credentials
  Future<void> saveImapCredentials(String email, String appPassword) async {
    await _secureStorage.write(key: 'imap_email', value: email);
    await _secureStorage.write(key: 'imap_app_password', value: appPassword);
  }

  Future<String?> _getStoredEmail() async {
    return await _secureStorage.read(key: 'imap_email');
  }

  Future<String?> _getStoredAppPassword() async {
    return await _secureStorage.read(key: 'imap_app_password');
  }

  Future<bool> hasImapCredentials() async {
    final email = await _getStoredEmail();
    final password = await _getStoredAppPassword();
    return email != null && password != null;
  }

  Future<void> clearImapCredentials() async {
    await _secureStorage.delete(key: 'imap_email');
    await _secureStorage.delete(key: 'imap_app_password');
  }

  // Unified method - automatically chooses the right method
  Future<List<EmailMessage>> fetchEmails({
    int maxResults = 20,
    String folder = 'inbox',
  }) async {
    final loginMethod = await _authService.getLoginMethod();

    if (loginMethod == 'google') {
      return await fetchEmailsViaGmailApi(
        maxResults: maxResults,
        folder: folder,
      );
    } else {
      return await fetchEmailsViaImap(maxResults: maxResults, folder: folder);
    }
  }
}

// Helper class for authenticated HTTP client
class _GoogleAuthClient extends BaseClient {
  final String _token;
  final Client _client = Client();

  _GoogleAuthClient(this._token);

  @override
  Future<StreamedResponse> send(BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _client.send(request);
  }
}
