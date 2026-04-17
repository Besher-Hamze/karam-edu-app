class Course {
  static const String defaultTeacherName = 'كرم غريب';

  /// When API sends [fullName] equal to this, UI shows [defaultTeacherName].
  static const String apiPlatformOwnerFullName = 'Platform Owner';

  final String id;
  final String name;
  final String description;
  final int yearLevel;
  final int semester;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool? isAvailable;
  /// May be omitted by the API; use [displayTeacherName] for UI.
  final String? teacherName;

  Course(
      {required this.id,
      required this.name,
      required this.description,
      required this.yearLevel,
      required this.semester,
      this.createdAt,
      this.updatedAt,
      this.isAvailable,
      this.teacherName});

  /// Teacher label for UI: [teacherName] when set, except [apiPlatformOwnerFullName] → [defaultTeacherName].
  String get displayTeacherName {
    final t = teacherName?.trim();
    if (t == null || t.isEmpty) return defaultTeacherName;
    if (t == apiPlatformOwnerFullName) return defaultTeacherName;
    return t;
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['_id'],
      name: json['name'],
      description: json['description'] ?? '',
      yearLevel: json['yearLevel'],
      semester: json['semester'],
      createdAt:
          json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt:
          json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isAvailable: json['isAvailable'] != null ? json['isAvailable'] : false,
      teacherName: _parseTeacherFromJson(json['teacherName']),
    );
  }

  /// API may send `teacherName` as a string or `{ "fullName": "..." , ... }`.
  static String? _parseTeacherFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    if (value is Map) {
      final dynamic fn = value['fullName'] ?? value['name'];
      if (fn == null) return null;
      final t = fn.toString().trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'yearLevel': yearLevel,
      'semester': semester,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isAvailable': isAvailable ?? false,
      if (teacherName != null) 'teacherName': teacherName,
    };
  }
}
