import 'dart:async';
import 'dart:io';
import 'package:course_platform/app/controllers/video_download_manager.dart';
import 'package:course_platform/app/data/models/video.dart';
import 'package:course_platform/app/data/repositories/video_repository.dart';
import 'package:course_platform/app/services/network_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock/wakelock.dart';

import '../services/storage_service.dart';
import '../ui/theme/color_theme.dart';

class VideoController extends GetxController {
  final VideoRepository _videoRepository;
  final VideoDownloadManager _downloadManager = Get.find<VideoDownloadManager>();

  VideoController({required VideoRepository videoRepository})
      : _videoRepository = videoRepository;

  Rx<Video?> currentVideo = Rx<Video?>(null);
  Rx<VideoPlayerController?> videoPlayerController = Rx<VideoPlayerController?>(null);
  RxBool isVideoInitialized = false.obs;
  RxBool isPlaying = false.obs;
  RxBool isLoading = true.obs;
  RxBool isBuffering = false.obs;
  RxDouble videoProgress = 0.0.obs;
  RxBool controlsVisible = true.obs;
  RxBool isOfflineMode = false.obs;
  final StorageService _storageService = Get.find<StorageService>();
  Timer? _hideControlsTimer;
  RxBool hasTriedOnlineFallback = false.obs;

  // إضافة متغير لتتبع سرعة التشغيل
  RxDouble playbackSpeed = 1.0.obs;

  // إضافة متغير لتتبع الملف المحلي الحالي
  String? _currentLocalFilePath;

  @override
  void onInit() {
    super.onInit();
    final String? videoId = Get.parameters['videoId'];
    if (videoId != null) {
      loadVideo(videoId);
    }

    // Hide system UI (navigation and status bars)
    _setFullScreen(true);

    SystemChannels.lifecycle.setMessageHandler((message) {
      if (message == 'AppLifecycleState.paused') {
        if (isPlaying.value) {
          playPause();
          Wakelock.disable();
        }
      } else if (message == 'AppLifecycleState.resumed') {
        _setFullScreen(true);
      }
      return Future.value(message);
    });
  }

  // Set full screen mode
  void _setFullScreen(bool enabled) {
    if (enabled) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [], // Hide both status bar and navigation bar
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values, // Show all system UI
      );
    }
  }

  // التحقق من صلاحية ملف الفيديو المحلي
  Future<bool> _isValidVideoFile(String filePath) async {
    try {
      final file = File(filePath);

      // التحقق من وجود الملف
      if (!await file.exists()) {
        return false;
      }

      // التحقق من حجم الملف (يجب أن يكون أكبر من الحد الأدنى)
      final fileSize = await file.length();
      if (fileSize < 1024 * 10) { // أقل من 10 كيلوبايت يعتبر غير صالح
        return false;
      }

      return true;
    } catch (e) {
      print('Error validating video file: $e');
      return false;
    }
  }

  Future<void> loadVideo(String videoId) async {
    try {
      isLoading.value = true;
      isVideoInitialized.value = false;
      hasTriedOnlineFallback.value = false;
      _currentLocalFilePath = null; // إعادة تعيين مسار الملف المحلي

      // إعادة تعيين سرعة التشغيل إلى الوضع الطبيعي عند تحميل فيديو جديد
      playbackSpeed.value = 1.0;

      // الحصول على تفاصيل الفيديو
      final video = await _videoRepository.getVideoDetails(videoId);
      currentVideo.value = video;

      if (video == null) {
        throw Exception('فشل في الحصول على تفاصيل الفيديو');
      }

      // التحقق من وجود اتصال بالإنترنت أولاً
      final hasInternet = await _hasInternetConnection();

      // التحقق من وجود الفيديو محلياً
      final isDownloaded = await _downloadManager.isVideoDownloaded(videoId);
      final String? localFilePath = isDownloaded ?
      await _downloadManager.getLocalVideoPath(videoId) : null;

      // التحقق من صلاحية الملف المحلي
      final bool isValidLocalFile = localFilePath != null &&
          await _isValidVideoFile(localFilePath);

      if (isValidLocalFile) {
        print("Loading offline video from: $localFilePath");
        _currentLocalFilePath = localFilePath; // حفظ مسار الملف المحلي
        final initSuccess = await initializeVideoPlayer(localFilePath, isOffline: true);

        // إذا فشل تشغيل الفيديو محلياً وكان هناك اتصال بالإنترنت، جرب التشغيل عبر الإنترنت
        if (!initSuccess && hasInternet) {
          print("Offline playback failed, switching to online mode");
          // حذف الفيديو المحلي التالف
          await _handleCorruptedLocalFile(videoId, localFilePath);

          final streamUrl = Get.find<NetworkService>().getVideoStreamUrl(videoId);
          await initializeVideoPlayer(streamUrl, isOffline: false);
        } else if (!initSuccess && !hasInternet) {
          // إذا فشل التشغيل المحلي ولا يوجد اتصال بالإنترنت، حذف الملف التالف أيضًا
          await _handleCorruptedLocalFile(videoId, localFilePath);
          throw Exception('فشل تشغيل الفيديو المحلي ولا يوجد اتصال بالإنترنت');
        }
      } else if (hasInternet) {
        // لا يوجد نسخة محلية صالحة ولكن يوجد اتصال بالإنترنت
        final streamUrl = Get.find<NetworkService>().getVideoStreamUrl(videoId);
        print("Using streaming URL: $streamUrl");
        await initializeVideoPlayer(streamUrl, isOffline: false);

        // إذا كان الفيديو في قائمة التنزيلات ولكن غير صالح، قم بإزالته
        if (isDownloaded && localFilePath != null && !isValidLocalFile) {
          print("Removing invalid local file: $localFilePath");
          await _downloadManager.deleteDownloadedVideo(videoId);
        }
      } else {
        // لا يوجد نسخة محلية صالحة ولا يوجد اتصال بالإنترنت
        throw Exception('لا يوجد اتصال بالإنترنت والفيديو غير متوفر للمشاهدة دون اتصال');
      }

      _startHideControlsTimer();
    } catch (e) {
      print('Error loading video: $e');

      // محاولة التشغيل عبر الإنترنت كخيار أخير إذا لم نجرب بعد ويوجد اتصال بالإنترنت
      if (!hasTriedOnlineFallback.value && currentVideo.value != null && await _hasInternetConnection()) {
        hasTriedOnlineFallback.value = true;
        print("Trying online fallback as last resort");
        final streamUrl = Get.find<NetworkService>().getVideoStreamUrl(currentVideo.value!.id);
        await initializeVideoPlayer(streamUrl, isOffline: false);
      } else {
        Get.snackbar(
          'خطأ',
          'فشل تحميل الفيديو. تأكد من اتصالك بالإنترنت أو قم بتنزيل الفيديو للمشاهدة دون اتصال.',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 5),
        );
      }
    } finally {
      isLoading.value = false;
    }
  }

  // دالة جديدة للتعامل مع ملفات الفيديو المحلية التالفة
  Future<void> _handleCorruptedLocalFile(String videoId, String filePath) async {
    try {
      print("Handling corrupted local file: $filePath");
      // حذف الملف من نظام الملفات
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print("Deleted corrupted file from filesystem: $filePath");
      }

      // حذف الفيديو من قائمة التنزيلات
      await _downloadManager.deleteDownload(videoId);
      print("Removed video from downloads list: $videoId");

      // عرض رسالة للمستخدم
      Get.snackbar(
        'ملف تالف',
        'تم اكتشاف مشكلة في الفيديو المحمل وتم حذفه. يمكنك إعادة تحميله لاحقاً.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.7),
        colorText: Colors.white,
        duration: Duration(seconds: 3),
      );
    } catch (e) {
      print("Error handling corrupted file: $e");
    }
  }

  // Helper method to check internet connectivity
  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  // Optionally track offline views for analytics
  void _trackOfflineView(String videoId) {
    print("OFFFLINE");
  }

  Future<bool> initializeVideoPlayer(String videoPath, {bool isOffline = false}) async {
    // Dispose previous controller if exists
    if (videoPlayerController.value != null) {
      await videoPlayerController.value!.dispose();
      videoPlayerController.value = null;
    }

    try {
      if (isOffline) {
        videoPlayerController.value = VideoPlayerController.file(File(videoPath));
        isOfflineMode.value = true;
      } else {
        final token = _storageService.getToken();
        videoPlayerController.value = VideoPlayerController.network(
            videoPath,
            httpHeaders: {
              'Authorization': 'Bearer $token',
            }
        );
        isOfflineMode.value = false;
      }

      // Initialize player
      await videoPlayerController.value!.initialize();

      // Set up listeners
      videoPlayerController.value!.addListener(_videoPlayerListener);

      // Auto-play
      await videoPlayerController.value!.play();
      isPlaying.value = true;
      isVideoInitialized.value = true;

      // تعيين سرعة التشغيل (للتأكد من استخدام السرعة الصحيحة إذا تم تغييرها سابقاً)
      await videoPlayerController.value!.setPlaybackSpeed(playbackSpeed.value);

      // Enable wakelock to keep screen on
      Wakelock.enable();

      return true; // تهيئة ناجحة
    } catch (e) {
      print('Error initializing video player: $e');
      isVideoInitialized.value = false;

      // إذا كان الخطأ في وضع عدم الاتصال، اعتبر الملف تالفًا
      if (isOffline && _currentLocalFilePath != null && currentVideo.value != null) {
        // حذف الملف التالف
        await _handleCorruptedLocalFile(currentVideo.value!.id, _currentLocalFilePath!);

        // محاولة تشغيل الفيديو عبر الإنترنت إذا كان متاحًا
        if (await _hasInternetConnection() && !hasTriedOnlineFallback.value) {
          hasTriedOnlineFallback.value = true;
          print("Local playback failed, trying online playback");
          final streamUrl = Get.find<NetworkService>().getVideoStreamUrl(currentVideo.value!.id);
          return await initializeVideoPlayer(streamUrl, isOffline: false);
        }
      }

      Get.snackbar(
        'خطأ',
        'فشل تشغيل الفيديو',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false; // تهيئة فاشلة
    }
  }


  RxBool hasShownZoomHint = false.obs;

// دالة لتعيين حالة عرض تلميح الزوم
  void setZoomHintShown() {
    hasShownZoomHint.value = true;
  }

  // Video player listener
  void _videoPlayerListener() {
    if (videoPlayerController.value != null) {
      // Update progress
      final Duration position = videoPlayerController.value!.value.position;
      final Duration duration = videoPlayerController.value!.value.duration;

      if (duration.inMilliseconds > 0) {
        videoProgress.value = position.inMilliseconds / duration.inMilliseconds;
      }

      // Update playing state
      isPlaying.value = videoPlayerController.value!.value.isPlaying;

      // Update buffering state
      isBuffering.value = videoPlayerController.value!.value.isBuffering;

      // التعامل مع أخطاء التشغيل أثناء المشاهدة
      if (videoPlayerController.value!.value.hasError && !hasTriedOnlineFallback.value) {
        _handlePlaybackError();
      }

      // Check if video ended
      if (position.inMilliseconds >= duration.inMilliseconds && !isBuffering.value) {
        // Show controls when video ends
        controlsVisible.value = true;

        // Disable wakelock when video ends
        Wakelock.disable();
      }
    }
  }

  // دالة جديدة للتعامل مع أخطاء التشغيل
  void _handlePlaybackError() async {
    if (isOfflineMode.value && await _hasInternetConnection() && currentVideo.value != null) {
      hasTriedOnlineFallback.value = true;
      print("Playback error detected, switching to online mode");

      // حذف الملف المحلي التالف إذا كنا في وضع عدم الاتصال
      if (_currentLocalFilePath != null) {
        await _handleCorruptedLocalFile(currentVideo.value!.id, _currentLocalFilePath!);
      }

      Get.snackbar(
          'جاري التبديل للمشاهدة عبر الإنترنت',
          'حدث خطأ في تشغيل الفيديو المحلي',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 2),
          colorText: Colors.white
      );

      final streamUrl = Get.find<NetworkService>().getVideoStreamUrl(currentVideo.value!.id);
      await initializeVideoPlayer(streamUrl, isOffline: false);
    } else if (isOfflineMode.value && currentVideo.value != null && _currentLocalFilePath != null) {
      // إذا لم يكن هناك اتصال بالإنترنت، احذف الملف التالف فقط
      await _handleCorruptedLocalFile(currentVideo.value!.id, _currentLocalFilePath!);
    }
  }

  // Play/pause toggle
  void playPause() {
    if (videoPlayerController.value != null) {
      if (isPlaying.value) {
        videoPlayerController.value!.pause();
        // Disable wakelock when paused
        Wakelock.disable();
      } else {
        videoPlayerController.value!.play();
        // Enable wakelock when playing
        Wakelock.enable();
        _startHideControlsTimer();
      }
    }
  }

  // دالة لتغيير سرعة تشغيل الفيديو
  Future<void> setPlaybackSpeed(double speed) async {
    if (videoPlayerController.value != null) {
      try {
        await videoPlayerController.value!.setPlaybackSpeed(speed);
        playbackSpeed.value = speed;

        // إظهار رسالة تأكيد للمستخدم
        Get.snackbar(
          'تم تغيير السرعة',
          'سرعة التشغيل: ${speed == 1.0 ? "طبيعية" : "x" + speed.toStringAsFixed(1)}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: ColorTheme.primary.withOpacity(0.7),
          colorText: Colors.white,
          duration: Duration(seconds: 1),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          margin: EdgeInsets.only(bottom: 20, left: 50, right: 50),
          borderRadius: 10,
        );

        // إبقاء عناصر التحكم ظاهرة لبعض الوقت
        _startHideControlsTimer();
      } catch (e) {
        print('Error setting playback speed: $e');
      }
    }
  }

  // Seek to position
  void seekTo(Duration position) {
    if (videoPlayerController.value != null) {
      videoPlayerController.value!.seekTo(position);
      _startHideControlsTimer();
    }
  }

  // Seek based on progress percentage
  void seekToProgress(double progress) {
    if (videoPlayerController.value != null) {
      final Duration duration = videoPlayerController.value!.value.duration;
      final int milliseconds = (progress * duration.inMilliseconds).round();
      seekTo(Duration(milliseconds: milliseconds));
    }
  }

  // Toggle controls visibility
  void toggleControlsVisibility() {
    controlsVisible.value = !controlsVisible.value;
    if (controlsVisible.value) {
      _startHideControlsTimer();
    } else {
      _cancelHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _cancelHideControlsTimer();
    _hideControlsTimer = Timer(Duration(seconds: 3), () {
      controlsVisible.value = false;
    });
  }

  void _cancelHideControlsTimer() {
    if (_hideControlsTimer != null) {
      _hideControlsTimer!.cancel();
      _hideControlsTimer = null;
    }
  }

  @override
  void onClose() {
    _cancelHideControlsTimer();
    if (videoPlayerController.value != null) {
      videoPlayerController.value!.removeListener(_videoPlayerListener);
      videoPlayerController.value!.dispose();
    }

    // Restore system UI and orientation
    _setFullScreen(false);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // Disable wakelock when leaving the video screen
    Wakelock.disable();

    super.onClose();
  }
}