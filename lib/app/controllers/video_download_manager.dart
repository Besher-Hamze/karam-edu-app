import 'dart:math';

import 'package:course_platform/app/controllers/permission_manager.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../data/models/video.dart';
import '../data/repositories/video_repository.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';

class VideoDownloadManager extends GetxController {
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

  @override
  void onInit() {
    super.onInit();
    // Initialize by checking existing downloads
    _initializeDownloadedVideos();
    checkPreviousDownloads(); // Add this line
  }

  Future<void> _restoreDownloadStates() async {
    try {
      print('🔄 Restoring download states...');

      // Get all videos that have partial download info
      final downloadedList = await _storageService.getDownloadedVideosList();

      for (String videoId in downloadedList) {
        // Check if video is fully downloaded
        final String? path = await _storageService.getVideoPath(videoId);
        if (path != null && path.isNotEmpty) {
          final File videoFile = File(path);
          if (await videoFile.exists()) {
            final fileSize = await videoFile.length();
            if (fileSize > 0) {
              // File exists and is downloadVideo
              downloadedVideos[videoId] = true;
              downloadedVideoFiles[videoId] = path;
              downloadStatus[videoId] = 'completed';
              downloadProgress[videoId] = 1.0;
              print('✅ Restored completed download: $videoId');
              continue;
            }
          }
        }

        // Check for partial downloads
        final partialInfo =
            await _storageService.getPartialDownloadInfo(videoId);
        if (partialInfo != null) {
          final tempPath = path != null ? '$path.tmp' : null;

          if (tempPath != null && await File(tempPath).exists()) {
            // Partial file exists
            final actualSize = await File(tempPath).length();
            final savedDownloadedBytes = partialInfo['downloadedBytes'] as int;
            final savedTotalBytes = partialInfo['totalBytes'] as int;

            // Use actual file size (more reliable)
            downloadedBytes[videoId] = actualSize;
            totalBytes[videoId] = savedTotalBytes;

            final progress = actualSize / savedTotalBytes;
            downloadProgress[videoId] = progress;
            downloadStatus[videoId] = 'paused';
            isPaused[videoId] = true;

            print(
                '📥 Restored paused download: $videoId (${(progress * 100).toStringAsFixed(1)}%)');
          } else {
            // Partial info exists but no temp file - clean up
            await _storageService.removePartialDownloadInfo(videoId);
            await _storageService.removeVideoFromDownloadedList(videoId);
            print('🧹 Cleaned up invalid partial download: $videoId');
          }
        }
      }

      print('✅ Download states restoration completed');
    } catch (e) {
      print('❌ Error restoring download states: $e');
    }
  }

  Future<void> checkPreviousDownloads() async {
    try {
      final downloadedList = await _storageService.getDownloadedVideosList();

      for (String videoId in downloadedList) {
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
            downloadStatus[videoId] = 'paused';
            final progress =
                partialInfo['downloadedBytes'] / partialInfo['totalBytes'];
            downloadProgress[videoId] = progress;
            isPaused[videoId] = true;
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
        for (String videoId in downloadedList) {
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
      Get.snackbar(
        'خطأ',
        'فشل التحقق من حالة التنزيلات',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // Download a single video
  Future<bool> downloadVideo(Video video) async {
    final hasPermission = await PermissionManager.requestStoragePermission();
    if (!hasPermission) return false;

    // Check if already downloading
    if (downloadStatus[video.id] == 'downloading') {
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

    final String videoUrl =
        '${Get.find<NetworkService>().baseUrl}/${video.filePath}';

    try {
      final cancelToken = CancelToken();
      cancelTokens[video.id] = cancelToken;

      downloadStatus[video.id] = 'downloading';
      isPaused[video.id] = false;
      downloadProgress[video.id] = 0.0;
      downloadedBytes[video.id] = 0;
      totalBytes[video.id] = 0;

      final String? localPath = await _downloadService.downloadVideoPrivately(
        videoUrl: videoUrl,
        videoId: video.id,
        onProgress: (received, total) {
          if (isPaused[video.id] == true) return;

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
          downloadStatus[video.id] = status;

          if (status == 'completed') {
            downloadedBytes.remove(video.id);
            totalBytes.remove(video.id);
          }
        },
      );

      if (localPath != null) {
        downloadedVideoFiles[video.id] = localPath;
        await _storageService.saveVideoPath(video.id, localPath);
        await _storageService.addVideoToDownloadedList(video.id);

        final videoDetails = await _videoRepository.getVideoDetails(video.id);
        if (videoDetails != null) {
          await _storageService.saveVideoDetails(
              video.id, videoDetails.toJson());
        }

        return true;
      }
      return false;
    } catch (e) {
      print('❌ Download error for ${video.id}: $e');

      if (e.toString().contains('cancel')) {
        downloadStatus[video.id] = 'paused';
        isPaused[video.id] = true;

        // Only save progress if we have valid tracking data
        if (downloadedBytes.containsKey(video.id) &&
            totalBytes.containsKey(video.id) &&
            totalBytes[video.id]! > 0) {
          try {
            await _saveDownloadProgress(video.id, downloadedBytes[video.id]!, totalBytes[video.id]!);
          } catch (saveError) {
            print('Error saving progress on pause: $saveError');
          }
        }
        print('⏸️ Download paused due to cancellation: ${video.id}');
      } else {
        downloadStatus[video.id] = 'error';

        // Clear all tracking data on error
        downloadProgress.remove(video.id);
        isPaused.remove(video.id);
        cancelTokens.remove(video.id);
        downloadedBytes.remove(video.id);
        totalBytes.remove(video.id);

        // Clear invalid download state
        await clearInvalidDownload(video.id);
      }

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


  Future<void> _handleDownloadSuccess(String videoId, String filePath) async {
    try {
      // Update storage
      await _storageService.saveVideoPath(videoId, filePath);
      await _storageService.addVideoToDownloadedList(videoId);
      await _storageService.removePartialDownloadInfo(videoId);

      // Update download manager state
      downloadedVideoFiles[videoId] = filePath;
      downloadStatus[videoId] = 'completed';
      downloadedVideos[videoId] = true;

      // Clean up tracking data
      downloadProgress.remove(videoId);
      downloadedBytes.remove(videoId);
      totalBytes.remove(videoId);
      isPaused.remove(videoId);
      cancelTokens.remove(videoId);

      print('✅ Successfully handled download completion for: $videoId');
    } catch (e) {
      print('❌ Error handling download success: $e');
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
          if (size <= 1024) { // File is too small, likely corrupted
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

  Future<void> pauseDownload(String videoId) async {
    try {
      print('⏸️ Attempting to pause download for: $videoId');

      final cancelToken = cancelTokens[videoId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download paused by user');
        print('✅ Cancel token cancelled for: $videoId');
      }

      // Update status immediately
      downloadStatus[videoId] = 'paused';
      isPaused[videoId] = true;

      // Force save current progress with current download state
      if (downloadedBytes.containsKey(videoId) &&
          totalBytes.containsKey(videoId)) {
        final currentDownloaded = downloadedBytes[videoId]!;
        final currentTotal = totalBytes[videoId]!;

        print(
            '💾 Saving progress on pause: ${currentDownloaded / 1024 / 1024} MB / ${currentTotal / 1024 / 1024} MB');
        await _storageService.savePartialDownloadInfo(
            videoId, currentDownloaded, currentTotal);

        // Also ensure the file path is saved
        final currentPath = await _storageService.getVideoPath(videoId);
        if (currentPath == null || currentPath.isEmpty) {
          // Generate and save a consistent path
          final videoDir = await _getVideoDirectory();
          final filename = _generateSecureFilename();
          final newPath = '${videoDir.path}/$filename';
          await _storageService.saveVideoPath(videoId, newPath);
          print('💾 Generated and saved new video path: $newPath');
        }
      }

      print('⏸️ Download paused successfully for: $videoId');
    } catch (e) {
      print('❌ Error pausing download: $e');
    }
  }

  Future<Directory> _getVideoDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final videoDir = Directory('${appDir.path}/videos');
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
    return 'video_${timestamp}_$randomString.dat';
  }

  Future<bool> resumeDownload(String videoId) async {
    try {
      if (downloadStatus[videoId] != 'paused') {
        print('Cannot resume - video is not paused');
        return false;
      }

      // Get video details to resume download
      final videoDetails = await _videoRepository.getVideoDetails(videoId);
      if (videoDetails == null) {
        print('Cannot resume - video details not found');
        return false;
      }

      print('▶️ Resuming download for video: $videoId');

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

// Add method to check if download is paused
  bool isDownloadPaused(String videoId) {
    return isPaused[videoId] ?? false;
  }

  // When deleting a video, also remove from storage service
  Future<bool> deleteDownloadedVideo(String videoId) async {
    final bool deleted = await _downloadService.deletePrivateVideo(videoId);
    if (deleted) {
      downloadedVideos[videoId] = false;
      downloadedVideoFiles.remove(videoId);

      // Also remove from storage service
      await _storageService.saveVideoPath(videoId, '');
      await _storageService.removeVideoFromDownloadedList(videoId);
    }
    return deleted;
  }

  // Check if a video is downloaded
  Future<bool> isVideoDownloaded(String videoId) async {
    return await _downloadService.isVideoDownloaded(videoId);
  }

  // Get local path of a downloaded video
  Future<String?> getLocalVideoPath(String videoId) async {
    return await _downloadService.getPrivateVideoPath(videoId);
  }

  // Get the local file path for a downloaded video
  String? getDownloadedVideoFile(String videoId) {
    return downloadedVideoFiles[videoId];
  }

  // Batch download multiple videos
  Future<void> downloadVideos(List<Video> videos) async {
    for (var video in videos) {
      await downloadVideo(video);
    }
  }

  // Download all videos for the current course
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
      Get.snackbar(
        'خطأ',
        'فشل تنزيل جميع مقاطع الفيديو',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
