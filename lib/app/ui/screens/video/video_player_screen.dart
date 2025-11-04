import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import '../../../controllers/video_controller.dart';
import '../../theme/color_theme.dart';

class VideoPlayerScreen extends GetView<VideoController> {
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);

    // Set full screen mode
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // Hide both status bar and navigation bar
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: WillPopScope(
        onWillPop: () async {
          // Restore system UI when back button is pressed
          SystemChrome.setEnabledSystemUIMode(
            SystemUiMode.manual,
            overlays: SystemUiOverlay.values, // Show all system UI
          );
          return true;
        },
        child: Obx(() {
          if (controller.isLoading.value) {
            return _buildLoadingState();
          }

          if (controller.currentVideo.value == null) {
            return _buildErrorState();
          }

          if (!controller.isVideoInitialized.value) {
            return _buildBufferingState();
          }

          return _buildVideoPlayer();
        }),
      ),
    );
  }

  // Simple loading state
  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
      ),
    );
  }

  // Simple error state
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: ColorTheme.error),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final String? videoId = Get.parameters['videoId'];
              if (videoId != null) controller.loadVideo(videoId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('إعادة المحاولة'),
          ),
          SizedBox(height: 12),
          TextButton(
            onPressed: () {
              // Restore system UI before going back
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.manual,
                overlays: SystemUiOverlay.values,
              );
              Get.back();
            },
            child: Text('العودة', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // Simple buffering state
  Widget _buildBufferingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
      ),
    );
  }

  // Streamlined video player
  Widget _buildVideoPlayer() {
    return Obx(() =>
        InteractiveViewer(
          maxScale: 4.0,
          minScale: 0.5,
          child: GestureDetector(
            onTap: controller.toggleControlsVisibility,
            child: Stack(
              children: [
                // Video player
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.videoPlayerController.value!.value.aspectRatio,
                    child: VideoPlayer(controller.videoPlayerController.value!),
                  ),
                ),

                // Controls overlay (with fade in/out animation)
                AnimatedOpacity(
                  opacity: controller.controlsVisible.value ? 1.0 : 0.0,
                  duration: Duration(milliseconds: 300),
                  child: Container(
                    color: Colors.black.withOpacity(0.4),
                    child: Stack(
                      children: [
                        // Back button (top left)
                        Positioned(
                          top: 16,
                          left: 16,
                          child: IconButton(
                            icon: Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () {
                              // Restore system UI before going back
                              SystemChrome.setEnabledSystemUIMode(
                                SystemUiMode.manual,
                                overlays: SystemUiOverlay.values,
                              );
                              Get.back();
                            },
                          ),
                        ),

                        // Top right controls - Speed & Zoom
                        Positioned(
                          top: 16,
                          right: 16,
                          child: Row(
                            children: [
                              // Offline indicator (if in offline mode)
                              if (controller.isOfflineMode.value)
                                Container(
                                  margin: EdgeInsets.only(right: 8),
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.offline_bolt, color: Colors.white, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'وضع بدون اتصال',
                                        style: TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),

                              // Playback speed button
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                child: DropdownButton<double>(
                                  value: controller.playbackSpeed.value,
                                  icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                                  underline: SizedBox(),
                                  dropdownColor: Colors.black87,
                                  items: [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0].map((speed) {
                                    return DropdownMenuItem<double>(
                                      value: speed,
                                      child: Text(
                                        speed == 1.0 ? 'عادي (x${speed.toStringAsFixed(1)})' : 'x${speed.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (double? newSpeed) {
                                    if (newSpeed != null) {
                                      controller.setPlaybackSpeed(newSpeed);
                                    }
                                  },
                                ),
                              ),

                              // Zoom indicator
                              Container(
                                margin: EdgeInsets.only(left: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.zoom_out_map, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'قم بالتكبير/التصغير بأصابعك',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center controls: backward, play/pause, forward
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Backward 10s button
                              GestureDetector(
                                onTap: controller.skipBackward,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.replay_10,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: 24),
                              
                              // Play/Pause button
                              GestureDetector(
                                onTap: controller.playPause,
                                child: Container(
                                  padding: EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: ColorTheme.primary.withOpacity(0.8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    controller.isPlaying.value ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                              ),
                              
                              SizedBox(width: 24),
                              
                              // Forward 10s button
                              GestureDetector(
                                onTap: controller.skipForward,
                                child: Container(
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.forward_10,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Bottom controls - progress bar and time
                        Positioned(
                          bottom: 16,
                          left: 16,
                          right: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  // Current position
                                  Text(
                                    _formatDuration(controller.videoPlayerController.value!.value.position),
                                    style: TextStyle(color: Colors.white),
                                  ),

                                  SizedBox(width: 8),

                                  // Progress slider
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderThemeData(
                                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                        trackHeight: 4,
                                        activeTrackColor: ColorTheme.primary,
                                        inactiveTrackColor: Colors.white30,
                                        thumbColor: ColorTheme.primary,
                                      ),
                                      child: Slider(
                                        value: controller.videoProgress.value,
                                        onChanged: (value) {
                                          controller.seekToProgress(value);
                                        },
                                      ),
                                    ),
                                  ),

                                  SizedBox(width: 8),

                                  // Total duration
                                  Text(
                                    _formatDuration(controller.videoPlayerController.value!.value.duration),
                                    style: TextStyle(color: Colors.white),
                                  ),

                                  // Add spacer for devices with notches
                                  SizedBox(width: MediaQuery.of(Get.context!).padding.right + 8),
                                ],
                              ),

                              // Speed buttons for quick access
                              SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildSpeedButton(0.5),
                                  _buildSpeedButton(1.0),
                                  _buildSpeedButton(1.5),
                                  _buildSpeedButton(2.0),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Buffering indicator
                Obx(() => controller.isBuffering.value
                    ? Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(ColorTheme.primary),
                  ),
                )
                    : SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
    );
  }

  // Helper to build speed selection buttons
  Widget _buildSpeedButton(double speed) {
    return Obx(() {
      final isSelected = controller.playbackSpeed.value == speed;
      return Container(
        margin: EdgeInsets.symmetric(horizontal: 4),
        child: ElevatedButton(
          onPressed: () => controller.setPlaybackSpeed(speed),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? ColorTheme.primary : Colors.black.withOpacity(0.7),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? Colors.white : Colors.grey,
                width: 1,
              ),
            ),
            elevation: 0,
          ),
          child: Text(
            speed == 1.0 ? 'عادي' : 'x${speed.toStringAsFixed(1)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    });
  }

  // Format duration to MM:SS
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final String minutes = twoDigits(duration.inMinutes.remainder(60));
    final String seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      final String hours = twoDigits(duration.inHours);
      return "$hours:$minutes:$seconds";
    } else {
      return "$minutes:$seconds";
    }
  }
}