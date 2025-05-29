import 'dart:io';

import '../../services/storage_service.dart';
import '../providers/video_provider.dart';
import '../models/video.dart';
import 'package:get/get.dart';

class VideoRepository {
  final VideoProvider _videoProvider;
  final StorageService _storageService = Get.find<StorageService>();

  VideoRepository({required VideoProvider videoProvider}) : _videoProvider = videoProvider;

  Future<List<Video>> getVideosByCourse(String courseId) async {
    try {
      // Check if we have internet connectivity
      if (await _hasInternetConnection()) {
        // If online, fetch from API and update local cache
        final response = await _videoProvider.getVideosByCourse(courseId);
        print("Response data type: ${response.data.runtimeType}");
        print("Response data: ${response.data}");


        final videos = (response.data as List).map((item) => Video.fromJson(item)).toList();
        print('Number of videos: ${videos.length}');

        // Save to local cache for offline access
        await _saveVideosToLocalCache(courseId, videos);
        return videos;
      } else {
        print("Error");
        // If offline, try to load from cache
        return await _getVideosFromLocalCache(courseId);
      }
    } catch (e) {
      print("ERRRROOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOOR");
      print(e);
      try {
        return await _getVideosFromLocalCache(courseId);
      } catch (cacheError) {
        // If both API and cache fail, rethrow the original error
        rethrow;
      }
    }
  }

  Future<Video?> getVideoDetails(String videoId) async {
    try {
      // Check if we have internet connectivity
      if (await _hasInternetConnection()) {
        // If online, fetch from API and update local cache
        final response = await _videoProvider.getVideoDetails(videoId);
        final video = Video.fromJson(response.data);

        // Save to local cache for offline access
        await _saveVideoDetailsToLocalCache(video);
        return video;
      } else {
        // If offline, try to load from cache
        return await _getVideoDetailsFromLocalCache(videoId);
      }
    } catch (e) {
      // If API call fails, try to load from cache as fallback
      try {
        return await _getVideoDetailsFromLocalCache(videoId);
      } catch (cacheError) {
        // If both API and cache fail, rethrow the original error
        rethrow;
      }
    }
  }

  // Check if the video is downloaded and available offline
  Future<bool> isVideoDownloaded(String videoId) async {
    return await _storageService.isVideoDownloaded(videoId);
  }

  // Get the local path for a downloaded video
  Future<String?> getLocalVideoPath(String videoId) async {
    return await _storageService.getVideoPath(videoId);
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

  // Cache methods for video lists
  Future<void> _saveVideosToLocalCache(String courseId, List<Video> videos) async {
    await _storageService.saveCourseVideos(courseId, videos.map((v) => v.toJson()).toList());
  }

  Future<List<Video>> _getVideosFromLocalCache(String courseId) async {
    final cachedData = await _storageService.getCourseVideos(courseId);
    if (cachedData != null) {
      return (cachedData as List).map((item) => Video.fromJson(item)).toList();
    }
    return [];
  }

  // Cache methods for individual video details
  Future<void> _saveVideoDetailsToLocalCache(Video video) async {
    await _storageService.saveVideoDetails(video.id, video.toJson());
  }

  Future<Video?> _getVideoDetailsFromLocalCache(String videoId) async {
    final cachedData = await _storageService.getVideoDetails(videoId);
    if (cachedData != null) {
      return Video.fromJson(cachedData);
    }
    return null;
  }
}