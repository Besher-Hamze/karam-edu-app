import 'dart:async';
import 'dart:io';
import 'package:course_platform/app/controllers/video_download_manager.dart';
import 'package:course_platform/app/data/models/video.dart';
import 'package:course_platform/app/data/repositories/video_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart' as mkv;
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

  /// One mpv (libmpv/FFmpeg) instance for the whole screen. Switching sources
  /// (offline -> online fallback) re-opens media on it instead of recreating it.
  final Player player = Player(
    configuration: const PlayerConfiguration(
      bufferSize: 64 * 1024 * 1024,
      logLevel: MPVLogLevel.warn,
    ),
  );

  /// Hardware decoding is tried first (`hwdec=auto-safe`); mpv falls back to
  /// software decoding by itself when the device decoder rejects the stream.
  late final mkv.VideoController videoOutput = mkv.VideoController(
    player,
    configuration: const mkv.VideoControllerConfiguration(
      enableHardwareAcceleration: true,
    ),
  );

  Rx<Video?> currentVideo = Rx<Video?>(null);
  RxBool isVideoInitialized = false.obs;
  RxBool isPlaying = false.obs;
  RxBool isLoading = true.obs;
  RxBool isBuffering = false.obs;
  RxDouble videoProgress = 0.0.obs;
  Rx<Duration> videoDuration = Duration.zero.obs;
  RxBool controlsVisible = true.obs;
  RxBool isOfflineMode = false.obs;
  final StorageService _storageService = Get.find<StorageService>();
  final NetworkService _networkService = Get.find<NetworkService>();
  Timer? _hideControlsTimer;
  RxBool hasTriedOnlineFallback = false.obs;

  RxDouble playbackSpeed = 1.0.obs;
  final List<StreamSubscription> _playerSubscriptions = [];
  AppLifecycleListener? _lifecycleListener;
  late final Future<void> _playerReady;
  bool _softwareDecodingForced = false;

  @override
  void onInit() {
    super.onInit();
    _playerReady = _configurePlayer();
    _listenToPlayer();

    final String? videoId = Get.parameters['videoId'];
    if (videoId != null) {
      loadVideo(videoId);
    }

    _setFullScreen(true);

    // Unlike SystemChannels.lifecycle.setMessageHandler, this does not replace
    // the framework's own lifecycle handling.
    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        if (isPlaying.value) {
          player.pause();
          WakelockPlus.disable();
        }
      },
      onResume: () => _setFullScreen(true),
    );
  }

  /// Network / decoding tuning applied to mpv before anything is opened.
  Future<void> _configurePlayer() async {
    final native = player.platform;
    if (native is! NativePlayer) return;
    try {
      // Make sure the video output is attached before setting properties.
      await videoOutput.platform.future;
      await native.setProperty('cache', 'yes');
      await native.setProperty('demuxer-max-back-bytes', '${32 * 1024 * 1024}');
      await native.setProperty('demuxer-readahead-secs', '60');
      await native.setProperty('network-timeout', '20');
      await native.setProperty('stream-lavf-o',
          'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=5');
      // Keeps A/V in sync on weak devices by dropping late frames.
      await native.setProperty('framedrop', 'decoder+vo');
    } catch (e) {
      print('Error configuring player: $e');
    }
  }

  void _listenToPlayer() {
    _playerSubscriptions.addAll([
      player.stream.playing.listen((playing) => isPlaying.value = playing),
      player.stream.buffering.listen((buffering) => isBuffering.value = buffering),
      player.stream.duration.listen((duration) => videoDuration.value = duration),
      player.stream.position.listen(_onPosition),
      player.stream.completed.listen((completed) {
        if (!completed) return;
        _markVideoAsWatched();
        controlsVisible.value = true;
        WakelockPlus.disable();
      }),
      player.stream.error.listen((error) => print('🎬 Player error: $error')),
    ]);
  }

  void _onPosition(Duration position) {
    final duration = player.state.duration;
    if (duration.inMilliseconds <= 0) return;

    final progress = position.inMilliseconds / duration.inMilliseconds;
    videoProgress.value = progress;

    if (!_videoMarkedAsWatched &&
        (progress >= 0.95 ||
            position.inMilliseconds >= duration.inMilliseconds - 1000)) {
      _markVideoAsWatched();
    }

    _checkVideoIsRendering(position);
  }

  /// Safety net for "audio but no picture": if playback has advanced and the
  /// decoder still hasn't produced a single video frame, force software
  /// decoding for this player and re-seek so the picture comes back.
  void _checkVideoIsRendering(Duration position) {
    if (_softwareDecodingForced || !isVideoInitialized.value) return;
    if (position < const Duration(seconds: 4)) return;
    if (player.state.width != null && player.state.width! > 0) return;

    final hasVideoTrack = player.state.tracks.video
        .any((track) => track.id != 'auto' && track.id != 'no');
    if (!hasVideoTrack) return;

    final native = player.platform;
    if (native is! NativePlayer) return;

    _softwareDecodingForced = true;
    print('⚠️ No video frames decoded, switching to software decoding');
    native.setProperty('hwdec', 'no').then((_) => player.seek(position));
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

  void pauseForProtection() {
    if (isPlaying.value) {
      player.pause();
      WakelockPlus.disable();
    }
  }

  Future<void> loadVideo(String videoId) async {
    try {
      isLoading.value = true;
      isVideoInitialized.value = false;
      hasTriedOnlineFallback.value = false;
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
        final initSuccess =
            await initializeVideoPlayer(localFilePath, isOffline: true);

        if (!initSuccess) {
          // FFmpeg could not even open the file, so it really is broken.
          await _handleCorruptedLocalFile(videoId, localFilePath);
          if (!hasInternet) {
            throw Exception(
                'فشل تشغيل الفيديو المحلي ولا يوجد اتصال بالإنترنت');
          }

          print("Offline playback failed, switching to online mode");
          hasTriedOnlineFallback.value = true;
          final String? streamUrl = await _videoRepository.getVideoUrl(videoId);
          if (streamUrl == null) {
            throw Exception('فشل الحصول على رابط الفيديو من الخادم');
          }
          await initializeVideoPlayer(streamUrl, isOffline: false);
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

  /// Completes once mpv knows the media duration. Errors are not fatal right
  /// away: mpv logs recoverable decoder errors (e.g. while falling back from
  /// hardware to software decoding), so only fail if the media never loads.
  Future<Duration> _waitUntilOpened() {
    final completer = Completer<Duration>();
    String? lastError;
    Timer? errorGrace;

    final subscriptions = <StreamSubscription>[
      player.stream.duration.listen((duration) {
        if (duration >= const Duration(seconds: 1) && !completer.isCompleted) {
          completer.complete(duration);
        }
      }),
      player.stream.error.listen((error) {
        lastError = error;
        errorGrace ??= Timer(const Duration(seconds: 4), () {
          if (!completer.isCompleted) {
            completer.completeError(Exception('Failed to open video: $lastError'));
          }
        });
      }),
    ];

    return completer.future
        .timeout(
          const Duration(seconds: 25),
          onTimeout: () => throw Exception(
              'Video initialization timeout${lastError != null ? ': $lastError' : ''}'),
        )
        .whenComplete(() {
      errorGrace?.cancel();
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    });
  }

  Future<bool> initializeVideoPlayer(String videoPath,
      {bool isOffline = false}) async {
    isVideoInitialized.value = false;
    isOfflineMode.value = isOffline;
    videoProgress.value = 0.0;

    try {
      await _playerReady;

      final opened = _waitUntilOpened();
      await player.open(Media(videoPath), play: false);
      final duration = await opened;
      print('✅ Video opened (${duration.inSeconds}s): $videoPath');

      await player.setRate(playbackSpeed.value);
      await player.play();

      isVideoInitialized.value = true;
      WakelockPlus.enable();
      return true;
    } catch (e) {
      print('Error initializing video player: $e');
      isVideoInitialized.value = false;
      await player.stop();

      // Local failures are handled by loadVideo (fallback to streaming).
      if (!isOffline) {
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'خطأ: فشل تشغيل الفيديو',
            type: SnackBarType.error,
          );
        }
      }
      return false;
    }
  }

  RxBool hasShownZoomHint = false.obs;

  void setZoomHintShown() {
    hasShownZoomHint.value = true;
  }

  bool _videoMarkedAsWatched = false;

  Future<void> _markVideoAsWatched() async {
    if (currentVideo.value != null && !_videoMarkedAsWatched) {
      _videoMarkedAsWatched = true;
      await _storageService.addVideoToWatchedList(currentVideo.value!.id);
      print('✅ Video marked as watched: ${currentVideo.value!.id}');
    }
  }

  void playPause() {
    if (!isVideoInitialized.value) return;
    if (isPlaying.value) {
      player.pause();
      WakelockPlus.disable();
    } else {
      if (player.state.completed) {
        player.seek(Duration.zero);
      }
      player.play();
      WakelockPlus.enable();
      _startHideControlsTimer();
    }
  }

  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await player.setRate(speed);
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

  void seekTo(Duration position) {
    if (!isVideoInitialized.value) return;
    final duration = player.state.duration;
    if (position < Duration.zero) position = Duration.zero;
    if (duration > Duration.zero && position > duration) position = duration;
    player.seek(position);
    _startHideControlsTimer();
  }

  void seekToProgress(double progress) {
    final duration = player.state.duration;
    final int milliseconds = (progress * duration.inMilliseconds).round();
    seekTo(Duration(milliseconds: milliseconds));
  }

  void skipForward() {
    seekTo(player.state.position + Duration(seconds: 10));
  }

  void skipBackward() {
    seekTo(player.state.position - Duration(seconds: 10));
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
    _lifecycleListener?.dispose();
    for (final subscription in _playerSubscriptions) {
      subscription.cancel();
    }
    player.dispose();

    _setFullScreen(false);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    WakelockPlus.disable();

    super.onClose();
  }
}
