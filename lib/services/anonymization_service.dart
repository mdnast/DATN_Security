class AnonymizationService {
  // Ánh xạ để lưu trữ các thay thế nhất quán
  final Map<String, String> _personMapping = {};
  final Map<String, String> _phoneMapping = {};
  final Map<String, String> _emailMapping = {};
  final Map<String, String> _locationMapping = {};
  final Map<String, String> _idMapping = {};
  final Map<String, String> _urlMapping = {};
  final Map<String, String> _dateMapping = {};

  int _personCounter = 1;
  int _phoneCounter = 1;
  int _emailCounter = 1;
  int _locationCounter = 1;
  int _idCounter = 1;
  int _urlCounter = 1;
  int _dateCounter = 1;

  // Danh sách tên giả để thay thế
  final List<String> _fakeNames = [
    'Nguyễn Văn Đông', 'Trần Thị Trang', 'Lê Văn Cường', 'Phạm Thị Dương',
    'Hoàng Văn Em', 'Phan Thị Phương', 'Vũ Văn Giang', 'Đặng Thị Hạnh',
    'Bùi Văn Hùng', 'Đỗ Thị Kim', 'Hồ Văn Long', 'Ngô Thị Mai',
  ];

  /// Bước 1: Nhận email gốc và xử lý
  Map<String, dynamic> anonymizeEmail({
    required String subject,
    required String body,
    required String from,
  }) {
    // Bước 2: Tiền xử lý văn bản
    final processedSubject = _preprocessText(subject);
    final processedBody = _preprocessText(body);

    // Bước 3-5: Nhận diện thực thể, tạo dữ liệu giả, và làm mờ
    final anonymizedSubject = _maskEntities(processedSubject);
    final anonymizedBody = _maskEntities(processedBody);
    
    // KHÔNG làm mờ địa chỉ người gửi - giữ nguyên để Gemini phân tích domain
    final anonymizedFrom = from;

    return {
      'subject': anonymizedSubject,
      'body': anonymizedBody,
      'from': anonymizedFrom,
      'mapping': _getMappingInfo(),
      'entityCount': _getEntityCount(),
    };
  }

  /// Bước 2: Tiền xử lý văn bản (chuẩn hóa, tách dòng)
  String _preprocessText(String text) {
    // Chuẩn hóa khoảng trắng
    String processed = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // Chuẩn hóa dấu xuống dòng
    processed = processed.replaceAll('\r\n', '\n');
    processed = processed.replaceAll('\r', '\n');
    
    // Loại bỏ các ký tự đặc biệt không cần thiết
    processed = processed.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '');
    
    return processed;
  }

  /// Bước 3-5: Nhận diện thực thể (NER), tạo dữ liệu giả, và thực thi làm mờ
  String _maskEntities(String text) {
    // Tạo danh sách các match với vị trí
    final List<EntityMatch> matches = [];

    // 1. Nhận diện EMAIL
    final emailRegex = RegExp(
      r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b',
      caseSensitive: false,
    );
    for (var match in emailRegex.allMatches(text)) {
      matches.add(EntityMatch(
        start: match.start,
        end: match.end,
        original: match.group(0)!,
        type: 'EMAIL',
      ));
    }

    // 2. Nhận diện SỐ ĐIỆN THOẠI (nhiều format)
    final phoneRegex = RegExp(
      r'(?:\+84|0)(?:\d{9,10})|(?:\(\d{2,4}\)\s?\d{6,8})|(?:\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{3,4})',
    );
    for (var match in phoneRegex.allMatches(text)) {
      matches.add(EntityMatch(
        start: match.start,
        end: match.end,
        original: match.group(0)!,
        type: 'PHONE',
      ));
    }

    // 3. Nhận diện URL
    final urlRegex = RegExp(
      r'https?://[^\s<>"]+|www\.[^\s<>"]+',
      caseSensitive: false,
    );
    for (var match in urlRegex.allMatches(text)) {
      matches.add(EntityMatch(
        start: match.start,
        end: match.end,
        original: match.group(0)!,
        type: 'URL',
      ));
    }

    // 4. Nhận diện SỐ CCCD/CMND/Hộ chiếu
    final idRegex = RegExp(
      r'\b(?:\d{9}|\d{12})\b',
    );
    for (var match in idRegex.allMatches(text)) {
      final id = match.group(0)!;
      // Chỉ xem là ID nếu có 9 hoặc 12 chữ số liên tiếp
      if (id.length == 9 || id.length == 12) {
        matches.add(EntityMatch(
          start: match.start,
          end: match.end,
          original: id,
          type: 'ID',
        ));
      }
    }

    // 5. Nhận diện NGÀY THÁNG
    final dateRegex = RegExp(
      r'\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{2,4}[/-]\d{1,2}[/-]\d{1,2})',
    );
    for (var match in dateRegex.allMatches(text)) {
      matches.add(EntityMatch(
        start: match.start,
        end: match.end,
        original: match.group(0)!,
        type: 'DATE',
      ));
    }

    // 6. Nhận diện TÊN NGƯỜI (Họ tên tiếng Việt)
    final nameRegex = RegExp(
      r'\b(?:[A-ZÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ][a-zàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]+\s){1,3}[A-ZÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ][a-zàáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]+',
    );
    for (var match in nameRegex.allMatches(text)) {
      final name = match.group(0)!;
      // Chỉ xem là tên nếu có từ 2-4 từ
      final words = name.split(' ');
      if (words.length >= 2 && words.length <= 4) {
        matches.add(EntityMatch(
          start: match.start,
          end: match.end,
          original: name,
          type: 'PERSON',
        ));
      }
    }

    // 7. Nhận diện ĐỊA CHỈ/ĐỊA ĐIỂM
    final locationRegex = RegExp(
      r'\b(?:Hà Nội|TP\.?\s*HCM|Sài Gòn|Đà Nẵng|Hải Phòng|Cần Thơ|' +
      r'Quận \d+|Phường [^\s,]+|Đường [^\s,]+|' +
      r'Tỉnh [^\s,]+|Thành phố [^\s,]+)',
      caseSensitive: false,
    );
    for (var match in locationRegex.allMatches(text)) {
      matches.add(EntityMatch(
        start: match.start,
        end: match.end,
        original: match.group(0)!,
        type: 'LOCATION',
      ));
    }

    // Sắp xếp matches theo vị trí từ cuối lên đầu (để thay thế không ảnh hưởng index)
    matches.sort((a, b) => b.start.compareTo(a.start));

    // Bước 5: Thực thi làm mờ (thay thế từ cuối văn bản lên đầu)
    String maskedText = text;
    for (var match in matches) {
      final replacement = _getReplacementForEntity(match.original, match.type);
      maskedText = maskedText.substring(0, match.start) + 
                   replacement + 
                   maskedText.substring(match.end);
    }

    return maskedText;
  }

  /// Bước 4: Tạo dữ liệu giả & ánh xạ nhất quán
  String _getReplacementForEntity(String original, String type) {
    switch (type) {
      case 'EMAIL':
        if (_emailMapping.containsKey(original)) {
          return _emailMapping[original]!;
        }
        final replacement = 'email${_emailCounter}@example.com';
        _emailMapping[original] = replacement;
        _emailCounter++;
        return replacement;

      case 'PHONE':
        if (_phoneMapping.containsKey(original)) {
          return _phoneMapping[original]!;
        }
        final replacement = '0${_phoneCounter.toString().padLeft(9, '0')}';
        _phoneMapping[original] = replacement;
        _phoneCounter++;
        return replacement;

      case 'URL':
        if (_urlMapping.containsKey(original)) {
          return _urlMapping[original]!;
        }
        final replacement = 'https://example${_urlCounter}.com';
        _urlMapping[original] = replacement;
        _urlCounter++;
        return replacement;

      case 'ID':
        if (_idMapping.containsKey(original)) {
          return _idMapping[original]!;
        }
        final length = original.length;
        final replacement = _idCounter.toString().padLeft(length, '0');
        _idMapping[original] = replacement;
        _idCounter++;
        return replacement;

      case 'DATE':
        if (_dateMapping.containsKey(original)) {
          return _dateMapping[original]!;
        }
        final replacement = 'DD/MM/YYYY';
        _dateMapping[original] = replacement;
        _dateCounter++;
        return replacement;

      case 'PERSON':
        if (_personMapping.containsKey(original)) {
          return _personMapping[original]!;
        }
        final replacement = _personCounter <= _fakeNames.length
            ? _fakeNames[_personCounter - 1]
            : 'Người ${_personCounter}';
        _personMapping[original] = replacement;
        _personCounter++;
        return replacement;

      case 'LOCATION':
        if (_locationMapping.containsKey(original)) {
          return _locationMapping[original]!;
        }
        final replacement = 'Địa điểm ${_locationCounter}';
        _locationMapping[original] = replacement;
        _locationCounter++;
        return replacement;

      default:
        return original;
    }
  }

  Map<String, Map<String, String>> _getMappingInfo() {
    return {
      'person': Map.from(_personMapping),
      'phone': Map.from(_phoneMapping),
      'email': Map.from(_emailMapping),
      'location': Map.from(_locationMapping),
      'id': Map.from(_idMapping),
      'url': Map.from(_urlMapping),
      'date': Map.from(_dateMapping),
    };
  }

  Map<String, int> _getEntityCount() {
    return {
      'person': _personMapping.length,
      'phone': _phoneMapping.length,
      'email': _emailMapping.length,
      'location': _locationMapping.length,
      'id': _idMapping.length,
      'url': _urlMapping.length,
      'date': _dateMapping.length,
    };
  }

  void reset() {
    _personMapping.clear();
    _phoneMapping.clear();
    _emailMapping.clear();
    _locationMapping.clear();
    _idMapping.clear();
    _urlMapping.clear();
    _dateMapping.clear();
    
    _personCounter = 1;
    _phoneCounter = 1;
    _emailCounter = 1;
    _locationCounter = 1;
    _idCounter = 1;
    _urlCounter = 1;
    _dateCounter = 1;
  }
}

class EntityMatch {
  final int start;
  final int end;
  final String original;
  final String type;

  EntityMatch({
    required this.start,
    required this.end,
    required this.original,
    required this.type,
  });
}