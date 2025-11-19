import 'package:course_platform/utils/constants.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'storage_service.dart';
import 'package:dio/dio.dart' as p;
import 'dart:math';
import '../ui/global_widgets/snackbar.dart';

class NetworkService extends GetxService {
  late Dio _dio;
  final StorageService _storageService = Get.find<StorageService>();
  final String baseUrl = AppConstants.baseUrl;
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();

  // Private variables for device information
  String? _deviceManufacturer;
  String? _deviceModel;
  int? _sdkVersion;
  bool? _isSamsungDevice;

  Future<NetworkService> init() async {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = _storageService.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (e, handler) {
        if (e.response?.statusCode == 401) {
          _storageService.clearAllData();
          Get.offAllNamed('/login');
          final context = Get.context;
          if (context != null) {
            ShamraSnackBar.show(
              context: context,
              message: 'خطأ في المصادقة: الرجاء تسجيل الدخول مرة أخرى',
              type: SnackBarType.error,
            );
          }
        }
        return handler.next(e);
      },
    ));

    // Initialize device info
    if (Platform.isAndroid) {
      final androidInfo = await _deviceInfo.androidInfo;
      _deviceManufacturer = androidInfo.manufacturer?.toLowerCase() ?? "";
      _deviceModel = androidInfo.model ?? "";
      _sdkVersion = androidInfo.version.sdkInt ?? 0;
      _isSamsungDevice = _deviceManufacturer!.contains('samsung');

      print('Device: ${androidInfo.manufacturer} ${androidInfo.model}');
      print('Android SDK: $_sdkVersion');
      print('Is Samsung device: $_isSamsungDevice');
    }

    return this;
  }

  // GET Request
  Future<p.Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.get(path, queryParameters: queryParameters);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // POST Request
  Future<p.Response> post(String path, {dynamic data}) async {
    try {
      return await _dio.post(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // PUT Request
  Future<p.Response> put(String path, {dynamic data}) async {
    try {
      return await _dio.put(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // PATCH Request
  Future<p.Response> patch(String path, {dynamic data}) async {
    try {
      return await _dio.patch(path, data: data);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // DELETE Request
  Future<p.Response> delete(String path) async {
    try {
      return await _dio.delete(path);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // Multipart Request للملفات
  Future<p.Response> uploadFile(String path, File file, String fileName, Map<String, dynamic> data) async {
    try {
      p.FormData formData = p.FormData.fromMap({
        ...data,
        'file': await p.MultipartFile.fromFile(file.path, filename: fileName),
      });
      return await _dio.post(path, data: formData);
    } on DioException catch (e) {
      _handleError(e);
      rethrow;
    }
  }

  // التعامل مع الأخطاء
  void _handleError(DioException e) {
    String errorMessage = 'حدث خطأ في الاتصال بالخادم';
    if (e.response != null) {
      if (e.response!.data is Map && e.response!.data['message'] != null) {
        errorMessage = e.response!.data['message'];
      } else {
        errorMessage = 'خطأ: ${e.response!.statusCode}';
      }
    } else if (e.type == DioExceptionType.connectionTimeout) {
      errorMessage = 'انتهت مهلة الاتصال بالخادم';
    } else if (e.type == DioExceptionType.connectionError) {
      errorMessage = 'تعذر الاتصال بالخادم، تحقق من اتصالك بالإنترنت';
    }

    final context = Get.context;
    if (context != null) {
      ShamraSnackBar.show(
        context: context,
        message: 'خطأ: $errorMessage',
        type: SnackBarType.error,
      );
    }
  }

  // Generate a secure random filename that doesn't look like a video
  String _generateSecureFilename() {
    // List of common non-video extensions
    final extensions = ['.dat', '.bin', '.db', '.enc', '.data'];

    // Random length between 8-12 characters
    final random = Random();
    final length = random.nextInt(5) + 8;

    // Generate a random string
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randomString = List.generate(
        length,
            (index) => chars[random.nextInt(chars.length)]
    ).join();

    // Add timestamp for uniqueness
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Pick a random extension
    final extension = extensions[random.nextInt(extensions.length)];

    return '$randomString-$timestamp$extension';
  }

  // Find all available private storage directories that work on Samsung
  Future<List<Directory>> _getAvailablePrivateDirectories() async {
    final List<Directory> availableDirs = [];
    final List<Directory?> potentialDirs = [];

    try {
      // App-specific directories that should always be available without permissions
      potentialDirs.add(await getApplicationDocumentsDirectory());
      potentialDirs.add(await getApplicationCacheDirectory());
      potentialDirs.add(await getApplicationSupportDirectory());
      potentialDirs.add(await getTemporaryDirectory());

      // Test each directory
      for (var dir in potentialDirs) {
        if (dir == null) continue;

        try {
          // Check if directory exists and is writable
          final testFile = File('${dir.path}/test_write.tmp');
          await testFile.writeAsString('test');
          await testFile.delete();

          // If we get here, it's writable
          availableDirs.add(dir);
        } catch (e) {
          print('Directory ${dir.path} is not writable: $e');
        }
      }
    } catch (e) {
      print('Error finding available directories: $e');
    }

    return availableDirs;
  }

  // Get best directory for storing videos on Samsung devices
  Future<Directory?> _getBestVideoDirectory() async {
    try {
      // Get all available directories
      final availableDirs = await _getAvailablePrivateDirectories();

      if (availableDirs.isEmpty) {
        throw Exception('No writable directories found');
      }

      // Sort directories by available space (largest first)
      final dirWithSpace = <Directory, int>{};

      for (var dir in availableDirs) {
        try {
          if (_isSamsungDevice! && dir.path.contains('cache')) {
            // Skip cache directories for Samsung as they can be purged
            continue;
          }

          // Create a videos subdirectory
          final videosDir = Directory('${dir.path}/data_files');
          if (!await videosDir.exists()) {
            await videosDir.create(recursive: true);
          }

          // Check available space
          final stat = await File('${videosDir.path}/space_check.tmp').writeAsString('test');
          await stat.delete();

          // Directory works, add it
          dirWithSpace[videosDir] = await _getAvailableSpace(dir);
        } catch (e) {
          print('Error checking directory ${dir.path}: $e');
        }
      }

      if (dirWithSpace.isEmpty) {
        throw Exception('No writable video directories found');
      }

      // Return the directory with the most space
      final bestDir = dirWithSpace.entries
          .reduce((a, b) => a.value > b.value ? a : b)
          .key;

      print('Selected best directory for videos: ${bestDir.path}');
      return bestDir;
    } catch (e) {
      print('Error finding best video directory: $e');

      // Fallback to application documents directory
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final videosDir = Directory('${fallbackDir.path}/data_files');
        if (!await videosDir.exists()) {
          await videosDir.create(recursive: true);
        }
        return videosDir;
      } catch (e2) {
        print('Error creating fallback directory: $e2');
        return null;
      }
    }
  }

  // Get available space in a directory (estimated)
  Future<int> _getAvailableSpace(Directory directory) async {
    try {
      // Try to create a 1MB file to test space
      final testFile = File('${directory.path}/space_test.tmp');

      // Create a buffer with 1MB
      final buffer = List<int>.filled(1024 * 1024, 0);
      await testFile.writeAsBytes(buffer);

      // Get file size to confirm
      final size = await testFile.length();
      await testFile.delete();

      // Directory has at least 1MB available
      return size;
    } catch (e) {
      print('Error checking available space: $e');
      return 0;
    }
  }

  Future<String?> downloadVideoPrivately({
    required String videoUrl,
    required String videoId,
    required CancelToken cancelToken,
    required Function(int, int) onProgress,
    Function(String)? onStatusChange,
  }) async {
    print('========== ENHANCED VIDEO DOWNLOAD START ==========');
    print('Device: $_deviceManufacturer $_deviceModel (SDK $_sdkVersion)');
    print('Video ID: $videoId');
    print('Video URL: $videoUrl');

    String? downloadedFilePath;
    RandomAccessFile? raf;
    String? filePath;
    String? tempFilePath;
    int totalBytes = 0;

    try {
      // Get or create file path
      String? existingPath = await _storageService.getVideoPath(videoId);

      if (existingPath != null && existingPath.isNotEmpty) {
        filePath = existingPath;
        print('📁 Using existing path: $filePath');
      } else {
        final videoDir = await _getBestVideoDirectory();
        if (videoDir == null) {
          print('Error: No suitable directory found for storing videos');
          return null;
        }

        final secureFilename = _generateSecureFilename();
        filePath = '${videoDir.path}/$secureFilename';
        await _storageService.saveVideoPath(videoId, filePath);
        print('📁 Generated and saved new path: $filePath');
      }

      tempFilePath = '$filePath.tmp';
      print('📁 Temp file path: $tempFilePath');

      // Check if video is already completely downloaded
      final finalFile = File(filePath);
      if (await finalFile.exists()) {
        final size = await finalFile.length();
        if (size > 1024) {
          // CRITICAL: Check if there's a temp file - if not, download is complete
          final tempFile = File(tempFilePath);
          if (!await tempFile.exists()) {
            print('✅ Video already downloaded at: $filePath (${size / 1024 / 1024} MB)');
            onProgress(size, size);
            // Clear any stale partial download info
            await _storageService.removePartialDownloadInfo(videoId);
            return filePath;
          } else {
            // Temp file exists - download might be incomplete
            print('⚠️ Final file exists but temp file also exists, checking...');
          }
        } else {
          print('🗑️ Deleting incomplete final file');
          await finalFile.delete();
        }
      }

      // Check for partial download info
      final partialInfo = await _storageService.getPartialDownloadInfo(videoId);
      int startByte = 0;
      int savedTotalBytes = 0;

      if (partialInfo != null) {
        final savedDownloaded = partialInfo['downloadedBytes'] as int? ?? 0;
        savedTotalBytes = partialInfo['totalBytes'] as int? ?? 0;

        print('💾 Found saved progress: ${savedDownloaded / 1024 / 1024} MB / ${savedTotalBytes / 1024 / 1024} MB');

        if (savedTotalBytes <= 0 || savedDownloaded <= 0) {
          print('⚠️ Invalid saved progress detected, clearing and starting fresh');
          await _storageService.removePartialDownloadInfo(videoId);
          startByte = 0;

          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('🗑️ Deleted invalid temp file');
          }
        } else {
          // Check if temp file exists and matches saved progress
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            final actualSize = await tempFile.length();
            
            // CRITICAL: Validate file size is reasonable
            if (actualSize > savedTotalBytes * 1.1) {
              // File is significantly larger (more than 10%) - likely corrupted
              print('⚠️ Temp file is significantly larger than expected total! File may be corrupted.');
              print('   File size: ${actualSize / 1024 / 1024} MB');
              print('   Expected total: ${savedTotalBytes / 1024 / 1024} MB');
              await tempFile.delete();
              await _storageService.removePartialDownloadInfo(videoId);
              startByte = 0;
            } else if (actualSize >= savedTotalBytes * 0.95) {
              // File is 95%+ of expected size - might be complete
              print('⚠️ Temp file is close to completion (${(actualSize / savedTotalBytes * 100).toStringAsFixed(1)}%)');
              
              // CRITICAL: If file is at or very close to expected size, verify it's complete
              if (actualSize >= savedTotalBytes - 1024) { // Within 1KB of expected
                print('✅ Temp file appears complete (${actualSize} bytes, expected ${savedTotalBytes} bytes)');
                print('   Verifying and finalizing download...');
                
                // Verify file is actually complete by checking if we can read the end
                try {
                  final verifyRaf = await tempFile.open(mode: FileMode.read);
                  await verifyRaf.setPosition(actualSize - 1);
                  final lastByte = await verifyRaf.read(1);
                  await verifyRaf.close();
                  
                  if (lastByte.isNotEmpty) {
                    // File appears complete - rename it and mark as complete
                    print('✅ File verification passed, finalizing...');
                    
                    // Wait a bit to ensure file is fully written
                    await Future.delayed(Duration(milliseconds: 200));
                    
                    // Rename temp to final
                    await tempFile.rename(filePath);
                    final finalFile = File(filePath);
                    if (await finalFile.exists()) {
                      final finalSize = await finalFile.length();
                      await _storageService.saveVideoPath(videoId, filePath);
                      await _storageService.addVideoToDownloadedList(videoId);
                      await _storageService.removePartialDownloadInfo(videoId);
                      onProgress(finalSize, finalSize);
                      onStatusChange?.call('completed');
                      print('✅ Download complete: ${finalSize / 1024 / 1024} MB');
                      return filePath;
                    } else {
                      print('⚠️ Rename failed, file does not exist at final path');
                    }
                  } else {
                    print('⚠️ Could not read last byte, file may be incomplete');
                  }
                } catch (e) {
                  print('⚠️ File verification failed: $e, will resume from actual size');
                }
              }
              
              // File is close but not complete - resume from actual size
              // CRITICAL: Don't truncate - use actual size to avoid corruption
              startByte = actualSize;
              totalBytes = savedTotalBytes;
              print('🔄 Resuming from actual file size: $startByte bytes (${(startByte / savedTotalBytes * 100).toStringAsFixed(1)}% complete)');
            } else if (actualSize < savedDownloaded) {
              // File is smaller than saved progress - use actual size
              print('⚠️ Temp file is smaller than saved progress');
              print('   File size: ${actualSize / 1024 / 1024} MB');
              print('   Saved progress: ${savedDownloaded / 1024 / 1024} MB');
              startByte = actualSize;
              totalBytes = savedTotalBytes;
              print('🔄 Resuming from actual file size: $startByte bytes');
            } else {
              // Use the smaller of actual size or saved progress to be safe
              startByte = actualSize < savedDownloaded ? actualSize : savedDownloaded;
              totalBytes = savedTotalBytes;

              if (startByte > 0) {
                print('🔄 Resuming download from byte: $startByte (${startByte / 1024 / 1024} MB)');
                print('   Total expected: ${totalBytes / 1024 / 1024} MB');
              } else {
                print('⚠️ Temp file exists but has 0 bytes, starting fresh');
                await tempFile.delete();
                await _storageService.removePartialDownloadInfo(videoId);
              }
            }
          } else {
            print('⚠️ Partial info exists but no temp file found, starting fresh');
            await _storageService.removePartialDownloadInfo(videoId);
            startByte = 0;
          }
        }
      } else {
        print('🆕 No previous download found, starting fresh');
        startByte = 0;

        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          await tempFile.delete();
          print('🗑️ Deleted orphaned temp file');
        }
      }

      // Check if this is a signed URL
      final isSignedUrl = videoUrl.contains('X-Amz-Algorithm') || 
                          videoUrl.contains('Signature') ||
                          videoUrl.contains('signature');

      // Prepare headers
      final Map<String, dynamic> downloadHeaders = {
        'Connection': 'keep-alive',
        'User-Agent': 'VideoDownloader/1.0',
        'Accept': '*/*',
        'Accept-Encoding': 'identity',
      };

      if (!isSignedUrl) {
        final token = _storageService.getToken();
        if (token != null) {
          downloadHeaders['Authorization'] = 'Bearer $token';
        }
      }

      // Create Dio instance for downloading
      final Dio downloadDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(minutes: 15),
        sendTimeout: const Duration(seconds: 30),
        headers: downloadHeaders,
      ));

      // Add range header for resume if needed
      if (startByte > 0) {
        downloadDio.options.headers['Range'] = 'bytes=$startByte-';
        print('📡 Request headers: Range=bytes=$startByte-');
      }

      onStatusChange?.call('connecting');
      print('🔌 Starting download request...');

      // Make the request with cancel token
      final response = await downloadDio.get<ResponseBody>(
        videoUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) {
            return status! < 400 || status == 416;
          },
        ),
      );

      // Check if cancelled immediately after request
      if (cancelToken.isCancelled) {
        print('⏸️ Download cancelled before stream processing');
        throw DioException(
          requestOptions: response.requestOptions,
          error: 'Download cancelled by user',
          type: DioExceptionType.cancel,
        );
      }

      if (response.data == null) {
        throw Exception('No response data received');
      }

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response headers: ${response.headers.map}');

      // Handle range not satisfiable
      if (response.statusCode == 416) {
        print('⚠️ Range not satisfiable - checking if file is complete');
        final tempFile = File(tempFilePath);
        if (await tempFile.exists()) {
          final tempSize = await tempFile.length();
          if (tempSize > 1024) {
            await tempFile.rename(filePath);
            final finalSize = await finalFile.length();
            onProgress(finalSize, finalSize);
            await _storageService.removePartialDownloadInfo(videoId);
            return filePath;
          }
        }
        throw Exception('Range not satisfiable and no valid temp file exists');
      }

      // Parse content information
      final contentLength = response.headers.value('content-length');
      final contentRange = response.headers.value('content-range');

      // Determine total file size
      if (contentRange != null) {
        // Server is sending a range (206 response)
        final rangeMatch = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
        if (rangeMatch != null) {
          final rangeStart = int.parse(rangeMatch.group(1)!);
          final rangeEnd = int.parse(rangeMatch.group(2)!);
          totalBytes = int.parse(rangeMatch.group(3)!);

          print('📊 Content-Range: $rangeStart-$rangeEnd/$totalBytes');
          print('📊 Expected start: $startByte, Actual start: $rangeStart');

          // CRITICAL: Verify server resumed from correct position
          if (rangeStart != startByte) {
            print('⚠️ Server did not resume from expected position!');
            print('   Expected: $startByte, Got: $rangeStart');
            
            if (rangeStart == 0) {
              // Server ignored range request and is sending full file
              print('🔄 Server sending full file, deleting temp and restarting');
              final tempFile = File(tempFilePath);
              if (await tempFile.exists()) {
                await tempFile.delete();
                print('🗑️ Deleted temp file to prevent corruption');
              }
              startByte = 0;
              await _storageService.removePartialDownloadInfo(videoId);
            } else {
              // Server resuming from different position - sync to it
              print('🔄 Syncing to server position: $rangeStart');
              startByte = rangeStart;
              
              // Truncate temp file to match server position
              final tempFile = File(tempFilePath);
              if (await tempFile.exists()) {
                final rafTemp = await tempFile.open(mode: FileMode.write);
                await rafTemp.truncate(startByte);
                await rafTemp.close();
                print('✂️ Truncated temp file to: $startByte bytes');
              }
            }
          }
        }
      } else if (contentLength != null) {
        // NO RANGE HEADER - Server is sending full file (200 response)
        final receivedLength = int.parse(contentLength);
        
        print('📡 No Content-Range header - full file response (200)');
        print('📊 Content-Length: $receivedLength');
        
        // CRITICAL: If we requested a range but got full file, delete temp
        if (startByte > 0) {
          print('⚠️ Requested range from byte $startByte but got full file (200 response)');
          print('🗑️ Deleting temp file to prevent corruption');
          
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            await tempFile.delete();
            print('✅ Temp file deleted');
          }
          
          startByte = 0;
          await _storageService.removePartialDownloadInfo(videoId);
          print('🔄 Reset to fresh download from byte 0');
        }
        
        totalBytes = receivedLength;
      } else {
        throw Exception('Server did not provide content length information');
      }

      if (totalBytes <= 0) {
        throw Exception('Invalid total file size: $totalBytes');
      }

      print('📊 Final download parameters:');
      print('   Total file size: ${totalBytes / 1024 / 1024} MB');
      print('   Starting from byte: $startByte');
      print('   Remaining to download: ${(totalBytes - startByte) / 1024 / 1024} MB');

      onStatusChange?.call('downloading');

      // Create temp file and open for writing
      final tempFile = File(tempFilePath);

      // CRITICAL: Ensure temp file state matches startByte
      // Always use actual file size as source of truth when resuming
      if (await tempFile.exists()) {
        try {
          final actualSize = await tempFile.length();
          
          // CRITICAL: If file is already at or beyond expected size, don't resume - finalize it
          if (totalBytes > 0 && actualSize >= totalBytes - 1024) {
            print('✅ Temp file is already complete (${actualSize} bytes, expected ${totalBytes} bytes)');
            print('   Finalizing download without resuming...');
            
            // Verify file is readable and complete
            try {
              final verifyRaf = await tempFile.open(mode: FileMode.read);
              await verifyRaf.setPosition(actualSize - 1);
              final lastByte = await verifyRaf.read(1);
              await verifyRaf.close();
              
              if (lastByte.isNotEmpty) {
                // File is complete - rename and finalize
                await tempFile.rename(filePath);
                final finalFile = File(filePath);
                if (await finalFile.exists()) {
                  final finalSize = await finalFile.length();
                  await _storageService.saveVideoPath(videoId, filePath);
                  await _storageService.addVideoToDownloadedList(videoId);
                  await _storageService.removePartialDownloadInfo(videoId);
                  onProgress(finalSize, finalSize);
                  onStatusChange?.call('completed');
                  print('✅ Download finalized: ${finalSize / 1024 / 1024} MB');
                  return filePath;
                }
              }
            } catch (e) {
              print('⚠️ File verification failed: $e, will try to resume');
            }
          }
          
          if (actualSize != startByte) {
            print('⚠️ Temp file size mismatch!');
            print('   Actual: $actualSize, Expected: $startByte');
            print('   Difference: ${actualSize - startByte} bytes (${(actualSize - startByte) / 1024} KB)');
            
            if (startByte == 0) {
              // Should start fresh - delete temp
              await tempFile.delete();
              print('🗑️ Deleted mismatched temp file for fresh start');
            } else if (actualSize > startByte) {
              // File is larger than saved progress - use actual size
              // This happens when buffered writes weren't accounted for in saved progress
              print('✅ File is larger than saved progress - using actual file size');
              print('   This ensures we resume from the correct position');
              startByte = actualSize;
              
              // Update saved progress to match actual file size
              await _storageService.savePartialDownloadInfo(videoId, actualSize, totalBytes);
              print('💾 Updated saved progress to match actual file size: ${actualSize / 1024 / 1024} MB');
            } else if (actualSize < startByte) {
              // Temp file is smaller - use actual size
              print('⚠️ Temp file smaller than saved progress, using actual file size');
              startByte = actualSize;
              
              // Update saved progress to match actual file size
              await _storageService.savePartialDownloadInfo(videoId, actualSize, totalBytes);
              print('💾 Updated saved progress to match actual file size: ${actualSize / 1024 / 1024} MB');
            }
          }
        } catch (e) {
          print('⚠️ Error checking temp file size: $e');
          // If we can't read the file, delete it and start fresh
          try {
            await tempFile.delete();
            print('🗑️ Deleted temp file due to error');
            startByte = 0;
          } catch (deleteError) {
            print('❌ Error deleting temp file: $deleteError');
          }
        }
      }

      // CRITICAL: Always create/ensure file exists before opening
      if (!await tempFile.exists()) {
        await tempFile.create(recursive: true);
      }

      // CRITICAL FIX: When resuming, we MUST ensure the file is exactly the size we expect
      // before opening it. This prevents corruption from multiple resume operations.
      if (startByte > 0) {
        // Resuming - ensure file is exactly startByte bytes
        final actualSize = await tempFile.length();
        
        if (actualSize != startByte) {
          print('⚠️ File size mismatch before resume!');
          print('   Actual: $actualSize bytes, Expected: $startByte bytes');
          
          if (actualSize > startByte) {
            // File is larger than expected - truncate to exact position
            print('✂️ Truncating file to exact resume position: $startByte bytes');
            final truncateRaf = await tempFile.open(mode: FileMode.write);
            await truncateRaf.truncate(startByte);
            await truncateRaf.close();
            
            // Verify truncation worked
            final verifySize = await tempFile.length();
            if (verifySize != startByte) {
              print('❌ Truncation failed! File size: $verifySize, Expected: $startByte');
              throw Exception('Failed to truncate file to resume position');
            }
            print('✅ File truncated successfully to: $startByte bytes');
          } else {
            // File is smaller - this shouldn't happen after our checks above
            // Use actual size as the resume position
            print('⚠️ File is smaller than expected, using actual size: $actualSize bytes');
            startByte = actualSize;
            await _storageService.savePartialDownloadInfo(videoId, actualSize, totalBytes);
          }
        } else {
          print('✅ File size matches resume position: $startByte bytes');
        }
      }

      // CRITICAL: Open file in append mode when resuming, write mode for fresh downloads
      // Append mode automatically positions at the end of the file, ensuring we write
      // from the correct position without risk of corruption
      if (startByte > 0) {
        // Resuming - open in append mode (automatically positions at end = startByte)
        raf = await tempFile.open(mode: FileMode.append);
        final currentPos = await raf.position();
        print('📍 Opened file in append mode for resume');
        print('   File size: $startByte bytes, Position: $currentPos bytes');
        
        // In append mode, position should be at the end of the file
        // If it's not, something is wrong
        if (currentPos != startByte) {
          print('⚠️ Position mismatch in append mode! Expected: $startByte, Got: $currentPos');
          // Close and reopen to ensure correct state
          await raf.close();
          // Re-verify file size
          final verifySize = await tempFile.length();
          if (verifySize != startByte) {
            throw Exception('File size mismatch after truncation: $verifySize != $startByte');
          }
          raf = await tempFile.open(mode: FileMode.append);
          final newPos = await raf.position();
          if (newPos != startByte) {
            throw Exception('Failed to open file at resume point: expected $startByte, got $newPos');
          }
          print('✅ File reopened and positioned correctly at: $startByte bytes');
        }
      } else {
        // Fresh download - open in write mode (creates/truncates file)
        raf = await tempFile.open(mode: FileMode.write);
        print('📍 Opened file for fresh download from byte 0');
      }

      int downloadedBytes = startByte;
      int lastProgressUpdate = 0;
      int lastSaveTime = DateTime.now().millisecondsSinceEpoch;

      // Save initial progress with valid total bytes
      if (startByte == 0) {
        await _storageService.savePartialDownloadInfo(videoId, 0, totalBytes);
        print('💾 Saved initial progress: 0 MB / ${totalBytes / 1024 / 1024} MB');
      }

      // Download the file with cancellation checks
      await for (final chunk in response.data!.stream) {
        // Check for cancellation before processing each chunk
        if (cancelToken.isCancelled) {
          print('⏸️ Download cancelled during stream processing');
          await raf?.close();
          raf = null;
          
          // Save current progress
          await _storageService.savePartialDownloadInfo(videoId, downloadedBytes, totalBytes);
          
          throw DioException(
            requestOptions: response.requestOptions,
            error: 'Download cancelled by user',
            type: DioExceptionType.cancel,
          );
        }

        await raf?.writeFrom(chunk);
        downloadedBytes += chunk.length;

        // Update progress
        if (downloadedBytes - lastProgressUpdate >= 256 * 1024 ||
            downloadedBytes >= totalBytes) {
          onProgress(downloadedBytes, totalBytes);
          lastProgressUpdate = downloadedBytes;
        }

        // Save progress periodically
        final currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - lastSaveTime >= 5000 || 
            downloadedBytes - lastProgressUpdate >= 5 * 1024 * 1024) {
          await _storageService.savePartialDownloadInfo(videoId, downloadedBytes, totalBytes);
          lastSaveTime = currentTime;
        }

        // Log progress
        if (downloadedBytes % (1024 * 1024) < chunk.length) {
          final progress = downloadedBytes / totalBytes;
          print('📥 Download progress: ${(progress * 100).toStringAsFixed(1)}% ($downloadedBytes/$totalBytes bytes)');
        }
      }

      // CRITICAL: Ensure all data is flushed to disk before closing
      if (raf != null) {
        await raf.flush();
        await raf.close();
        raf = null;
      }
      
      // Wait for filesystem to sync
      await Future.delayed(Duration(milliseconds: 200));

      // Verify download
      final finalSize = await tempFile.length();
      print('📁 Final temp file size: ${finalSize / 1024 / 1024} MB');
      print('📊 Expected size: ${totalBytes / 1024 / 1024} MB');
      print('📊 Downloaded bytes tracked: $downloadedBytes');

      // CRITICAL: Verify downloadedBytes matches file size
      if ((downloadedBytes - finalSize).abs() > 1024) {
        print('⚠️ WARNING: Downloaded bytes mismatch!');
        print('   Tracked: $downloadedBytes bytes');
        print('   File size: $finalSize bytes');
        // Use actual file size as source of truth
        downloadedBytes = finalSize;
      }

      if (finalSize < totalBytes) {
        throw Exception('Download incomplete: $finalSize/$totalBytes bytes');
      }

      // Additional verification - check file size matches total
      if ((finalSize - totalBytes).abs() > 1024) { // Allow 1KB tolerance
        print('⚠️ Warning: File size mismatch detected');
        print('   Downloaded: $finalSize bytes');
        print('   Expected: $totalBytes bytes');
        throw Exception('Download size verification failed: $finalSize != $totalBytes');
      }

      // CRITICAL: Ensure file is fully written before rename
      // Force sync the file to disk
      try {
        // Open the file in read mode to ensure it's fully written
        final verifyFile = await tempFile.open(mode: FileMode.read);
        await verifyFile.close();
      } catch (e) {
        print('⚠️ Warning: File verification failed: $e');
      }

      // Now it's safe to rename
      print('📝 Renaming temp file to final location...');
      await tempFile.rename(filePath);
      
      // Verify the renamed file exists and has correct size
      if (await finalFile.exists()) {
        final verifySize = await finalFile.length();
        print('✅ Renamed file verified: ${verifySize / 1024 / 1024} MB');
        
        if (verifySize < totalBytes - 1024) { // Allow 1KB tolerance
          throw Exception('Renamed file is corrupted: $verifySize/$totalBytes bytes');
        }
      } else {
        throw Exception('Renamed file does not exist at: $filePath');
      }
      
      downloadedFilePath = filePath;

      print('✅ Download complete. Final file size: ${(await finalFile.length()) / 1024 / 1024} MB');

      // Update storage
      await _storageService.saveVideoPath(videoId, filePath);
      await _storageService.addVideoToDownloadedList(videoId);
      await _storageService.removePartialDownloadInfo(videoId);

      onStatusChange?.call('completed');

    } on DioException catch (e) {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }

      // Handle cancellation specifically
      if (e.type == DioExceptionType.cancel) {
        print('⏸️ Download cancelled by user: $videoId');
        onStatusChange?.call('paused');
        
        // CRITICAL: Save actual file size, not tracked bytes
        if (tempFilePath != null && totalBytes > 0) {
          try {
            // Ensure file is closed and flushed
            if (raf != null) {
              try {
                await raf.flush();
                await raf.close();
              } catch (_) {}
              raf = null;
            }
            
            // Wait longer for filesystem to sync all buffered writes
            await Future.delayed(Duration(milliseconds: 500));
            
            final tempFile = File(tempFilePath);
            if (await tempFile.exists()) {
              // Get actual file size after all writes are flushed
              final currentSize = await tempFile.length();
              
              // CRITICAL: Always use actual file size, but ensure it doesn't exceed total
              if (currentSize > 0) {
                if (currentSize <= totalBytes) {
                  // Use actual file size as source of truth
                  await _storageService.savePartialDownloadInfo(videoId, currentSize, totalBytes);
                  print('💾 Saved actual file progress: ${currentSize / 1024 / 1024} MB / ${totalBytes / 1024 / 1024} MB');
                } else {
                  // File is larger than expected - this should not happen, but truncate to be safe
                  print('⚠️ File size ($currentSize) exceeds expected total ($totalBytes), truncating...');
                  final rafTemp = await tempFile.open(mode: FileMode.write);
                  await rafTemp.truncate(totalBytes);
                  await rafTemp.close();
                  final newSize = await tempFile.length();
                  await _storageService.savePartialDownloadInfo(videoId, newSize, totalBytes);
                  print('💾 Saved truncated progress: ${newSize / 1024 / 1024} MB / ${totalBytes / 1024 / 1024} MB');
                }
              }
            }
          } catch (saveError) {
            print('Error saving progress on cancellation: $saveError');
          }
        }
        
        rethrow;
      }

      print('❌ Error downloading video: $e');
      onStatusChange?.call('error');

      // Save progress only if we have valid data
      if (downloadedFilePath == null && tempFilePath != null && totalBytes > 0) {
        try {
          // Ensure file is closed
          if (raf != null) {
            try {
              await raf.flush();
              await raf.close();
            } catch (_) {}
            raf = null;
          }
          
          await Future.delayed(Duration(milliseconds: 100));
          
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            final currentSize = await tempFile.length();
            if (currentSize > 0 && currentSize <= totalBytes) {
              // Use actual file size as source of truth
              await _storageService.savePartialDownloadInfo(videoId, currentSize, totalBytes);
              print('💾 Saved actual file progress: ${currentSize / 1024 / 1024} MB / ${totalBytes / 1024 / 1024} MB');
            } else if (currentSize > totalBytes) {
              // File is larger than expected - truncate it
              print('⚠️ File size exceeds expected total, truncating...');
              final rafTemp = await tempFile.open(mode: FileMode.write);
              await rafTemp.truncate(totalBytes);
              await rafTemp.close();
              final newSize = await tempFile.length();
              await _storageService.savePartialDownloadInfo(videoId, newSize, totalBytes);
              print('💾 Saved truncated progress: ${newSize / 1024 / 1024} MB / ${totalBytes / 1024 / 1024} MB');
            }
          } else {
            print('⚠️ Temp file does not exist, cannot save progress');
            await _storageService.removePartialDownloadInfo(videoId);
          }
        } catch (saveError) {
          print('Error saving progress on failure: $saveError');
          try {
            await _storageService.removePartialDownloadInfo(videoId);
          } catch (_) {}
        }
      }

      rethrow;
    } catch (e, stackTrace) {
      if (raf != null) {
        try {
          await raf.close();
        } catch (_) {}
      }

      print('❌ Error downloading video: $e');
      print('📋 Stack trace: $stackTrace');
      onStatusChange?.call('error');

      // Save progress only if we have valid data
      if (downloadedFilePath == null && tempFilePath != null && totalBytes > 0) {
        try {
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            final currentSize = await tempFile.length();
            if (currentSize > 0) {
              await _storageService.savePartialDownloadInfo(videoId, currentSize, totalBytes);
              print('💾 Saved current progress: ${currentSize / 1024 / 1024} MB');
            }
          } else {
            print('⚠️ Temp file does not exist, cannot save progress');
            await _storageService.removePartialDownloadInfo(videoId);
          }
        } catch (saveError) {
          print('Error saving progress on failure: $saveError');
          try {
            await _storageService.removePartialDownloadInfo(videoId);
          } catch (_) {}
        }
      }

      rethrow;
    }

    print('========== VIDEO DOWNLOAD ${downloadedFilePath != null ? "SUCCESS" : "FAILED"} ==========');
    return downloadedFilePath;
  }

  Future<bool> _validateDownloadedFile(String filePath, int expectedSize) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ Downloaded file does not exist: $filePath');
        return false;
      }

      final actualSize = await file.length();
      if (actualSize < expectedSize * 0.95) {
        print('❌ Downloaded file size mismatch: $actualSize vs expected $expectedSize');
        return false;
      }

      print('✅ Downloaded file validation passed: ${actualSize / 1024 / 1024} MB');
      return true;
    } catch (e) {
      print('❌ Error validating downloaded file: $e');
      return false;
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

  Future<Map<String, dynamic>?> getDownloadInfo(String videoId) async {
    return await _storageService.getPartialDownloadInfo(videoId);
  }

  Future<bool> deletePrivateVideo(String videoId) async {
    try {
      final String? savedPath = await _storageService.getVideoPath(videoId);

      if (savedPath != null && savedPath.isNotEmpty) {
        final File videoFile = File(savedPath);
        if (await videoFile.exists()) {
          await videoFile.delete();

          await _storageService.saveVideoPath(videoId, '');
          await _storageService.removeVideoFromDownloadedList(videoId);

          return true;
        }
      }

      return false;
    } catch (e) {
      print('Error deleting private video: $e');
      return false;
    }
  }

  Future<bool> isVideoDownloaded(String videoId) async {
    try {
      final String? savedPath = await _storageService.getVideoPath(videoId);

      if (savedPath != null && savedPath.isNotEmpty) {
        final File videoFile = File(savedPath);
        if (await videoFile.exists()) {
          final fileSize = await videoFile.length();
          return fileSize > 0;
        }
      }

      return false;
    } catch (e) {
      print('Error checking if video is downloaded: $e');
      return false;
    }
  }

  Future<String?> getPrivateVideoPath(String videoId) async {
    try {
      return await _storageService.getVideoPath(videoId);
    } catch (e) {
      print('Error getting private video path: $e');
      return null;
    }
  }

  String getVideoStreamUrl(String videoId, {bool download = false}) {
    return '$baseUrl/videos/stream/$videoId${download ? '?download=true' : ''}';
  }
}