import 'dart:io';
import 'package:course_platform/app/controllers/permission_manager.dart';
import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import '../data/models/video.dart';
import '../data/repositories/video_repository.dart';
import '../services/network_service.dart';
import '../services/storage_service.dart';
import 'package:flutter/material.dart';

class VideoDownloadManager extends GetxController {
  final NetworkService _networkService = Get.find<NetworkService>();
  late VideoRepository _videoRepository;
  final StorageService _storageService = Get.find<StorageService>();

  // Simple state management
  final RxMap<String, DownloadTask> _downloadTasks = <String, DownloadTask>{}.obs;
  final RxMap<String, CancelToken> _cancelTokens = <String, CancelToken>{}.obs;

  // Getters for UI
  RxMap<String, DownloadTask> get downloadTasks => _downloadTasks;

  @override
  void onInit() {
    super.onInit();
    // Delay repository initialization until it's available
    _initializeRepository();
  }

  void _initializeRepository() {
    try {
      _videoRepository = Get.find<VideoRepository>();
      _loadSavedDownloads();
    } catch (e) {
      // Repository not ready yet, will retry when needed
      print('VideoRepository not ready yet: $e');
    }
  }

  /// Load previously downloaded and in-progress videos
  Future<void> _loadSavedDownloads() async {
    try {
      print('🔄 Loading saved downloads...');
      
      // Get all saved download tasks
      final savedTasks = await _storageService.getAllDownloadTasks();
      
      for (var taskData in savedTasks) {
        final task = DownloadTask.fromJson(taskData);
        
        // Check if file exists for completed downloads
        if (task.status == DownloadStatus.completed) {
          final file = File(task.localPath);
          if (await file.exists()) {
            _downloadTasks[task.videoId] = task;
            print('✅ Found completed download: ${task.videoId}');
          } else {
            // File missing, remove from storage
            await _storageService.removeDownloadTask(task.videoId);
            print('🗑️ Removed missing file: ${task.videoId}');
          }
        }
        // For paused downloads, check if temp file exists
        else if (task.status == DownloadStatus.paused) {
          final tempFile = File('${task.localPath}.tmp');
          if (await tempFile.exists()) {
            _downloadTasks[task.videoId] = task;
            print('⏸️ Found paused download: ${task.videoId}');
          } else {
            // Temp file missing, reset task
            await _storageService.removeDownloadTask(task.videoId);
            print('🗑️ Removed orphaned task: ${task.videoId}');
          }
        }
      }
      
      print('✅ Loaded ${_downloadTasks.length} saved downloads');
    } catch (e) {
      print('❌ Error loading saved downloads: $e');
    }
  }

  /// Ensure repository is initialized (call this from UI when needed)
  void ensureRepositoryInitialized() {
    if (!Get.isRegistered<VideoRepository>()) {
      return;
    }
    
    try {
      _videoRepository = Get.find<VideoRepository>();
      // Load saved downloads if not already loaded
      if (_downloadTasks.isEmpty) {
        _loadSavedDownloads();
      }
    } catch (e) {
      print('Error initializing repository: $e');
    }
  }

  /// Start downloading a video
  Future<bool> startDownload(Video video) async {
    try {
      // Check permissions
      final hasPermission = await PermissionManager.requestStoragePermission();
      if (!hasPermission) {
        _showError('تحتاج للسماح بالوصول للتخزين');
        return false;
      }

      // Check if already downloading
      final existingTask = _downloadTasks[video.id];
      if (existingTask?.status == DownloadStatus.downloading) {
        print('⚠️ Video ${video.id} is already downloading');
        return false;
      }

      print('🚀 Starting download for video: ${video.id}');

      // Create download directory
      final downloadDir = await _getDownloadDirectory();
      final fileName = '${video.id}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final localPath = '${downloadDir.path}/$fileName';

      // Create download task
      final task = DownloadTask(
        videoId: video.id,
        videoTitle: video.title,
        localPath: localPath,
        status: DownloadStatus.downloading,
        progress: 0.0,
        downloadedBytes: 0,
        totalBytes: 0,
        createdAt: DateTime.now(),
      );

      // Update UI immediately
      _downloadTasks[video.id] = task;
      await _storageService.saveDownloadTask(video.id, task.toJson());

      // Start download in background
      _performDownload(video, task);
      
      return true;
    } catch (e) {
      print('❌ Error starting download: $e');
      _showError('فشل في بدء التحميل');
      return false;
    }
  }

  /// Pause download
  Future<void> pauseDownload(String videoId) async {
    try {
      print('⏸️ Pausing download: $videoId');
      
      // Cancel the download
      final cancelToken = _cancelTokens[videoId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download paused by user');
      }

      // Update task status
      final task = _downloadTasks[videoId];
      if (task != null) {
        final updatedTask = task.copyWith(status: DownloadStatus.paused);
        _downloadTasks[videoId] = updatedTask;
        await _storageService.saveDownloadTask(videoId, updatedTask.toJson());
      }

      _cancelTokens.remove(videoId);
      print('✅ Download paused: $videoId');
    } catch (e) {
      print('❌ Error pausing download: $e');
    }
  }

  /// Resume download
  Future<void> resumeDownload(String videoId) async {
    try {
      final task = _downloadTasks[videoId];
      if (task == null || task.status != DownloadStatus.paused) {
        print('⚠️ Cannot resume - invalid task state');
        return;
      }

      print('▶️ Resuming download: $videoId');

      // Ensure repository is available
      if (!Get.isRegistered<VideoRepository>()) {
        print('❌ VideoRepository not available for resume');
        return;
      }

      // Get video details
      final video = await _videoRepository.getVideoDetails(videoId);
      if (video == null) {
        print('❌ Video not found for resume');
        return;
      }

      // Update status to downloading
      final updatedTask = task.copyWith(status: DownloadStatus.downloading);
      _downloadTasks[videoId] = updatedTask;
      await _storageService.saveDownloadTask(videoId, updatedTask.toJson());

      // Resume download
      _performDownload(video, updatedTask);
    } catch (e) {
      print('❌ Error resuming download: $e');
    }
  }

  /// Cancel download completely
  Future<void> cancelDownload(String videoId) async {
    try {
      print('❌ Cancelling download: $videoId');

      // Cancel the download
      final cancelToken = _cancelTokens[videoId];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download cancelled by user');
      }

      // Get task for cleanup
      final task = _downloadTasks[videoId];
      
      // Remove from memory and storage
      _downloadTasks.remove(videoId);
      _cancelTokens.remove(videoId);
      await _storageService.removeDownloadTask(videoId);

      // Delete temp file
      if (task != null) {
        final tempFile = File('${task.localPath}.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
          print('🗑️ Deleted temp file');
        }
      }

      print('✅ Download cancelled: $videoId');
    } catch (e) {
      print('❌ Error cancelling download: $e');
    }
  }

  /// Delete downloaded video
  Future<void> deleteDownload(String videoId) async {
    try {
      print('🗑️ Deleting download: $videoId');

      final task = _downloadTasks[videoId];
      if (task == null) return;

      // Delete the file
      final file = File(task.localPath);
      if (await file.exists()) {
        await file.delete();
      }

      // Remove from memory and storage
      _downloadTasks.remove(videoId);
      await _storageService.removeDownloadTask(videoId);

      print('✅ Download deleted: $videoId');
      _showSuccess('تم حذف الفيديو بنجاح');
    } catch (e) {
      print('❌ Error deleting download: $e');
      _showError('فشل في حذف الفيديو');
    }
  }

  /// Perform the actual download
  Future<void> _performDownload(Video video, DownloadTask task) async {
    CancelToken? cancelToken;
    
    try {
      // Create cancel token
      cancelToken = CancelToken();
      _cancelTokens[video.id] = cancelToken;

      final videoUrl = '${_networkService.baseUrl}/${video.filePath}';
      final tempPath = '${task.localPath}.tmp';
      
      // Check for existing temp file (for resume)
      int startByte = 0;
      
      // If task has downloadedBytes > 0, this is a resume operation
      if (task.downloadedBytes > 0) {
        final tempFile = File(tempPath);
        if (await tempFile.exists()) {
          final actualFileSize = await tempFile.length();
          
          // Use the actual file size for resume
          startByte = actualFileSize;
          print('📦 Resuming from saved progress: ${startByte / 1024 / 1024} MB');
          
          // Validate that we have valid total bytes
          if (task.totalBytes <= 0) {
            print('⚠️ No valid total bytes, starting fresh');
            startByte = 0;
            await tempFile.delete();
          }
        } else {
          print('⚠️ Temp file missing, starting fresh');
          startByte = 0;
        }
      }

      print('📡 Downloading from byte: $startByte');

      // Setup headers
      final headers = <String, dynamic>{
        'Authorization': 'Bearer ${_storageService.getToken()}',
      };
      
      if (startByte > 0) {
        headers['Range'] = 'bytes=$startByte-';
        print('📡 Using Range header: bytes=$startByte-');
      }

      // Create temp file if it doesn't exist or if starting fresh
      final tempFile = File(tempPath);
      if (!await tempFile.exists() || startByte == 0) {
        await tempFile.create(recursive: true);
        if (startByte == 0) {
          // Write empty file for new downloads
          await tempFile.writeAsBytes([]);
        }
      }

      // Use a custom download approach for better control
      final response = await _networkService.dio.get<ResponseBody>(
        videoUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveDataWhenStatusError: false,
        ),
      );

      if (response.data == null) {
        throw Exception('No response data received');
      }

      // Get content length
      final contentLength = response.headers.value('content-length');
      final contentRange = response.headers.value('content-range');
      
      int totalFileSize = 0;
      if (contentRange != null) {
        // Parse Content-Range: bytes start-end/total
        final rangeMatch = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
        if (rangeMatch != null) {
          totalFileSize = int.parse(rangeMatch.group(3)!);
        }
      } else if (contentLength != null) {
        totalFileSize = startByte + int.parse(contentLength);
      } else {
        throw Exception('Unable to determine file size');
      }

      print('📊 Total file size: ${totalFileSize / 1024 / 1024} MB');

      // Open file for writing (append mode if resuming)
      final RandomAccessFile raf = await tempFile.open(mode: startByte > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly);
      
      int downloadedBytes = startByte;
      
      try {
        await for (final chunk in response.data!.stream) {
          if (cancelToken.isCancelled) {
            print('⏸️ Download cancelled during streaming');
            break;
          }
          
          // Write chunk to file
          await raf.writeFrom(chunk);
          downloadedBytes += chunk.length;
          
          // Calculate progress
          final progress = downloadedBytes / totalFileSize;

          // Update task
          final updatedTask = task.copyWith(
            progress: progress,
            downloadedBytes: downloadedBytes,
            totalBytes: totalFileSize,
          );
          
          _downloadTasks[video.id] = updatedTask;
          
          // Save progress periodically (every ~1MB)
          if (downloadedBytes % (1024 * 1024) < chunk.length) {
            await _storageService.saveDownloadTask(video.id, updatedTask.toJson());
          }
          
          // Log progress occasionally
          if (downloadedBytes % (5 * 1024 * 1024) < chunk.length) { // Every 5MB
            print('📥 Progress: ${(progress * 100).toStringAsFixed(1)}% (${downloadedBytes / 1024 / 1024} MB / ${totalFileSize / 1024 / 1024} MB)');
          }
        }
      } finally {
        await raf.close();
      }

      // Check if download was cancelled
      if (cancelToken.isCancelled) {
        print('⏸️ Download was cancelled/paused');
        return;
      }

      // Verify download completion
      final finalFileSize = await tempFile.length();
      if (finalFileSize >= totalFileSize) {
        // Move temp file to final location
        await tempFile.rename(task.localPath);
        print('📁 Moved temp file to final location: ${task.localPath}');

        // Update task as completed
        final completedTask = task.copyWith(
          status: DownloadStatus.completed,
          progress: 1.0,
          completedAt: DateTime.now(),
        );
        
        _downloadTasks[video.id] = completedTask;
        await _storageService.saveDownloadTask(video.id, completedTask.toJson());

        print('✅ Download completed: ${video.id}');
        _showSuccess('تم تحميل ${video.title} بنجاح');
      } else {
        print('⚠️ Download incomplete: ${finalFileSize}/${totalFileSize} bytes');
      }

      // Cleanup
      _cancelTokens.remove(video.id);

    } catch (e) {
      print('❌ Download error: $e');
      
      // Don't show error if it was just cancelled
      if (cancelToken?.isCancelled != true) {
        // Update task as error
        final errorTask = task.copyWith(status: DownloadStatus.error);
        _downloadTasks[video.id] = errorTask;
        await _storageService.saveDownloadTask(video.id, errorTask.toJson());
        
        _showError('فشل في تحميل ${video.title}');
      }
      
      _cancelTokens.remove(video.id);
    }
  }

  /// Get download directory
  Future<Directory> _getDownloadDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${appDir.path}/downloads');
    
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    
    return downloadDir;
  }

  // Legacy method for compatibility
  Future<bool> downloadVideo(Video video) async {
    return await startDownload(video);
  }

  /// Check if video is downloaded
  bool isVideoDownloaded(String videoId) {
    final task = _downloadTasks[videoId];
    return task?.status == DownloadStatus.completed;
  }

  /// Get local video path
  String? getLocalVideoPath(String videoId) {
    final task = _downloadTasks[videoId];
    if (task?.status == DownloadStatus.completed) {
      return task?.localPath;
    }
    return null;
  }

  /// Get download progress
  double getDownloadProgress(String videoId) {
    return _downloadTasks[videoId]?.progress ?? 0.0;
  }

  /// Get download status
  DownloadStatus getDownloadStatus(String videoId) {
    return _downloadTasks[videoId]?.status ?? DownloadStatus.notStarted;
  }

  /// Legacy methods for compatibility
  Future<bool> deleteDownloadedVideo(String videoId) async {
    await deleteDownload(videoId);
    return true;
  }

  String getDownloadStatusString(String videoId) {
    final status = getDownloadStatus(videoId);
    switch (status) {
      case DownloadStatus.notStarted:
        return 'not_started';
      case DownloadStatus.downloading:
        return 'downloading';
      case DownloadStatus.paused:
        return 'paused';
      case DownloadStatus.completed:
        return 'completed';
      case DownloadStatus.error:
        return 'error';
    }
  }

  bool isDownloadPaused(String videoId) {
    return getDownloadStatus(videoId) == DownloadStatus.paused;
  }

  /// Helper methods
  void _showSuccess(String message) {
    Get.snackbar(
      'نجح',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.primaryColor,
      colorText: Colors.white,
    );
  }

  void _showError(String message) {
    Get.snackbar(
      'خطأ',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red,
      colorText: Colors.white,
    );
  }
}

/// Download Status Enum
enum DownloadStatus {
  notStarted,
  downloading,
  paused,
  completed,
  error,
}

/// Download Task Model
class DownloadTask {
  final String videoId;
  final String videoTitle;
  final String localPath;
  final DownloadStatus status;
  final double progress;
  final int downloadedBytes;
  final int totalBytes;
  final DateTime createdAt;
  final DateTime? completedAt;

  DownloadTask({
    required this.videoId,
    required this.videoTitle,
    required this.localPath,
    required this.status,
    required this.progress,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.createdAt,
    this.completedAt,
  });

  DownloadTask copyWith({
    String? videoId,
    String? videoTitle,
    String? localPath,
    DownloadStatus? status,
    double? progress,
    int? downloadedBytes,
    int? totalBytes,
    DateTime? createdAt,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      videoId: videoId ?? this.videoId,
      videoTitle: videoTitle ?? this.videoTitle,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'videoId': videoId,
      'videoTitle': videoTitle,
      'localPath': localPath,
      'status': status.index,
      'progress': progress,
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    return DownloadTask(
      videoId: json['videoId'],
      videoTitle: json['videoTitle'],
      localPath: json['localPath'],
      status: DownloadStatus.values[json['status']],
      progress: json['progress'].toDouble(),
      downloadedBytes: json['downloadedBytes'],
      totalBytes: json['totalBytes'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
    );
  }

  String get statusString {
    switch (status) {
      case DownloadStatus.notStarted:
        return 'لم يبدأ';
      case DownloadStatus.downloading:
        return 'جاري التحميل';
      case DownloadStatus.paused:
        return 'متوقف';
      case DownloadStatus.completed:
        return 'مكتمل';
      case DownloadStatus.error:
        return 'خطأ';
    }
  }

  String get formattedSize {
    if (totalBytes <= 0) return 'غير معروف';
    
    final mb = totalBytes / (1024 * 1024);
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    } else {
      final kb = totalBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
  }

  String get progressText {
    if (status == DownloadStatus.completed) {
      return '100%';
    } else if (totalBytes > 0) {
      return '${(progress * 100).toInt()}%';
    } else {
      return '0%';
    }
  }
}
