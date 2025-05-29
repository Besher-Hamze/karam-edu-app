import 'package:get/get.dart';
import '../data/models/video.dart';
import 'network_service.dart';
class VideoDownloadManager {
  final NetworkService _downloadService = NetworkService();

  void downloadVideo(Video video) async {
    final String videoUrl = '${Get.find<NetworkService>().baseUrl}/${video.filePath}';

    try {
      final String? localPath = await _downloadService.downloadVideoPrivately(
          videoUrl: videoUrl,
          videoId: video.id,
          onProgress: (received, total) {
            // Update UI with download progress
            final progress = (received / total * 100).toStringAsFixed(0);
            print('Download progress: $progress%');
          }
      );

      if (localPath != null) {
        // Video downloaded successfully
        // You might want to update the video's local status in your database
      }
    } catch (e) {
      // Handle download error
      print('Video download failed: $e');
    }
  }

  Future<bool> isVideoDownloaded(String videoId) async {
    return await _downloadService.isVideoDownloaded(videoId);
  }
}