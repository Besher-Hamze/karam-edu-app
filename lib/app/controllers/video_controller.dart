import 'dart:async';
import 'dart:io';
import 'package:course_platform/app/controllers/video_download_manager.dart';
import 'package:course_platform/app/data/models/video.dart';
import 'package:course_platform/app/data/repositories/video_repository.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/storage_service.dart';
import '../ui/global_widgets/snackbar.dart';

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
          WakelockPlus.disable();
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
        print('❌ Video file does not exist: $filePath');
        return false;
      }

      // CRITICAL: Check if this is a temp file (should not play temp files)
      if (filePath.endsWith('.tmp')) {
        print('❌ Cannot play temp file: $filePath');
        return false;
      }

      // CRITICAL: Check if file is currently being downloaded
      // Get the video ID from the file path or check download status
      // We'll check this in loadVideo instead to have access to videoId

      // التحقق من حجم الملف (يجب أن يكون أكبر من الحد الأدنى)
      final fileSize = await file.length();
      if (fileSize < 1024 * 10) { // أقل من 10 كيلوبايت يعتبر غير صالح
        print('❌ Video file too small: ${fileSize} bytes');
        return false;
      }

      // CRITICAL: Check if there's a corresponding .tmp file (download in progress)
      final tempFile = File('$filePath.tmp');
      if (await tempFile.exists()) {
        print('⚠️ Temp file exists - download may be in progress: $filePath.tmp');
        // Don't consider it valid if temp file exists (download not complete)
        return false;
      }

      print('✅ Video file validation passed: $filePath (${fileSize / 1024 / 1024} MB)');
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
      _videoMarkedAsWatched = false; // Reset watched flag for new video

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

      // CRITICAL: Check if download is currently in progress or paused
      final downloadStatus = _downloadManager.getDownloadStatusString(videoId);
      final isDownloading = downloadStatus == 'downloading' || downloadStatus == 'paused';
      
      if (isDownloading) {
        print('⚠️ Video is currently downloading or paused, cannot play local file yet');
        // If downloading, use online playback instead
        if (hasInternet) {
          final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
          if (streamUrl != null) {
            print("Video is downloading, using streaming URL instead");
            await initializeVideoPlayer(streamUrl, isOffline: false);
            _startHideControlsTimer();
            return;
          }
        }
      }

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

          // Get direct video URL from backend
          final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
          if (streamUrl != null) {
            await initializeVideoPlayer(streamUrl, isOffline: false);
          } else {
            throw Exception('فشل الحصول على رابط الفيديو من الخادم');
          }
        } else if (!initSuccess && !hasInternet) {
          // إذا فشل التشغيل المحلي ولا يوجد اتصال بالإنترنت، حذف الملف التالف أيضًا
          await _handleCorruptedLocalFile(videoId, localFilePath);
          throw Exception('فشل تشغيل الفيديو المحلي ولا يوجد اتصال بالإنترنت');
        }
      } else if (hasInternet) {
        // لا يوجد نسخة محلية صالحة ولكن يوجد اتصال بالإنترنت
        // Get direct video URL from backend
        final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
        if (streamUrl != null) {
          print("Using streaming URL: $streamUrl");
          await initializeVideoPlayer(streamUrl, isOffline: false);
        } else {
          throw Exception('فشل الحصول على رابط الفيديو من الخادم');
        }

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
        final String? streamUrl = await _videoRepository.getVideoUrl(currentVideo.value!.id);
        if (streamUrl != null) {
          await initializeVideoPlayer(streamUrl, isOffline: false);
        }
      } else {
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'خطأ: فشل تحميل الفيديو. تأكد من اتصالك بالإنترنت أو قم بتنزيل الفيديو للمشاهدة دون اتصال.',
            type: SnackBarType.error,
            duration: Duration(seconds: 5),
          );
        }
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
      await _downloadManager.deleteDownloadedVideo(videoId);
      print("Removed video from downloads list: $videoId");

      // عرض رسالة للمستخدم
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'ملف تالف: تم اكتشاف مشكلة في الفيديو المحمل وتم حذفه. يمكنك إعادة تحميله لاحقاً.',
          type: SnackBarType.warning,
          duration: Duration(seconds: 3),
        );
      }
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
        // For online mode, use the direct URL (no need to add auth header as it's a signed URL)
        videoPlayerController.value = VideoPlayerController.network(videoPath);
        isOfflineMode.value = false;
      }

      // Initialize player with timeout
      await videoPlayerController.value!.initialize().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timeout');
        },
      );

      // CRITICAL: Additional validation - check if video has valid duration
      final duration = videoPlayerController.value!.value.duration;
      if (duration == Duration.zero || duration.inSeconds < 1) {
        throw Exception('Video has invalid duration: $duration');
      }

      // Set up listeners
      videoPlayerController.value!.addListener(_videoPlayerListener);

      // Auto-play
      await videoPlayerController.value!.play();
      isPlaying.value = true;
      isVideoInitialized.value = true;

      // تعيين سرعة التشغيل (للتأكد من استخدام السرعة الصحيحة إذا تم تغييرها سابقاً)
      await videoPlayerController.value!.setPlaybackSpeed(playbackSpeed.value);

      // Enable wakelock to keep screen on
      WakelockPlus.enable();

      return true; // تهيئة ناجحة
    } catch (e) {
      print('Error initializing video player: $e');
      print('Error details: ${e.toString()}');
      isVideoInitialized.value = false;

      // إذا كان الخطأ في وضع عدم الاتصال، تحقق أولاً إذا كان التنزيل قيد التنفيذ
      if (isOffline && _currentLocalFilePath != null && currentVideo.value != null) {
        final videoId = currentVideo.value!.id;
        
        // CRITICAL: Check if download is in progress before deleting
        final downloadStatus = _downloadManager.getDownloadStatusString(videoId);
        final isDownloading = downloadStatus == 'downloading' || downloadStatus == 'paused';
        
        if (isDownloading) {
          print('⚠️ Download in progress, file may not be complete yet. Trying online playback instead.');
          // Don't delete file if download is in progress - it might just be incomplete
          if (await _hasInternetConnection() && !hasTriedOnlineFallback.value) {
            hasTriedOnlineFallback.value = true;
            print("Local playback failed (download in progress), trying online playback");
            final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
            if (streamUrl != null) {
              return await initializeVideoPlayer(streamUrl, isOffline: false);
            }
          }
          return false;
        }
        
        // Check if file is a temp file
        if (_currentLocalFilePath!.endsWith('.tmp')) {
          print('⚠️ Trying to play temp file, switching to online playback');
          if (await _hasInternetConnection() && !hasTriedOnlineFallback.value) {
            hasTriedOnlineFallback.value = true;
            final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
            if (streamUrl != null) {
              return await initializeVideoPlayer(streamUrl, isOffline: false);
            }
          }
          return false;
        }
        
        // Only delete if download is complete and file is truly corrupted
        // Give it one more chance - wait a bit and retry
        print('⚠️ Local file failed to play, waiting and retrying once...');
        await Future.delayed(Duration(milliseconds: 500));
        
        try {
          // Try to reinitialize
          if (videoPlayerController.value != null) {
            await videoPlayerController.value!.dispose();
            videoPlayerController.value = null;
          }
          
          videoPlayerController.value = VideoPlayerController.file(File(_currentLocalFilePath!));
          await videoPlayerController.value!.initialize();
          
          final duration = videoPlayerController.value!.value.duration;
          if (duration != Duration.zero && duration.inSeconds >= 1) {
            // Success on retry
            videoPlayerController.value!.addListener(_videoPlayerListener);
            await videoPlayerController.value!.play();
            isPlaying.value = true;
            isVideoInitialized.value = true;
            await videoPlayerController.value!.setPlaybackSpeed(playbackSpeed.value);
            WakelockPlus.enable();
            return true;
          }
        } catch (retryError) {
          print('Retry also failed: $retryError');
        }
        
        // If retry failed, then consider it corrupted
        print('❌ File appears to be corrupted after retry, deleting...');
        await _handleCorruptedLocalFile(videoId, _currentLocalFilePath!);

        // محاولة تشغيل الفيديو عبر الإنترنت إذا كان متاحًا
        if (await _hasInternetConnection() && !hasTriedOnlineFallback.value) {
          hasTriedOnlineFallback.value = true;
          print("Local playback failed, trying online playback");
          final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
          if (streamUrl != null) {
            return await initializeVideoPlayer(streamUrl, isOffline: false);
          }
          return false;
        }
      }

      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: فشل تشغيل الفيديو',
          type: SnackBarType.error,
        );
      }
      return false; // تهيئة فاشلة
    }
  }


  RxBool hasShownZoomHint = false.obs;

// دالة لتعيين حالة عرض تلميح الزوم
  void setZoomHintShown() {
    hasShownZoomHint.value = true;
  }

  // Variable to track if video was already marked as watched
  bool _videoMarkedAsWatched = false;

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

      // Check if video ended (mark as watched if at least 95% completed)
      if (duration.inMilliseconds > 0 && !_videoMarkedAsWatched) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        // Mark as watched if video is at least 95% complete or reached the end
        if (progress >= 0.95 || position.inMilliseconds >= duration.inMilliseconds - 1000) {
          _markVideoAsWatched();
        }
      }

      // Check if video ended
      if (position.inMilliseconds >= duration.inMilliseconds && !isBuffering.value) {
        // Show controls when video ends
        controlsVisible.value = true;

        // Disable wakelock when video ends
        WakelockPlus.disable();
      }
    }
  }

  // Mark video as watched in storage
  Future<void> _markVideoAsWatched() async {
    if (currentVideo.value != null && !_videoMarkedAsWatched) {
      _videoMarkedAsWatched = true;
      await _storageService.addVideoToWatchedList(currentVideo.value!.id);
      print('✅ Video marked as watched: ${currentVideo.value!.id}');
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

      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'جاري التبديل للمشاهدة عبر الإنترنت: حدث خطأ في تشغيل الفيديو المحلي',
          type: SnackBarType.info,
          duration: Duration(seconds: 2),
        );
      }

      final String? streamUrl = await _videoRepository.getVideoUrl(currentVideo.value!.id);
      if (streamUrl != null) {
        await initializeVideoPlayer(streamUrl, isOffline: false);
      }
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
        WakelockPlus.disable();
      } else {
        videoPlayerController.value!.play();
        // Enable wakelock when playing
        WakelockPlus.enable();
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
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'تم تغيير السرعة: سرعة التشغيل: ${speed == 1.0 ? "طبيعية" : "x" + speed.toStringAsFixed(1)}',
            type: SnackBarType.info,
            duration: Duration(seconds: 1),
          );
        }

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

  // Skip forward 10 seconds
  void skipForward() {
    if (videoPlayerController.value != null) {
      final Duration currentPosition = videoPlayerController.value!.value.position;
      final Duration duration = videoPlayerController.value!.value.duration;
      final Duration newPosition = currentPosition + Duration(seconds: 10);
      
      // Don't skip past the end
      if (newPosition < duration) {
        seekTo(newPosition);
      } else {
        seekTo(duration);
      }
    }
  }

  // Skip backward 10 seconds
  void skipBackward() {
    if (videoPlayerController.value != null) {
      final Duration currentPosition = videoPlayerController.value!.value.position;
      final Duration newPosition = currentPosition - Duration(seconds: 10);
      
      // Don't skip before the beginning
      if (newPosition > Duration.zero) {
        seekTo(newPosition);
      } else {
        seekTo(Duration.zero);
      }
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
    WakelockPlus.disable();

    super.onClose();
  }
}