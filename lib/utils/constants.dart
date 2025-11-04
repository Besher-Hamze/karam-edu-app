class AppConstants {
  // الروابط الخاصة بالAPI
  static const String baseUrl = 'http://192.168.0.6:3050'; // للمحاكي، قم بتغييره للجهاز الفعلي

  // مفاتيح التخزين
  static const String tokenKey = 'token';
  static const String studentProfileKey = 'student_profile';
  static const String cachedCoursesKey = 'cached_courses';

  // رسائل الخطأ
  static const String connectionError = 'تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت';
  static const String serverError = 'حدث خطأ في الخادم، الرجاء المحاولة لاحقًا';
  static const String unknownError = 'حدث خطأ غير معروف، الرجاء المحاولة لاحقًا';

  // مدة الجلسة
  static const int sessionTimeout = 60; // بالدقائق
}
