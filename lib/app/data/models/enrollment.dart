import 'package:course_platform/app/data/models/course.dart';

class Enrollment {
  final String id;
  final String student;
  final String course;
  final DateTime enrollDate;
  final bool isActive;

  final dynamic courseDetails;

  Enrollment({
    required this.id,
    required this.student,
    required this.course,
    required this.enrollDate,
    required this.isActive,
    this.courseDetails,
  });

  factory Enrollment.fromJson(Map<String, dynamic> json) {
    return Enrollment(
      id: json['_id'],
      student: json['student'],
      course: json['course'],
      enrollDate: DateTime.parse(json['enrollDate']),
      isActive: json['isActive'],
      courseDetails: json['course'] is Map ? Course.fromJson(json['course']) : null,
    );
  }
}
