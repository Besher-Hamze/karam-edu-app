import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io' show Platform, Directory, File;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class PermissionManager {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static bool? _isXiaomiOrRedmi;
  static bool? _isSamsung;
  static int? _sdkVersion;
  static String? _deviceModel;
  static String? _deviceManufacturer;

  // Initialize device information
  static Future<void> _initDeviceInfo() async {
    if (_sdkVersion != null) return; // Already initialized

    if (Platform.isAndroid) {
      try {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceManufacturer = androidInfo.manufacturer?.toLowerCase() ?? "";
        _deviceModel = androidInfo.model;
        _sdkVersion = androidInfo.version.sdkInt ?? 0;
        _isXiaomiOrRedmi = _deviceManufacturer!.contains('xiaomi') ||
            _deviceManufacturer!.contains('redmi') ||
            _deviceManufacturer!.contains('poco');
        _isSamsung = _deviceManufacturer!.contains('samsung');

        print('Device: ${androidInfo.manufacturer} ${androidInfo.model}');
        print('Android SDK: $_sdkVersion');
        print('Is Xiaomi device: $_isXiaomiOrRedmi');
        print('Is Samsung device: $_isSamsung');
      } catch (e) {
        print('Error initializing device info: $e');
      }
    }
  }

  // Main method to request storage permission
  static Future<bool> requestStoragePermission() async {
    if (!Platform.isAndroid) {
      return true; // For iOS, always return true
    }

    // Initialize device info
    await _initDeviceInfo();

    // For Samsung devices on Android 13+ (API 33+), we'll bypass permission checks
    // and use private app storage instead
    if (_isSamsung! && _sdkVersion! >= 33) {
      print("Samsung A series detected. Using app's private storage without permission checks.");
      return await _setupPrivateStorageDirectories();
    }

    // For other devices, use standard permission handling
    if (_isXiaomiOrRedmi!) {
      return await _handleXiaomiPermissions();
    } else {
      return await _handleStandardPermissions();
    }
  }

  // Setup private storage directories that don't require permissions
  static Future<bool> _setupPrivateStorageDirectories() async {
    try {
      // First, get the app's private directory
      final appDir = await getApplicationDocumentsDirectory();

      // Create the videos directory
      final videosDir = Directory('${appDir.path}/videos');
      if (!await videosDir.exists()) {
        await videosDir.create(recursive: true);
      }

      // Create a hidden directory for secure videos
      final secureDir = Directory('${appDir.path}/.secured_videos');
      if (!await secureDir.exists()) {
        await secureDir.create(recursive: true);
      }

      // Create a .nomedia file to prevent scanning
      final nomediaFile = File('${secureDir.path}/.nomedia');
      if (!await nomediaFile.exists()) {
        await nomediaFile.create();
      }

      // Create a test file to verify write access
      final testFile = File('${secureDir.path}/test.txt');
      await testFile.writeAsString('test');
      await testFile.delete();

      print('Successfully set up private storage directories');
      return true;
    } catch (e) {
      print('Error setting up private storage: $e');
      return false;
    }
  }

  // Handle Xiaomi/Redmi device permissions
  static Future<bool> _handleXiaomiPermissions() async {
    try {
      // Request multiple permissions at once for Xiaomi devices
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        if (_sdkVersion! >= 33) Permission.photos,
        if (_sdkVersion! >= 33) Permission.videos,
        if (_sdkVersion! >= 33) Permission.audio,
        if (_sdkVersion! >= 30) Permission.manageExternalStorage,
        Permission.accessMediaLocation,
      ].request();

      // For debugging
      statuses.forEach((permission, status) {
        print('$permission: $status');
      });

      // Check if we have necessary permissions
      bool hasPermission = false;

      if (_sdkVersion! >= 33) {
        hasPermission = statuses[Permission.photos]?.isGranted == true ||
            statuses[Permission.videos]?.isGranted == true;
      } else if (_sdkVersion! >= 30) {
        hasPermission = statuses[Permission.manageExternalStorage]?.isGranted == true ||
            statuses[Permission.storage]?.isGranted == true;
      } else {
        hasPermission = statuses[Permission.storage]?.isGranted == true;
      }

      if (hasPermission) {
        return true;
      }

      // Show dialog if permissions not granted
      _showXiaomiPermissionDialog();
      return false;
    } catch (e) {
      print('Error handling Xiaomi permissions: $e');
      return false;
    }
  }

  // Standard Android permission handling
  static Future<bool> _handleStandardPermissions() async {
    try {
      if (_sdkVersion! >= 33) {
        // For Android 13+, request media permissions
        final statuses = await [
          Permission.photos,
          Permission.videos,
        ].request();

        if (statuses[Permission.photos]?.isGranted == true ||
            statuses[Permission.videos]?.isGranted == true) {
          return true;
        }
      } else if (_sdkVersion! >= 30) {
        // For Android 11+, try both storage and manage external storage
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          return true;
        }

        final manageStatus = await Permission.manageExternalStorage.request();
        if (manageStatus.isGranted) {
          return true;
        }
      } else {
        // For Android 10 and below
        final storageStatus = await Permission.storage.request();
        if (storageStatus.isGranted) {
          return true;
        }
      }

      // Show dialog if permissions not granted
      _showPermissionRationaleDialog();
      return false;
    } catch (e) {
      print('Error handling standard permissions: $e');
      return false;
    }
  }

  // Special dialog for Xiaomi/Redmi devices
  static void _showXiaomiPermissionDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
            'لأجهزة Xiaomi/Redmi، تحتاج إلى تمكين أذونات إضافية في إعدادات الأمان:\n\n'
                '1. انتقل إلى تطبيق الأمان > الأذونات\n'
                '2. ابحث عن هذا التطبيق\n'
                '3. قم بتمكين إذن "التخزين"\n'
                '4. إذا كان متاحًا، قم أيضًا بتمكين إذن "تثبيت التطبيقات غير المعروفة"'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(), // Close dialog
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              _openAppSettings(); // Open app settings
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  // Standard permission dialog
  static void _showPermissionRationaleDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Storage Permission Required'),
        content: const Text(
            'يحتاج هذا التطبيق إلى إذن التخزين لتنزيل وحفظ مقاطع الفيديو. '
                'يرجى منح إذن التخزين للمتابعة.'
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(), // Close dialog
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () {
              Get.back(); // Close dialog
              _openAppSettings(); // Open app settings
            },
            child: const Text('فتح الإعدادات'),
          ),
        ],
      ),
    );
  }

  // Open app settings to manually grant permission
  static Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  // Debug method to help troubleshoot permission issues
  static Future<void> debugPermissions() async {
    try {
      await _initDeviceInfo();

      print('Device Manufacturer: $_deviceManufacturer');
      print('Device Model: $_deviceModel');
      print('SDK Version: $_sdkVersion');

      print('Storage permission: ${await Permission.storage.status}');
      print('Manage External Storage permission: ${await Permission.manageExternalStorage.status}');
      print('Photos permission: ${await Permission.photos.status}');
      print('Videos permission: ${await Permission.videos.status}');
      print('Audio permission: ${await Permission.audio.status}');
      print('Access Media Location permission: ${await Permission.accessMediaLocation.status}');

      print('Is Xiaomi/Redmi device: $_isXiaomiOrRedmi');
      print('Is Samsung device: $_isSamsung');

      // Test private storage access
      print('Testing private storage access:');
      try {
        final appDir = await getApplicationDocumentsDirectory();
        print('App documents directory: ${appDir.path}');

        // Try to create a directory
        final testDir = Directory('${appDir.path}/test_dir');
        await testDir.create(recursive: true);
        print('Created test directory: ${testDir.path}');

        // Create a test file
        final testFile = File('${testDir.path}/test.txt');
        await testFile.writeAsString('Test content');
        print('Created test file with content');

        // Read the file
        final content = await testFile.readAsString();
        print('Read file content: $content');

        // Clean up
        await testFile.delete();
        await testDir.delete();
        print('Cleaned up test files');
      } catch (e) {
        print('Error testing private storage: $e');
      }
    } catch (e) {
      print('Error debugging permissions: $e');
    }
  }
}