import '../providers/enrollment_provider.dart';

class EnrollmentRepository {
  final EnrollmentProvider _enrollmentProvider;

  EnrollmentRepository({required EnrollmentProvider enrollmentProvider})
      : _enrollmentProvider = enrollmentProvider;

  Future<Map<String, dynamic>> redeemCode(String code) async {
    try {
      final response = await _enrollmentProvider.redeemEnrollmentCode(code);
      return {
        'success': true,
        'message': response.data['message'] ?? 'تم التسجيل بنجاح',
        'data': response.data,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'فشل التحقق من الكود. يرجى المحاولة مرة أخرى',
      };
    }
  }
}

