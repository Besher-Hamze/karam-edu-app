import 'package:course_platform/utils/constants.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:get/get.dart';
import 'dart:collection';
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
  Directory? _cachedVideoDirectory;
  static const Duration _defaultCacheDuration = Duration(days: 7);

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
  Future<p.Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool useOfflineCache = true,
    Duration? cacheDuration,
    bool forceRefresh = false,
  }) async {
    final effectiveDuration = cacheDuration ?? _defaultCacheDuration;
    final cacheKey = _buildCacheKey(path, queryParameters);

    if (useOfflineCache && !forceRefresh) {
      final hasInternet = await _hasInternetConnection();
      if (!hasInternet) {
        final cached = await _storageService.getHttpCache(cacheKey, maxAge: effectiveDuration);
        if (cached != null) {
          print('📡 Offline mode - serving cached response for $cacheKey');
          return _buildCachedResponse(path, queryParameters, cached);
        }
        final offlineError = DioException(
          requestOptions: RequestOptions(path: path, queryParameters: queryParameters ?? <String, dynamic>{}),
          error: 'No internet connection',
          type: DioExceptionType.connectionError,
        );
        _handleError(offlineError);
        throw offlineError;
      }
    }

    try {
      final response = await _dio.get(path, queryParameters: queryParameters);
      if (useOfflineCache && response.data != null) {
        await _storageService.saveHttpCache(cacheKey, response.data);
      }
      return response;
    } on DioException catch (e) {
      if (useOfflineCache && _isOfflineException(e)) {
        final cached = await _storageService.getHttpCache(cacheKey, maxAge: effectiveDuration);
        if (cached != null) {
          print('📡 Network unavailable - using cached response for $cacheKey');
          return _buildCachedResponse(path, queryParameters, cached);
        }
      }
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

  // Generate a secure random filename. Extension stays .mp4 so iOS can play it.
  String _generateSecureFilename() {
    final random = Random();
    final length = random.nextInt(5) + 8;

    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final randomString = List.generate(
        length,
            (index) => chars[random.nextInt(chars.length)]
    ).join();

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '$randomString-$timestamp.mp4';
  }

  /// iOS rename fails if the destination already exists. Android overwrites.
  Future<void> _moveTempToFinal(File tempFile, String filePath) async {
    final destination = File(filePath);
    if (await destination.exists()) {
      await destination.delete();
    }
    try {
      await tempFile.rename(filePath);
    } catch (e) {
      print('Rename failed, copying instead: $e');
      await tempFile.copy(filePath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
    }
  }

  /// FileMode.write empties the file on open, so truncating through it zero-fills the data.
  Future<void> _truncateFile(File file, int length) async {
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.truncate(length);
    } finally {
      await raf.close();
    }
    final size = await file.length();
    if (size != length) {
      throw Exception('Failed to truncate file to $length bytes (got $size)');
    }
  }

  Future<bool> _canWriteToDirectory(Directory dir) async {
    final testFile = File('${dir.path}/.perm_check_${DateTime.now().microsecondsSinceEpoch}');
    try {
      await testFile.create(recursive: true);
      await testFile.writeAsString('ok');
      await testFile.delete();
      return true;
    } catch (e) {
      print('Directory ${dir.path} is not writable: $e');
      try {
        if (await testFile.exists()) {
          await testFile.delete();
        }
      } catch (_) {}
      return false;
    }
  }

  Future<Directory?> _prepareVideoDirectory(Directory baseDir) async {
    try {
      final targetDir = Directory('${baseDir.path}/data_files');
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final canWrite = await _canWriteToDirectory(targetDir);
      if (canWrite) {
        return targetDir;
      }
    } catch (e) {
      print('Error preparing directory ${baseDir.path}: $e');
    }
    return null;
  }

  Future<Directory?> _getPersistentInternalDirectory() async {
    final List<Future<Directory?>> probes = [];

    try {
      final docs = await getApplicationDocumentsDirectory();
      probes.add(_prepareVideoDirectory(docs));
    } catch (e) {
      print('Unable to access documents directory: $e');
    }

    try {
      final support = await getApplicationSupportDirectory();
      probes.add(_prepareVideoDirectory(support));
    } catch (e) {
      print('Unable to access support directory: $e');
    }

    if (Platform.isAndroid) {
      try {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          probes.add(_prepareVideoDirectory(external));
        }
      } catch (e) {
        print('Unable to access external storage directory: $e');
      }
    }

    for (final probe in probes) {
      final dir = await probe;
      if (dir != null) {
        return dir;
      }
    }

    return null;
  }

  Future<Directory?> _getFallbackCacheDirectory() async {
    final List<Future<Directory?>> probes = [];

    try {
      final cache = await getApplicationCacheDirectory();
      probes.add(_prepareVideoDirectory(cache));
    } catch (e) {
      print('Unable to access cache directory: $e');
    }

    try {
      final temp = await getTemporaryDirectory();
      probes.add(_prepareVideoDirectory(temp));
    } catch (e) {
      print('Unable to access temporary directory: $e');
    }

    for (final probe in probes) {
      final dir = await probe;
      if (dir != null) {
        return dir;
      }
    }

    return null;
  }

  Future<bool> _isDirectoryStillUsable(Directory dir) async {
    if (!await dir.exists()) {
      return false;
    }
    return await _canWriteToDirectory(dir);
  }

  // Get best directory for storing videos (favor persistent internal storage)
  Future<Directory?> _getBestVideoDirectory() async {
    try {
      if (_cachedVideoDirectory != null &&
          await _isDirectoryStillUsable(_cachedVideoDirectory!)) {
        return _cachedVideoDirectory;
      }

      final persistentDir = await _getPersistentInternalDirectory();
      if (persistentDir != null) {
        _cachedVideoDirectory = persistentDir;
        print('Selected persistent directory for videos: ${persistentDir.path}');
        return persistentDir;
      }

      final fallbackDir = await _getFallbackCacheDirectory();
      if (fallbackDir != null) {
        _cachedVideoDirectory = fallbackDir;
        print('Using fallback cache directory for videos: ${fallbackDir.path}');
        return fallbackDir;
      }

      throw Exception('No writable directories found');
    } catch (e) {
      print('Error finding best video directory: $e');
      return null;
    }
  }

  Future<Directory> getPersistentVideoDirectory() async {
    final dir = await _getBestVideoDirectory();
    if (dir == null) {
      throw Exception('Unable to resolve persistent video directory');
    }
    return dir;
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
        final videoDir = await getPersistentVideoDirectory();

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
          // The bytes on disk are the only source of truth: saved progress lags behind the
          // file (it is written every few seconds), and resuming from it duplicates data.
          final tempFile = File(tempFilePath);
          if (await tempFile.exists()) {
            final actualSize = await tempFile.length();

            if (actualSize > savedTotalBytes || actualSize == 0) {
              print('⚠️ Temp file size $actualSize is invalid for total $savedTotalBytes, restarting');
              await tempFile.delete();
              await _storageService.removePartialDownloadInfo(videoId);
              startByte = 0;
            } else if (actualSize == savedTotalBytes) {
              print('✅ Temp file is complete ($actualSize bytes), finalizing');
              await _moveTempToFinal(tempFile, filePath);
              await _storageService.saveVideoPath(videoId, filePath);
              await _storageService.addVideoToDownloadedList(videoId);
              await _storageService.removePartialDownloadInfo(videoId);
              onProgress(actualSize, actualSize);
              onStatusChange?.call('completed');
              return filePath;
            } else {
              startByte = actualSize;
              totalBytes = savedTotalBytes;
              print('🔄 Resuming download from byte: $startByte (${startByte / 1024 / 1024} MB)');
              print('   Total expected: ${totalBytes / 1024 / 1024} MB');
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
          if (savedTotalBytes > 0 && tempSize == savedTotalBytes) {
            await _moveTempToFinal(tempFile, filePath);
            final finalSize = await finalFile.length();
            onProgress(finalSize, finalSize);
            await _storageService.removePartialDownloadInfo(videoId);
            return filePath;
          }
          await tempFile.delete();
        }
        await _storageService.removePartialDownloadInfo(videoId);
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
                if (await tempFile.length() < startByte) {
                  throw Exception('Server resumed past the end of the local file');
                }
                await _truncateFile(tempFile, startByte);
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

      // The request was already made from startByte, so the file must be made to match it,
      // never the other way round (moving startByte here appends bytes at the wrong offset).
      if (startByte == 0) {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } else {
        final actualSize = await tempFile.exists() ? await tempFile.length() : 0;
        if (actualSize < startByte) {
          await _storageService.savePartialDownloadInfo(videoId, actualSize, totalBytes);
          throw Exception('Temp file shrank to $actualSize bytes, expected $startByte');
        }
        if (actualSize > startByte) {
          print('✂️ Truncating temp file from $actualSize to resume position $startByte');
          await _truncateFile(tempFile, startByte);
        }
      }

      if (!await tempFile.exists()) {
        await tempFile.create(recursive: true);
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

      if (finalSize != totalBytes) {
        // Larger than the video means bytes were written twice; the file can't be repaired.
        final message = 'Download size verification failed: $finalSize != $totalBytes';
        print('❌ $message, discarding and restarting');
        await tempFile.delete();
        await _storageService.removePartialDownloadInfo(videoId);
        totalBytes = 0;
        throw Exception(message);
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
      await _moveTempToFinal(tempFile, filePath);
      
      // Verify the renamed file exists and has correct size
      if (await finalFile.exists()) {
        final verifySize = await finalFile.length();
        print('✅ Renamed file verified: ${verifySize / 1024 / 1024} MB');
        
        if (verifySize != totalBytes) {
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
                  print('⚠️ File size ($currentSize) exceeds expected total ($totalBytes), discarding');
                  await tempFile.delete();
                  await _storageService.removePartialDownloadInfo(videoId);
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
              print('⚠️ File size exceeds expected total, discarding');
              await tempFile.delete();
              await _storageService.removePartialDownloadInfo(videoId);
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
            if (currentSize > totalBytes) {
              await tempFile.delete();
              await _storageService.removePartialDownloadInfo(videoId);
            } else if (currentSize > 0) {
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

  String _buildCacheKey(String path, Map<String, dynamic>? queryParameters) {
    final buffer = StringBuffer(path);
    if (queryParameters != null && queryParameters.isNotEmpty) {
      final sorted = SplayTreeMap<String, dynamic>.from(queryParameters);
      buffer.write('?');
      buffer.write(sorted.entries
          .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value?.toString() ?? '')}')
          .join('&'));
    }
    return buffer.toString();
  }

  bool _isOfflineException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return true;
    }
    if (e.type == DioExceptionType.unknown && e.error is SocketException) {
      return true;
    }
    return false;
  }

  p.Response _buildCachedResponse(
      String path, Map<String, dynamic>? queryParameters, dynamic data) {
    return p.Response(
      data: data,
      statusCode: 200,
      statusMessage: 'OK (cached)',
      requestOptions: RequestOptions(
        path: path,
        queryParameters: queryParameters ?? <String, dynamic>{},
      ),
      extra: {'fromCache': true},
    );
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('example.com');
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}