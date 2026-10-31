import 'dart:io';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageService extends GetxService {
  late GetStorage _box;

  Future<StorageService> init() async {
    _box = GetStorage();
    return this;
  }

  // Auth
  String? getToken() {
    return _box.read('token');
  }

  Future<void> setToken(String token) async {
    await _box.write('token', token);
  }

  Future<void> removeToken() async {
    await _box.remove('token');
  }

  // Student Profile
  Map<String, dynamic>? getStudentProfile() {
    return _box.read('student_profile');
  }

  Future<void> setStudentProfile(Map<String, dynamic> profile) async {
    await _box.write('student_profile', profile);
  }

  Future<void> removeStudentProfile() async {
    await _box.remove('student_profile');
  }

  // Course Cache
  List<dynamic>? getCachedCourses() {
    return _box.read('cached_courses');
  }

  Future<void> setCachedCourses(List<dynamic> courses) async {
    await _box.write('cached_courses', courses);
  }

  // Logout - Clear all data
  Future<void> clearAllData() async {
    await _box.erase();
  }
  Future<void> saveCourseVideos(
      String courseId, List<Map<String, dynamic>> videos) async {
    await GetStorage().write('course_videos_$courseId', videos);
  }

  Future<dynamic> getCourseVideos(String courseId) async {
    return await GetStorage().read('course_videos_$courseId');
  }





// Check if a video file is downloaded
  Future<bool> isVideoDownloaded(String videoId) async {
    final String? path = await getVideoPath(videoId);
    if (path == null) return false;

    final file = File(path);
    return await file.exists();
  }



  Future<List<String>> getDownloadedVideosList() async {
    final List<dynamic>? list = await GetStorage().read('downloaded_videos_list');
    return list?.cast<String>() ?? [];
  }

// Add a video ID to the downloaded list
  Future<void> addVideoToDownloadedList(String videoId) async {
    final List<String> currentList = await getDownloadedVideosList();
    if (!currentList.contains(videoId)) {
      currentList.add(videoId);
      await GetStorage().write('downloaded_videos_list', currentList);
    }
  }

// Remove a video ID from the downloaded list
  Future<void> removeVideoFromDownloadedList(String videoId) async {
    final List<String> currentList = await getDownloadedVideosList();
    currentList.remove(videoId);
    await GetStorage().write('downloaded_videos_list', currentList);
  }

// Save video details to local storage
  Future<void> saveVideoDetails(String videoId, Map<String, dynamic> videoDetails) async {
    await GetStorage().write('video_details_$videoId', videoDetails);
  }

// Get video details from local storage
  Future<Map<String, dynamic>?> getVideoDetails(String videoId) async {
    return await GetStorage().read('video_details_$videoId');
  }
  Future<List<String>> getDownloadedFilesList() async {
    final List<dynamic>? list = await GetStorage().read('downloaded_files_list');
    return list?.cast<String>() ?? [];
  }

// Add a file ID to the downloaded list
  Future<void> addFileToDownloadedList(String fileId) async {
    final List<String> currentList = await getDownloadedFilesList();
    if (!currentList.contains(fileId)) {
      currentList.add(fileId);
      await GetStorage().write('downloaded_files_list', currentList);
    }
  }

// Remove a file ID from the downloaded list
  Future<void> removeFileFromDownloadedList(String fileId) async {
    final List<String> currentList = await getDownloadedFilesList();
    currentList.remove(fileId);
    await GetStorage().write('downloaded_files_list', currentList);
  }

// Save path to downloaded file
  Future<void> saveFilePath(String fileId, String path) async {
    await GetStorage().write('file_path_$fileId', path);
  }

// Get path to downloaded file
  Future<String?> getFilePath(String fileId) async {
    return await GetStorage().read('file_path_$fileId');
  }

  Future<void> saveDownloadTasks(List<Map<String, dynamic>> tasks) async {
    await _box.write('download_tasks', tasks);
  }

  Future<List<Map<String, dynamic>>?> getDownloadTasks() async {
    final tasks = _box.read('download_tasks');
    return tasks?.cast<Map<String, dynamic>>();
  }

// Download progress tracking
  Future<void> saveDownloadProgress(String videoId, double progress) async {
    await _box.write('download_progress_$videoId', progress);
  }

  Future<double> getDownloadProgress(String videoId) async {
    return _box.read('download_progress_$videoId') ?? 0.0;
  }

// Partial download info
  Future<void> savePartialDownloadInfo(String videoId, int downloadedBytes, int totalBytes) async {
    await _box.write('partial_download_$videoId', {
      'downloadedBytes': downloadedBytes,
      'totalBytes': totalBytes,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    print('💾 Saved progress for $videoId: ${downloadedBytes / 1024 / 1024} MB / ${totalBytes / 1024 / 1024} MB');
  }

  Future<Map<String, dynamic>?> getPartialDownloadInfo(String videoId) async {
    final info = _box.read('partial_download_$videoId');
    if (info != null) {
      print('📖 Retrieved progress for $videoId: ${info['downloadedBytes'] / 1024 / 1024} MB / ${info['totalBytes'] / 1024 / 1024} MB');
    }
    return info;
  }


  Future<void> removePartialDownloadInfo(String videoId) async {
    await _box.remove('partial_download_$videoId');
    print('🗑️ Removed partial download info for $videoId');
  }

  Future<void> saveVideoPath(String videoId, String path) async {
    await _box.write('video_path_$videoId', path);
    print('💾 Saved video path for $videoId: $path');
  }

  Future<String?> getVideoPath(String videoId) async {
    final path = _box.read('video_path_$videoId');
    if (path != null) {
      print('📖 Retrieved video path for $videoId: $path');
    }
    return path;
  }

  // Watched videos tracking
  Future<List<String>> getWatchedVideosList() async {
    final List<dynamic>? list = await GetStorage().read('watched_videos_list');
    return list?.cast<String>() ?? [];
  }

  Future<void> addVideoToWatchedList(String videoId) async {
    final List<String> currentList = await getWatchedVideosList();
    if (!currentList.contains(videoId)) {
      currentList.add(videoId);
      await GetStorage().write('watched_videos_list', currentList);
      print('✅ Marked video as watched: $videoId');
    }
  }

  Future<bool> isVideoWatched(String videoId) async {
    final List<String> watchedList = await getWatchedVideosList();
    return watchedList.contains(videoId);
  }

  Future<void> saveHttpCache(String key, dynamic data) async {
    await _box.write('http_cache_$key', {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': data,
    });
  }

  Future<dynamic> getHttpCache(String key, {Duration? maxAge}) async {
    final entry = _box.read('http_cache_$key');
    if (entry == null) {
      return null;
    }

    if (entry is Map && entry.containsKey('timestamp')) {
      final ts = entry['timestamp'] as int? ?? 0;
      if (maxAge != null) {
        final age = DateTime.now().millisecondsSinceEpoch - ts;
        if (age > maxAge.inMilliseconds) {
          await _box.remove('http_cache_$key');
          return null;
        }
      }
      return entry['data'];
    }

    return entry;
  }

  Future<void> removeHttpCache(String key) async {
    await _box.remove('http_cache_$key');
  }

  // FCM
  String? getFcmRegisteredToken() => _box.read('fcm_registered_token');

  Future<void> setFcmRegisteredToken(String token) async {
    await _box.write('fcm_registered_token', token);
  }

  bool isFcmTopicSubscribed(String topic) {
    return _box.read('fcm_topic_$topic') == true;
  }

  Future<void> setFcmTopicSubscribed(String topic, bool value) async {
    await _box.write('fcm_topic_$topic', value);
  }

  /// Black overlay on video controls (0–1). Default 0.4
  double getVideoOverlayOpacity() {
    final v = _box.read('video_overlay_opacity');
    if (v is num) return v.toDouble().clamp(0.0, 1.0);
    return 0.4;
  }

  Future<void> setVideoOverlayOpacity(double opacity) async {
    await _box.write('video_overlay_opacity', opacity.clamp(0.0, 1.0));
  }
}
