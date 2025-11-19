import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_windowmanager_plus/flutter_windowmanager_plus.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:safe_device/safe_device.dart';
import 'dart:io';
import 'app/routes/app_pages.dart';
import 'app/ui/theme/app_theme.dart';
import 'app/services/storage_service.dart';
import 'app/services/network_service.dart';
import 'app/controllers/video_download_manager.dart';
import 'app/data/providers/video_provider.dart';
import 'app/data/repositories/video_repository.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  await initServices();
  await FlutterWindowManagerPlus.addFlags(FlutterWindowManagerPlus.FLAG_SECURE);
  List<String> allowDevice = ["SP1A.210812.016"];
  String identifier = '';
  DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
  if (GetPlatform.isAndroid) {
    final androidInfo = await deviceInfo.androidInfo;
    identifier = androidInfo.id ?? ""; // Android device ID
  }
  // Use the comprehensive isSafeDevice check
  bool isSafeDevice = true;
  bool skipChecking= false;
  String securityIssue = "";
  try {
    // First try the comprehensive check
    isSafeDevice = await SafeDevice.isSafeDevice;
    print("============================${identifier}");
    if (allowDevice.contains(identifier)) {
      print("-----------------------------");
      isSafeDevice = true;
      skipChecking=true;
    }
    // If comprehensive check passes, do individual checks for more specific error messages
    if (isSafeDevice) {
      if (await SafeDevice.isJailBroken) {
        isSafeDevice = false;
        securityIssue = "جهاز مكسور الحماية";
      } else if (await SafeDevice.isRealDevice == false) {
        isSafeDevice = false;
        securityIssue = "جهاز وهمي";
      } else if (await SafeDevice.isMockLocation) {
        isSafeDevice = false;
        securityIssue = "الموقع الجغرافي المزيف";
      } else if (Platform.isAndroid && await SafeDevice.isOnExternalStorage) {
        isSafeDevice = false;
        securityIssue = "تخزين خارجي";
      } else if (Platform.isAndroid &&
          await SafeDevice.isDevelopmentModeEnable) {
        isSafeDevice = false;
        securityIssue = "وضع المطور";
      }
    } else {
      securityIssue = "جهاز غير آمن";
    }
  } catch (e) {
    print('Error checking device security: $e');
    // Optional: decide what to do if check fails
    isSafeDevice = false;
    securityIssue = "خطأ في فحص الأمان";
  }

  if (isSafeDevice) {
    runApp(MyApp());
  } else {
    runApp(CompromisedDeviceApp(securityIssue: securityIssue));
  }
}

Future<void> initServices() async {
  await Get.putAsync(() => StorageService().init());
  await Get.putAsync(() => NetworkService().init());
  
  // Register VideoProvider and VideoRepository permanently so VideoDownloadManager
  // can be initialized early for lifecycle handling
  Get.put(VideoProvider(), permanent: true);
  Get.put(VideoRepository(videoProvider: Get.find<VideoProvider>()), permanent: true);
  
  // Register VideoDownloadManager as a permanent service so it's always available
  // for lifecycle handling even when course screen is not open
  Get.put(VideoDownloadManager(), permanent: true);
}

// Regular app
class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Get the download manager instance
    if (Get.isRegistered<VideoDownloadManager>()) {
      final downloadManager = Get.find<VideoDownloadManager>();
      
      if (state == AppLifecycleState.paused) {
        // App went to background - pause active downloads
        print('📱 App went to background - pausing active downloads');
        downloadManager.handleAppPaused();
      } else if (state == AppLifecycleState.resumed) {
        // App returned to foreground - resume paused downloads
        print('📱 App resumed - resuming paused downloads');
        downloadManager.handleAppResumed();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'منصة التعلم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar', 'SA'),
      textDirection: TextDirection.rtl,
      fallbackLocale: const Locale('ar', 'SA'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', 'SA'),
      ],
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}

// App for compromised devices
class CompromisedDeviceApp extends StatelessWidget {
  final String securityIssue;

  const CompromisedDeviceApp({Key? key, required this.securityIssue})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'منصة التعلم',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar', 'SA'),
      textDirection: TextDirection.rtl,
      home: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color(0xFF00B0FF), // Your brand blue
                Color(0xFF001F33), // Your navy
              ],
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.security,
                        size: 72,
                        color: Colors.red,
                      ),
                      SizedBox(height: 24),
                      Text(
                        'تنبيه أمان',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'لا يمكن تشغيل التطبيق لأسباب أمنية:',
                        style: TextStyle(fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        securityIssue,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'يرجى استخدام جهاز آمن لتشغيل التطبيق.',
                        style: TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 32),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF00B0FF),
                          padding: EdgeInsets.symmetric(
                              horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'إغلاق التطبيق',
                          style: TextStyle(fontSize: 18),
                        ),
                        onPressed: () => exit(0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
