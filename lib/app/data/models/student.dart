class Student {
  final String id;
  final String universityId;
  final String fullName;
  final String? deviceNumber;

  Student({
    required this.id,
    required this.universityId,
    required this.fullName,
    this.deviceNumber,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['_id'],
      universityId: json['universityId'],
      fullName: json['fullName'],
      deviceNumber: json['deviceNumber'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'universityId': universityId,
      'fullName': fullName,
    };
  }
}
