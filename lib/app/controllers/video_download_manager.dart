import 'dart:math';

import 'package:course_platform/app/controllers/permission_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'dart:io';
import '../data/models/video.dart';
import '../data/repositories/video_repository.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import '../ui/global_widgets/snackbar.dart';

class VideoDownloadManager extends GetxController {
  static const MethodChannel _backgroundChannel =
      MethodChannel('karam/background_download');

  final NetworkService _downloadService = Get.find<NetworkService>();
  final VideoRepository _videoRepository = Get.find<VideoRepository>();
  final StorageService _storageService = Get.find<StorageService>();

  // Reactive download progress for each video
  final RxMap<String, double> downloadProgress = <String, double>{}.obs;

  // Reactive map to track downloaded videos
  final RxMap<String, bool> downloadedVideos = <String, bool>{}.obs;

  // Map to store local file paths for downloaded videos
  final RxMap<String, String> downloadedVideoFiles = <String, String>{}.obs;

  final RxMap<String, String> downloadStatus = <String, String>{}.obs;
  final RxMap<String, bool> isPaused = <String, bool>{}.obs;
  final RxMap<String, CancelToken> cancelTokens = <String, CancelToken>{}.obs;
  final RxMap<String, int> downloadedBytes = <String, int>{}.obs;
  final RxMap<String, int> totalBytes = <String, int>{}.obs;

  // Optional: Add a course ID to track downloads for a specific course
  String? _currentCourseId;

  /// Only one active [downloadVideo] per video id. Prevents double taps / parallel
  /// triggers from starting two HTTP downloads and corrupting progress for the same file.
  final Map<String, Future<bool>> _ongoingDownloads = {};
  final Map<String, int> _autoResumeAttempts = {};

  @override
  void onInit() {
    super.onInit();
    // Initialize by checking existing downloads
    _initializeDownloadedVideos();
    checkPreviousDownloads();
  }
  
  Future<void> handleAppPaused() async {
    await _syncIosBackgroundTask();
  }

  // If iOS suspended the process, continue any download that is no longer running.
  Future<void> handleAppResumed() async {
    final activeIds = downloadStatus.entries
        .where((entry) =>
            entry.value == 'downloading' && isPaused[entry.key] != true)
        .map((entry) => entry.key)
        .toList();

    for (final videoId in activeIds) {
      if (_ongoingDownloads.containsKey(videoId)) continue;
      final video = await _videoRepository.getVideoDetails(videoId);
      if (video == null) continue;
      downloadStatus[videoId] = 'interrupted';
      await downloadVideo(video);
    }
  }

  Future<void> checkPreviousDownloads() async {
    try {
      final downloadedList = await _storageService.getDownloadedVideosList();

      // CRITICAL: Create a copy of the list to avoid concurrent modification errors
      final List<String> videoIds = List<String>.from(downloadedList);

      for (String videoId in videoIds) {
        // Check if file still exists
        final String? path = await _storageService.getVideoPath(videoId);
        if (path != null && path.isNotEmpty) {
          final File videoFile = File(path);
          if (await videoFile.exists()) {
            downloadedVideos[videoId] = true;
            downloadedVideoFiles[videoId] = path;
            downloadStatus[videoId] = 'completed';
            downloadProgress[videoId] = 1.0;
          } else {
            // File missing, clean up
            await _storageService.removeVideoFromDownloadedList(videoId);
          }
        }

        // Check for partial downloads
        final partialInfo =
            await _storageService.getPartialDownloadInfo(videoId);
        if (partialInfo != null && !downloadedVideos.containsKey(videoId)) {
          final tempPath = path != null ? '$path.tmp' : null;
          if (tempPath != null && await File(tempPath).exists()) {
            final actualBytes = await File(tempPath).length();
            final savedTotal = partialInfo['totalBytes'] as int;
            
            // Restore accurate progress
            downloadedBytes[videoId] = actualBytes;
            totalBytes[videoId] = savedTotal;
            downloadStatus[videoId] = 'paused';
            downloadProgress[videoId] = actualBytes / savedTotal;
            isPaused[videoId] = true;
            
            print('📥 Restored paused download: $videoId (${(downloadProgress[videoId]! * 100).toStringAsFixed(1)}%)');
          }
        }
      }
    } catch (e) {
      print('Error checking previous downloads: $e');
    }
  }

  // New method to initialize downloads on app start
  Future<void> _initializeDownloadedVideos() async {
    try {
      // Get list of all downloaded videos from storage
      final downloadedList = await _storageService.getDownloadedVideosList();

      if (downloadedList.isNotEmpty) {
        // CRITICAL: Create a copy of the list to avoid concurrent modification errors
        final List<String> videoIds = List<String>.from(downloadedList);
        
        for (String videoId in videoIds) {
          final String? path = await _storageService.getVideoPath(videoId);
          if (path != null && path.isNotEmpty) {
            final File videoFile = File(path);
            if (await videoFile.exists()) {
              downloadedVideos[videoId] = true;
              downloadedVideoFiles[videoId] = path;
            } else {
              await _storageService.removeVideoFromDownloadedList(videoId);
            }
          }
        }
      }
    } catch (e) {
      print('Error initializing downloaded videos: $e');
    }
  }

  // Check which videos are already downloaded for a specific course
  Future<void> checkExistingDownloads(String courseId) async {
    _currentCourseId = courseId;
    try {
      // Fetch videos for the specific course
      final videos = await _videoRepository.getVideosByCourse(courseId);

      // Check download status for each video
      for (var video in videos) {
        final isDownloaded = await isVideoDownloaded(video.id);
        downloadedVideos[video.id] = isDownloaded;

        if (isDownloaded) {
          final localPath = await getLocalVideoPath(video.id);
          if (localPath != null) {
            downloadedVideoFiles[video.id] = localPath;
          }
        }
      }
    } catch (e) {
      print('Error checking existing downloads: $e');
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: فشل التحقق من حالة التنزيلات',
          type: SnackBarType.error,
        );
      }
    }
  }

  /// Download a single video. Concurrent calls for the same video share one download.
  Future<bool> downloadVideo(Video video) {
    final id = video.id;
    return _ongoingDownloads.putIfAbsent(id, () {
      final future = _downloadVideoImpl(video);
      return future.whenComplete(() => _ongoingDownloads.remove(id));
    });
  }

  Future<bool> _downloadVideoImpl(Video video) async {
    final hasPermission = await PermissionManager.requestStoragePermission();
    if (!hasPermission) return false;

    // Check if already downloading (in-memory state; may be set before HTTP starts)
    if (_ongoingDownloads.containsKey(video.id) ||
        downloadStatus[video.id] == 'downloading') {
      print('Video ${video.id} is already downloading');
      return false;
    }

    print('🚀 Starting download for video: ${video.id}');

    // Check for invalid partial downloads and clear them
    final partialInfo = await _storageService.getPartialDownloadInfo(video.id);
    if (partialInfo != null) {
      final savedDownloaded = partialInfo['downloadedBytes'] as int? ?? 0;
      final savedTotal = partialInfo['totalBytes'] as int? ?? 0;

      if (savedTotal <= 0 ||
          savedDownloaded < 0 ||
          savedDownloaded > savedTotal) {
        print('⚠️ Found invalid partial download, clearing...');
        await clearInvalidDownload(video.id);
      }
    }

    // Get signed URL from backend
    final String? videoUrl = await _videoRepository.getVideoUrl(video.id);
    
    if (videoUrl == null) {
      print('❌ Failed to get video URL from backend');
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: فشل الحصول على رابط الفيديو',
          type: SnackBarType.error,
        );
      }
      return false;
    }

    try {
      final cancelToken = CancelToken();
      cancelTokens[video.id] = cancelToken;

      downloadStatus[video.id] = 'downloading';
      isPaused[video.id] = false;
      await _syncIosBackgroundTask();
      
      // Don't reset progress if resuming - keep existing values
      if (!downloadedBytes.containsKey(video.id)) {
        downloadProgress[video.id] = 0.0;
        downloadedBytes[video.id] = 0;
        totalBytes[video.id] = 0;
      }

      final String? localPath = await _downloadService.downloadVideoPrivately(
        videoUrl: videoUrl,
        videoId: video.id,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          // Check cancellation immediately
          if (cancelToken.isCancelled || isPaused[video.id] == true) {
            print('⏸️ Progress callback skipped - download is paused');
            return;
          }

          // Validate progress data
          if (total <= 0 || received < 0 || received > total) {
            print('⚠️ Invalid progress data: $received/$total');
            return;
          }

          downloadedBytes[video.id] = received;
          totalBytes[video.id] = total;
          downloadProgress[video.id] = received / total;

          if (received >= total) {
            downloadStatus[video.id] = 'completed';
            downloadedVideos[video.id] = true;
            isPaused[video.id] = false;
            cancelTokens.remove(video.id);
            _storageService.removePartialDownloadInfo(video.id);
          }
        },
        onStatusChange: (status) {
          print('📱 Status change for ${video.id}: $status');
          
          // Don't override paused status
          if (downloadStatus[video.id] != 'paused') {
            downloadStatus[video.id] = status;
          }

          if (status == 'completed') {
            downloadedBytes.remove(video.id);
            totalBytes.remove(video.id);
          }
        },
      );

      // Check if it was paused during download
      if (isPaused[video.id] == true) {
        print('⏸️ Download was paused during execution');
        return false;
      }

      if (localPath != null) {
        downloadedVideoFiles[video.id] = localPath;
        await _storageService.saveVideoPath(video.id, localPath);
        await _storageService.addVideoToDownloadedList(video.id);

        final videoDetails = await _videoRepository.getVideoDetails(video.id);
        if (videoDetails != null) {
          await _storageService.saveVideoDetails(
              video.id, videoDetails.toJson());
        }

        _autoResumeAttempts.remove(video.id);
        await _syncIosBackgroundTask();
        return true;
      }
      return false;
    } catch (e) {
      final userPaused = isPaused[video.id] == true ||
          (e is DioException && e.type == DioExceptionType.cancel) ||
          e.toString().contains('cancel');

      if (userPaused) {
        downloadStatus[video.id] = 'paused';
        isPaused[video.id] = true;
        await _persistPartial(video.id);
        await _syncIosBackgroundTask();
        print('⏸️ Download paused: ${video.id}');
        return false;
      }

      print('Download interrupted, keeping progress: $e');
      await _persistPartial(video.id);
      final attempts = (_autoResumeAttempts[video.id] ?? 0) + 1;
      _autoResumeAttempts[video.id] = attempts;

      if (attempts <= 8) {
        downloadStatus[video.id] = 'downloading';
        Future<void>.delayed(const Duration(seconds: 2), () async {
          if (isPaused[video.id] == true) return;
          if (downloadStatus[video.id] == 'completed') return;
          if (_ongoingDownloads.containsKey(video.id)) return;
          downloadStatus[video.id] = 'interrupted';
          await downloadVideo(video);
        });
      } else {
        downloadStatus[video.id] = 'error';
        final context = Get.context;
        if (context != null) {
          ShamraSnackBar.show(
            context: context,
            message: 'خطأ: فشل حفظ الفيديو على الجهاز',
            type: SnackBarType.error,
          );
        }
      }

      await _syncIosBackgroundTask();
      return false;
    }
  }

  Future<void> _saveDownloadProgress(String videoId, int downloaded, int total) async {
    try {
      if (total > 0 && downloaded >= 0 && downloaded <= total) {
        await _storageService.savePartialDownloadInfo(videoId, downloaded, total);
        print('💾 Saved progress for $videoId: ${downloaded / 1024 / 1024} MB / ${total / 1024 / 1024} MB');
      } else {
        print('⚠️ Invalid progress data, not saving: $downloaded/$total');
      }
    } catch (e) {
      print('Error saving download progress: $e');
    }
  }

  Future<void> clearInvalidDownload(String videoId) async {
    try {
      print('🧹 Clearing invalid download for: $videoId');

      // Remove partial download info
      await _storageService.removePartialDownloadInfo(videoId);

      // Get and delete temp file if it exists
      final savedPath = await _storageService.getVideoPath(videoId);
      if (savedPath != null && savedPath.isNotEmpty) {
        final tempFile = File('$savedPath.tmp');
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
            print('🗑️ Deleted temp file: $savedPath.tmp');
          } catch (e) {
            print('Error deleting temp file: $e');
          }
        }

        // Also check for corrupted final file
        final finalFile = File(savedPath);
        if (await finalFile.exists()) {
          final size = await finalFile.length();
          if (size <= 1024) {
            try {
              await finalFile.delete();
              print('🗑️ Deleted corrupted final file: $savedPath');
            } catch (e) {
              print('Error deleting corrupted final file: $e');
            }
          }
        }
      }

      // Clear download state
      downloadStatus.remove(videoId);
      downloadProgress.remove(videoId);
      downloadedBytes.remove(videoId);
      totalBytes.remove(videoId);
      isPaused.remove(videoId);
      cancelTokens.remove(videoId);

      print('✅ Cleared invalid download state for: $videoId');
    } catch (e) {
      print('❌ Error clearing invalid download: $e');
    }
  }

  Future<void> _persistPartial(String videoId) async {
    final path = await _storageService.getVideoPath(videoId);
    if (path == null || path.isEmpty) return;
    final tempFile = File('$path.tmp');
    if (!await tempFile.exists()) return;
    final size = await tempFile.length();
    final total = totalBytes[videoId] ?? 0;
    if (size <= 0 || total <= 0 || size > total) return;
    downloadedBytes[videoId] = size;
    downloadProgress[videoId] = size / total;
    await _saveDownloadProgress(videoId, size, total);
  }

  Future<void> _syncIosBackgroundTask() async {
    if (!Platform.isIOS) return;
    final hasActiveDownload =
        downloadStatus.values.any((status) => status == 'downloading');
    try {
      await _backgroundChannel
          .invokeMethod(hasActiveDownload ? 'begin' : 'end');
    } catch (e) {
      print('Background download task update failed: $e');
    }
  }

  Future<void> pauseDownload(String videoId) async {
    try {
      print('⏸️ Attempting to pause download for: $videoId');
      
      // Set paused state FIRST
      isPaused[videoId] = true;
      downloadStatus[videoId] = 'paused';

      final cancelToken = cancelTokens[videoId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download paused by user');
        print('✅ Cancel token cancelled for: $videoId');
      }

      // Wait longer for download to actually stop and file writes to complete
      await Future.delayed(Duration(milliseconds: 1000));

      // CRITICAL: Get actual file size instead of tracked bytes
      // This ensures we save the real progress, accounting for any buffered writes
      final currentPath = await _storageService.getVideoPath(videoId);
      if (currentPath != null && currentPath.isNotEmpty) {
        final tempFile = File('$currentPath.tmp');
        if (await tempFile.exists()) {
          try {
            // Get actual file size after all writes are flushed
            final actualFileSize = await tempFile.length();
            final currentTotal = totalBytes[videoId] ?? 0;
            
            if (actualFileSize > 0 && currentTotal > 0) {
              // Use actual file size as source of truth
              await _storageService.savePartialDownloadInfo(
                  videoId, actualFileSize, currentTotal);
              print('💾 Saved actual file progress on pause: ${actualFileSize / 1024 / 1024} MB / ${currentTotal / 1024 / 1024} MB');
              
              // Update in-memory tracking to match actual file size
              downloadedBytes[videoId] = actualFileSize;
              downloadProgress[videoId] = actualFileSize / currentTotal;
            }
          } catch (e) {
            print('⚠️ Error getting actual file size on pause: $e');
            // Fallback to tracked bytes if we can't read file
            if (downloadedBytes.containsKey(videoId) &&
                totalBytes.containsKey(videoId) &&
                totalBytes[videoId]! > 0) {
              final currentDownloaded = downloadedBytes[videoId]!;
              final currentTotal = totalBytes[videoId]!;
              await _storageService.savePartialDownloadInfo(
                  videoId, currentDownloaded, currentTotal);
              print('💾 Saved tracked progress on pause (fallback): ${currentDownloaded / 1024 / 1024} MB / ${currentTotal / 1024 / 1024} MB');
            }
          }
        } else if (downloadedBytes.containsKey(videoId) &&
            totalBytes.containsKey(videoId) &&
            totalBytes[videoId]! > 0) {
          // No temp file yet, use tracked bytes
          final currentDownloaded = downloadedBytes[videoId]!;
          final currentTotal = totalBytes[videoId]!;
          await _storageService.savePartialDownloadInfo(
              videoId, currentDownloaded, currentTotal);
          print('💾 Saved tracked progress on pause: ${currentDownloaded / 1024 / 1024} MB / ${currentTotal / 1024 / 1024} MB');
        }
      } else {
        // Generate and save a consistent path
        final videoDir = await _getVideoDirectory();
        final filename = _generateSecureFilename();
        final newPath = '${videoDir.path}/$filename';
        await _storageService.saveVideoPath(videoId, newPath);
        print('💾 Generated and saved new video path: $newPath');
      }

      print('⏸️ Download paused successfully for: $videoId');
      await _syncIosBackgroundTask();
    } catch (e) {
      print('❌ Error pausing download: $e');
    }
  }

  Future<Directory> _getVideoDirectory() async {
    final videoDir = await _downloadService.getPersistentVideoDirectory();
    if (!await videoDir.exists()) {
      await videoDir.create(recursive: true);
    }
    return videoDir;
  }

  String _generateSecureFilename() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random();
    final randomString = List.generate(
        8,
        (index) =>
            'abcdefghijklmnopqrstuvwxyz0123456789'[random.nextInt(36)]).join();
    return 'video_${timestamp}_$randomString.mp4';
  }

  Future<bool> resumeDownload(String videoId) async {
    try {
      // CRITICAL: Check if download is already complete
      final isDownloaded = await isVideoDownloaded(videoId);
      if (isDownloaded) {
        final localPath = await getLocalVideoPath(videoId);
        if (localPath != null) {
          final file = File(localPath);
          if (await file.exists()) {
            final size = await file.length();
            if (size > 1024) {
              print('✅ Video already downloaded, no need to resume: $videoId');
              downloadStatus[videoId] = 'completed';
              downloadedVideos[videoId] = true;
              downloadedVideoFiles[videoId] = localPath;
              downloadProgress[videoId] = 1.0;
              isPaused.remove(videoId);
              return true;
            }
          }
        }
      }

      if (downloadStatus[videoId] != 'paused') {
        print('Cannot resume - video is not paused (status: ${downloadStatus[videoId]})');
        return false;
      }

      // Get video details to resume download
      final videoDetails = await _videoRepository.getVideoDetails(videoId);
      if (videoDetails == null) {
        print('Cannot resume - video details not found');
        return false;
      }

      print('▶️ Resuming download for video: $videoId');
      print('📊 Current progress: ${downloadedBytes[videoId]} / ${totalBytes[videoId]} bytes');

      // Remove paused state but keep progress data
      isPaused.remove(videoId);
      cancelTokens.remove(videoId);

      // Restart download (it will automatically resume from saved progress)
      return await downloadVideo(videoDetails);
    } catch (e) {
      print('Error resuming download: $e');
      return false;
    }
  }

  Future<void> cancelDownload(String videoId) async {
    try {
      final cancelToken = cancelTokens[videoId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download cancelled by user');
      }

      // Clean up all download data
      downloadProgress.remove(videoId);
      downloadStatus.remove(videoId);
      isPaused.remove(videoId);
      cancelTokens.remove(videoId);
      downloadedBytes.remove(videoId);
      totalBytes.remove(videoId);

      // Remove partial download info and temp files
      await _storageService.removePartialDownloadInfo(videoId);

      // Delete temp file if exists
      final path = await _storageService.getVideoPath(videoId);
      if (path != null) {
        final tempFile = File('$path.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
          print('🗑️ Deleted temp file: $path.tmp');
        }
      }

      // Remove from downloaded list
      await _storageService.removeVideoFromDownloadedList(videoId);

      print('❌ Download cancelled for video: $videoId');
    } catch (e) {
      print('Error cancelling download: $e');
    }
  }

  Future<bool> canResumeDownload(String videoId) async {
    try {
      final partialInfo = await _storageService.getPartialDownloadInfo(videoId);
      if (partialInfo == null) return false;

      final existingPath = await _storageService.getVideoPath(videoId);
      if (existingPath == null) return false;

      final tempFile = File('$existingPath.tmp');
      return await tempFile.exists();
    } catch (e) {
      print('Error checking resume capability: $e');
      return false;
    }
  }

  String getDownloadStatusString(String videoId) {
    return downloadStatus[videoId] ?? 'not_started';
  }

  bool isDownloadPaused(String videoId) {
    return isPaused[videoId] ?? false;
  }

  Future<bool> deleteDownloadedVideo(String videoId) async {
    final bool deleted = await _downloadService.deletePrivateVideo(videoId);
    if (deleted) {
      downloadedVideos[videoId] = false;
      downloadedVideoFiles.remove(videoId);
      
      // Clear all download-related state to trigger UI update
      downloadStatus.remove(videoId);
      downloadProgress.remove(videoId);
      downloadedBytes.remove(videoId);
      totalBytes.remove(videoId);
      isPaused.remove(videoId);
      cancelTokens.remove(videoId);

      await _storageService.saveVideoPath(videoId, '');
      await _storageService.removeVideoFromDownloadedList(videoId);
      await _storageService.removePartialDownloadInfo(videoId);
    }
    return deleted;
  }

  Future<bool> isVideoDownloaded(String videoId) async {
    return await _downloadService.isVideoDownloaded(videoId);
  }

  Future<String?> getLocalVideoPath(String videoId) async {
    return await _downloadService.getPrivateVideoPath(videoId);
  }

  String? getDownloadedVideoFile(String videoId) {
    return downloadedVideoFiles[videoId];
  }

  Future<void> downloadVideos(List<Video> videos) async {
    for (var video in videos) {
      await downloadVideo(video);
    }
  }

  Future<void> downloadAllCourseVideos() async {
    if (_currentCourseId == null) {
      print('No course selected for batch download');
      return;
    }

    try {
      final videos =
          await _videoRepository.getVideosByCourse(_currentCourseId!);
      await downloadVideos(videos);
    } catch (e) {
      print('Error downloading course videos: $e');
      final context = Get.context;
      if (context != null) {
        ShamraSnackBar.show(
          context: context,
          message: 'خطأ: فشل تنزيل جميع مقاطع الفيديو',
          type: SnackBarType.error,
        );
      }
    }
  }
}