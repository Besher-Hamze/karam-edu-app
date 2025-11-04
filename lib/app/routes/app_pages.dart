import 'package:course_platform/app/bindings/video_binding.dart';
import 'package:get/get.dart';
import '../bindings/auth_binding.dart';
import '../bindings/home_binding.dart';
import '../bindings/course_binding.dart';
import '../bindings/profile_binding.dart';
import '../ui/screens/pdf/pdf_viewer_screen.dart';
import '../ui/screens/splash/splash_screen.dart';
import '../ui/screens/auth/login_screen.dart';
import '../ui/screens/auth/register_screen.dart';
import '../ui/screens/home/home_screen.dart';
import '../ui/screens/courses/course_detail_screen.dart';
import '../ui/screens/video/video_player_screen.dart';
import '../ui/screens/profile/profile_screen.dart';
import '../ui/screens/qr/qr_scanner_screen.dart';


class AppPages {
  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => SplashScreen(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => LoginScreen(),
      binding: AuthBinding(),
    ),
    GetPage(
      name: Routes.REGISTER,  // Add register route
      page: () => RegisterScreen(),
      binding: AuthBinding(),  // Reuse the same binding as login
    ),
    GetPage(
      name: Routes.HOME,
      page: () => HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: Routes.COURSE_DETAIL,
      page: () => CourseDetailScreen(),
      binding: CourseBinding(),
    ),
    GetPage(
        name: Routes.VIDEO_PLAYER,
        page: () => VideoPlayerScreen(),
        binding: VideoBinding()
    ),
    GetPage(
      name: Routes.PROFILE,
      page: () => ProfileScreen(),
      binding: ProfileBinding(),
    ),
    GetPage(
      name: Routes.PDF_VIEWER,
      page: () => PdfViewerScreen(filePath: Get.arguments['filePath']),
    ),
    GetPage(
      name: Routes.QR_SCANNER,
      page: () => QrScannerScreen(),
    ),

  ];
}


abstract class Routes {
  static const SPLASH = '/splash';
  static const LOGIN = '/login';
  static const REGISTER = '/register';
  static const HOME = '/home';
  static const COURSE_DETAIL = '/course-detail';
  static const VIDEO_PLAYER = '/video-player';
  static const PROFILE = '/profile';
  static const PDF_VIEWER = '/pdf-viewer';
  static const QR_SCANNER = '/qr-scanner';

}