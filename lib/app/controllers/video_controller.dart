import 'dart:async';
import 'dart:io';
import 'package:course_platform/app/controllers/video_download_manager.dart';
import 'package:course_platform/app/data/models/video.dart';
import 'package:course_platform/app/data/repositories/video_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../services/storage_service.dart';
import '../services/network_service.dart';
import '../ui/global_widgets/snackbar.dart';

class VideoController extends GetxController {
  final VideoRepository _videoRepository;
  final VideoDownloadManager _downloadManager =
      Get.find<VideoDownloadManager>();

  VideoController({required VideoRepository videoRepository})
      : _videoRepository = videoRepository;

  Rx<Video?> currentVideo = Rx<Video?>(null);
  Rx<BetterPlayerController?> betterPlayerController =
      Rx<BetterPlayerController?>(null);
  RxBool isVideoInitialized = false.obs;
  RxBool isPlaying = false.obs;
  RxBool isLoading = true.obs;
  RxBool isBuffering = false.obs;
  RxDouble videoProgress = 0.0.obs;
  RxBool controlsVisible = true.obs;
  RxBool isOfflineMode = false.obs;
  final StorageService _storageService = Get.find<StorageService>();
  final NetworkService _networkService = Get.find<NetworkService>();
  Timer? _hideControlsTimer;
  RxBool hasTriedOnlineFallback = false.obs;

  RxDouble playbackSpeed = 1.0.obs;
  String? _currentLocalFilePath;
  StreamSubscription? _playerEventSubscription;

  @override
  void onInit() {
    super.onInit();
    final String? videoId = Get.parameters['videoId'];
    if (videoId != null) {
      loadVideo(videoId);
    }

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

  void _setFullScreen(bool enabled) {
    if (enabled) {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.immersiveSticky,
        overlays: [],
      );
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
  }

  Future<bool> _isValidVideoFile(String filePath) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        print('❌ Video file does not exist: $filePath');
        return false;
      }

      if (filePath.endsWith('.tmp')) {
        print('❌ Cannot play temp file: $filePath');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize < 1024 * 10) {
        print('❌ Video file too small: ${fileSize} bytes');
        return false;
      }

      final tempFile = File('$filePath.tmp');
      if (await tempFile.exists()) {
        print(
            '⚠️ Temp file exists - download may be in progress: $filePath.tmp');
        return false;
      }

      print(
          '✅ Video file validation passed: $filePath (${fileSize / 1024 / 1024} MB)');
      return true;
    } catch (e) {
      print('Error validating video file: $e');
      return false;
    }
  }

  bool _isCachePath(String path) {
    return path.contains('/cache/') || path.contains('\\cache\\');
  }

  String _extractFileName(String path) {
    final segments = path.split(RegExp(r'[\\/]+'));
    if (segments.isNotEmpty && segments.last.isNotEmpty) {
      return segments.last;
    }
    return 'video_${DateTime.now().millisecondsSinceEpoch}.data';
  }

  Future<String?> _ensurePersistentLocalFile(
      String videoId, String? savedPath) async {
    if (savedPath == null || savedPath.isEmpty) {
      return savedPath;
    }

    if (!_isCachePath(savedPath)) {
      return savedPath;
    }

    final cachedFile = File(savedPath);
    if (!await cachedFile.exists()) {
      return savedPath;
    }

    try {
      final persistentDir = await _networkService.getPersistentVideoDirectory();
      String targetPath =
          '${persistentDir.path}/${_extractFileName(savedPath)}';

      if (targetPath == savedPath) {
        return savedPath;
      }

      if (await File(targetPath).exists()) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        targetPath = '${persistentDir.path}/${videoId}_$timestamp.data';
      }

      try {
        await cachedFile.rename(targetPath);
      } catch (e) {
        await cachedFile.copy(targetPath);
        await cachedFile.delete();
      }

      final tempFile = File('$savedPath.tmp');
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      await _storageService.saveVideoPath(videoId, targetPath);
      print('♻️ Migrated cached video to persistent storage: $targetPath');
      return targetPath;
    } catch (e) {
      print('Error migrating video file for $videoId: $e');
      return savedPath;
    }
  }

  Future<void> loadVideo(String videoId) async {
    try {
      isLoading.value = true;
      isVideoInitialized.value = false;
      hasTriedOnlineFallback.value = false;
      _currentLocalFilePath = null;
      _videoMarkedAsWatched = false;

      playbackSpeed.value = 1.0;

      final video = await _videoRepository.getVideoDetails(videoId);
      currentVideo.value = video;

      if (video == null) {
        throw Exception('فشل في الحصول على تفاصيل الفيديو');
      }

      final hasInternet = await _hasInternetConnection();

      final isDownloaded = await _downloadManager.isVideoDownloaded(videoId);
      String? localFilePath = isDownloaded
          ? await _downloadManager.getLocalVideoPath(videoId)
          : null;
      localFilePath = await _ensurePersistentLocalFile(videoId, localFilePath);

      final downloadStatus = _downloadManager.getDownloadStatusString(videoId);
      final isDownloading =
          downloadStatus == 'downloading' || downloadStatus == 'paused';

      if (isDownloading) {
        print(
            '⚠️ Video is currently downloading or paused, cannot play local file yet');
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

      final bool isValidLocalFile =
          localFilePath != null && await _isValidVideoFile(localFilePath);

      if (isValidLocalFile) {
        print("Loading offline video from: $localFilePath");
        _currentLocalFilePath = localFilePath;
        final initSuccess =
            await initializeVideoPlayer(localFilePath, isOffline: true);

        if (!initSuccess && hasInternet) {
          print("Offline playback failed, switching to online mode");
          await _handleCorruptedLocalFile(videoId, localFilePath);

          final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
          if (streamUrl != null) {
            await initializeVideoPlayer(streamUrl, isOffline: false);
          } else {
            throw Exception('فشل الحصول على رابط الفيديو من الخادم');
          }
        } else if (!initSuccess && !hasInternet) {
          await _handleCorruptedLocalFile(videoId, localFilePath);
          throw Exception('فشل تشغيل الفيديو المحلي ولا يوجد اتصال بالإنترنت');
        }
      } else if (hasInternet) {
        final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
        if (streamUrl != null) {
          print("Using streaming URL: $streamUrl");
          await initializeVideoPlayer(streamUrl, isOffline: false);
        } else {
          throw Exception('فشل الحصول على رابط الفيديو من الخادم');
        }

        if (isDownloaded && localFilePath != null && !isValidLocalFile) {
          print("Removing invalid local file: $localFilePath");
          await _downloadManager.deleteDownloadedVideo(videoId);
        }
      } else {
        throw Exception(
            'لا يوجد اتصال بالإنترنت والفيديو غير متوفر للمشاهدة دون اتصال');
      }

      _startHideControlsTimer();
    } catch (e) {
      print('Error loading video: $e');

      if (!hasTriedOnlineFallback.value &&
          currentVideo.value != null &&
          await _hasInternetConnection()) {
        hasTriedOnlineFallback.value = true;
        print("Trying online fallback as last resort");
        final String? streamUrl =
            await _videoRepository.getVideoUrl(currentVideo.value!.id);
        if (streamUrl != null) {
          await initializeVideoPlayer(streamUrl, isOffline: false);
        }
      } else {
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message:
                'خطأ: فشل تحميل الفيديو. تأكد من اتصالك بالإنترنت أو قم بتنزيل الفيديو للمشاهدة دون اتصال.',
            type: SnackBarType.error,
            duration: Duration(seconds: 5),
          );
        }
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _handleCorruptedLocalFile(
      String videoId, String filePath) async {
    try {
      print("Handling corrupted local file: $filePath");
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print("Deleted corrupted file from filesystem: $filePath");
      }

      await _downloadManager.deleteDownloadedVideo(videoId);
      print("Removed video from downloads list: $videoId");

      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message:
              'ملف تالف: تم اكتشاف مشكلة في الفيديو المحمل وتم حذفه. يمكنك إعادة تحميله لاحقاً.',
          type: SnackBarType.warning,
          duration: Duration(seconds: 3),
        );
      }
    } catch (e) {
      print("Error handling corrupted file: $e");
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  Future<bool> initializeVideoPlayer(String videoPath,
      {bool isOffline = false}) async {
    // Dispose previous controller if exists
    if (betterPlayerController.value != null) {
      await _playerEventSubscription?.cancel();
      _playerEventSubscription = null;
      betterPlayerController.value!.dispose();
      betterPlayerController.value = null;
    }

    try {
      BetterPlayerDataSource dataSource;

      if (isOffline) {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          videoPath,
          cacheConfiguration: BetterPlayerCacheConfiguration(
            useCache: false, // Already cached locally
          ),
        );
        isOfflineMode.value = true;
      } else {
        dataSource = BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          videoPath,
          cacheConfiguration: BetterPlayerCacheConfiguration(
            useCache: true,
            maxCacheSize: 100 * 1024 * 1024, // 100 MB cache
            maxCacheFileSize: 50 * 1024 * 1024, // 50 MB per file
          ),
          bufferingConfiguration: BetterPlayerBufferingConfiguration(
            minBufferMs: 2000,
            maxBufferMs: 10000,
            bufferForPlaybackMs: 1000,
            bufferForPlaybackAfterRebufferMs: 2000,
          ),
        );
        isOfflineMode.value = false;
      }

      final betterPlayerConfiguration = BetterPlayerConfiguration(
        autoPlay: true,
        looping: false,
        fullScreenByDefault: false,
        fit: BoxFit.cover,
        aspectRatio: 16 / 9,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: false, // We're using custom controls
        ),
        autoDetectFullscreenDeviceOrientation: true,
        handleLifecycle: true,
        // This helps with MTK devices - forces software decoding when needed
        autoDetectFullscreenAspectRatio: true,
      );

      betterPlayerController.value = BetterPlayerController(
        betterPlayerConfiguration,
        betterPlayerDataSource: dataSource,
      );

      // Wait for initialization with timeout
      await Future.delayed(Duration(milliseconds: 500));

      bool initialized = false;
      final initTimeout = DateTime.now().add(Duration(seconds: 15));

      while (!initialized && DateTime.now().isBefore(initTimeout)) {
        if (betterPlayerController.value?.isVideoInitialized() == true) {
          initialized = true;
          break;
        }
        await Future.delayed(Duration(milliseconds: 100));
      }

      if (!initialized) {
        throw Exception('Video initialization timeout');
      }

      // Validate video duration
      final duration =
          betterPlayerController.value?.videoPlayerController?.value.duration;
      if (duration == null ||
          duration == Duration.zero ||
          duration.inSeconds < 1) {
        throw Exception('Video has invalid duration: $duration');
      }

      // Set up listener
      _setupPlayerListener();

      // Set playback speed
      await betterPlayerController.value?.setSpeed(playbackSpeed.value);

      isPlaying.value = true;
      isVideoInitialized.value = true;

      WakelockPlus.enable();

      return true;
    } catch (e) {
      print('Error initializing video player: $e');
      print('Error details: ${e.toString()}');
      isVideoInitialized.value = false;

      if (isOffline &&
          _currentLocalFilePath != null &&
          currentVideo.value != null) {
        final videoId = currentVideo.value!.id;

        final downloadStatus =
            _downloadManager.getDownloadStatusString(videoId);
        final isDownloading =
            downloadStatus == 'downloading' || downloadStatus == 'paused';

        if (isDownloading) {
          print(
              '⚠️ Download in progress, file may not be complete yet. Trying online playback instead.');
          if (await _hasInternetConnection() && !hasTriedOnlineFallback.value) {
            hasTriedOnlineFallback.value = true;
            print(
                "Local playback failed (download in progress), trying online playback");
            final String? streamUrl =
                await _videoRepository.getVideoUrl(videoId);
            if (streamUrl != null) {
              return await initializeVideoPlayer(streamUrl, isOffline: false);
            }
          }
          return false;
        }

        if (_currentLocalFilePath!.endsWith('.tmp')) {
          print('⚠️ Trying to play temp file, switching to online playback');
          if (await _hasInternetConnection() && !hasTriedOnlineFallback.value) {
            hasTriedOnlineFallback.value = true;
            final String? streamUrl =
                await _videoRepository.getVideoUrl(videoId);
            if (streamUrl != null) {
              return await initializeVideoPlayer(streamUrl, isOffline: false);
            }
          }
          return false;
        }

        print('⚠️ Local file failed to play, waiting and retrying once...');
        await Future.delayed(Duration(milliseconds: 500));

        try {
          if (betterPlayerController.value != null) {
            await _playerEventSubscription?.cancel();
            betterPlayerController.value!.dispose();
            betterPlayerController.value = null;
          }

          final retryDataSource = BetterPlayerDataSource(
            BetterPlayerDataSourceType.file,
            _currentLocalFilePath!,
          );

          final retryConfiguration = BetterPlayerConfiguration(
            autoPlay: true,
            looping: false,
            controlsConfiguration: BetterPlayerControlsConfiguration(
              showControls: false,
            ),
          );

          betterPlayerController.value = BetterPlayerController(
            retryConfiguration,
            betterPlayerDataSource: retryDataSource,
          );

          await Future.delayed(Duration(milliseconds: 500));

          if (betterPlayerController.value?.isVideoInitialized() == true) {
            final duration = betterPlayerController
                .value?.videoPlayerController?.value.duration;
            if (duration != null &&
                duration != Duration.zero &&
                duration.inSeconds >= 1) {
              _setupPlayerListener();
              await betterPlayerController.value?.setSpeed(playbackSpeed.value);
              isPlaying.value = true;
              isVideoInitialized.value = true;
              WakelockPlus.enable();
              return true;
            }
          }
        } catch (retryError) {
          print('Retry also failed: $retryError');
        }

        print('❌ File appears to be corrupted after retry, deleting...');
        await _handleCorruptedLocalFile(videoId, _currentLocalFilePath!);

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
      return false;
    }
  }

  void _setupPlayerListener() {
    _playerEventSubscription?.cancel();

    _playerEventSubscription =
        betterPlayerController.value?.videoPlayerController?.addListener(() {
      _videoPlayerListener();
    }) as StreamSubscription?;
  }

  RxBool hasShownZoomHint = false.obs;

  void setZoomHintShown() {
    hasShownZoomHint.value = true;
  }

  bool _videoMarkedAsWatched = false;

  void _videoPlayerListener() {
    if (betterPlayerController.value?.videoPlayerController != null) {
      final videoController =
          betterPlayerController.value!.videoPlayerController!;

      final Duration position = videoController.value.position;
      final Duration duration = videoController.value.duration ?? Duration.zero;

      if (duration.inMilliseconds > 0) {
        videoProgress.value = position.inMilliseconds / duration.inMilliseconds;
      }

      isPlaying.value = videoController.value.isPlaying;
      isBuffering.value = videoController.value.isBuffering;

      if (videoController.value.hasError && !hasTriedOnlineFallback.value) {
        _handlePlaybackError();
      }

      if (duration.inMilliseconds > 0 && !_videoMarkedAsWatched) {
        final progress = position.inMilliseconds / duration.inMilliseconds;
        if (progress >= 0.95 ||
            position.inMilliseconds >= duration.inMilliseconds - 1000) {
          _markVideoAsWatched();
        }
      }

      if (position.inMilliseconds >= duration.inMilliseconds &&
          !isBuffering.value) {
        controlsVisible.value = true;
        WakelockPlus.disable();
      }
    }
  }

  Future<void> _markVideoAsWatched() async {
    if (currentVideo.value != null && !_videoMarkedAsWatched) {
      _videoMarkedAsWatched = true;
      await _storageService.addVideoToWatchedList(currentVideo.value!.id);
      print('✅ Video marked as watched: ${currentVideo.value!.id}');
    }
  }

  void _handlePlaybackError() async {
    if (isOfflineMode.value &&
        await _hasInternetConnection() &&
        currentVideo.value != null) {
      hasTriedOnlineFallback.value = true;
      print("Playback error detected, switching to online mode");

      if (_currentLocalFilePath != null) {
        await _handleCorruptedLocalFile(
            currentVideo.value!.id, _currentLocalFilePath!);
      }

      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message:
              'جاري التبديل للمشاهدة عبر الإنترنت: حدث خطأ في تشغيل الفيديو المحلي',
          type: SnackBarType.info,
          duration: Duration(seconds: 2),
        );
      }

      final String? streamUrl =
          await _videoRepository.getVideoUrl(currentVideo.value!.id);
      if (streamUrl != null) {
        await initializeVideoPlayer(streamUrl, isOffline: false);
      }
    } else if (isOfflineMode.value &&
        currentVideo.value != null &&
        _currentLocalFilePath != null) {
      await _handleCorruptedLocalFile(
          currentVideo.value!.id, _currentLocalFilePath!);
    }
  }

  void playPause() {
    if (betterPlayerController.value != null) {
      if (isPlaying.value) {
        betterPlayerController.value!.pause();
        WakelockPlus.disable();
      } else {
        betterPlayerController.value!.play();
        WakelockPlus.enable();
        _startHideControlsTimer();
      }
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (betterPlayerController.value != null) {
      try {
        await betterPlayerController.value!.setSpeed(speed);
        playbackSpeed.value = speed;

        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message:
                'تم تغيير السرعة: سرعة التشغيل: ${speed == 1.0 ? "طبيعية" : "x" + speed.toStringAsFixed(1)}',
            type: SnackBarType.info,
            duration: Duration(seconds: 1),
          );
        }

        _startHideControlsTimer();
      } catch (e) {
        print('Error setting playback speed: $e');
      }
    }
  }

  void seekTo(Duration position) {
    if (betterPlayerController.value != null) {
      betterPlayerController.value!.seekTo(position);
      _startHideControlsTimer();
    }
  }

  void seekToProgress(double progress) {
    if (betterPlayerController.value?.videoPlayerController != null) {
      final Duration duration =
          betterPlayerController.value!.videoPlayerController!.value.duration ?? Duration.zero;
      final int milliseconds = (progress * duration.inMilliseconds).round();
      seekTo(Duration(milliseconds: milliseconds));
    }
  }

  void skipForward() {
    if (betterPlayerController.value?.videoPlayerController != null) {
      final Duration currentPosition =
          betterPlayerController.value!.videoPlayerController!.value.position;
      final Duration duration =
          betterPlayerController.value!.videoPlayerController!.value.duration ?? Duration.zero;
      final Duration newPosition = currentPosition + Duration(seconds: 10);

      if (newPosition < duration) {
        seekTo(newPosition);
      } else {
        seekTo(duration);
      }
    }
  }

  void skipBackward() {
    if (betterPlayerController.value?.videoPlayerController != null) {
      final Duration currentPosition =
          betterPlayerController.value!.videoPlayerController!.value.position;
      final Duration newPosition = currentPosition - Duration(seconds: 10);

      if (newPosition > Duration.zero) {
        seekTo(newPosition);
      } else {
        seekTo(Duration.zero);
      }
    }
  }

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
    _playerEventSubscription?.cancel();
    if (betterPlayerController.value != null) {
      betterPlayerController.value!.dispose();
    }

    _setFullScreen(false);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    WakelockPlus.disable();

    super.onClose();
  }
}
