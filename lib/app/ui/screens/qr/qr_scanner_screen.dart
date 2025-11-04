import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/color_theme.dart';
import '../../global_widgets/snackbar.dart';
import '../../../controllers/home_controller.dart';
import 'dart:ui' as ui;

class QrScannerScreen extends StatefulWidget {
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _hasPermission = false;
  bool _torchOn = false;
  bool _isHandling = false;
  late final AnimationController _scanController;
  late final Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
    _scanController = AnimationController(vsync: this, duration: Duration(seconds: 2))..repeat();
    _scanAnimation = CurvedAnimation(parent: _scanController, curve: Curves.easeInOut);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    setState(() {
      _hasPermission = status.isGranted;
    });
    if (!status.isGranted) {
      if (!mounted) return;
      ShamraSnackBar.show(
        context: context,
        message: 'يرجى منح إذن الكاميرا لاستخدام الماسح',
        type: SnackBarType.warning,
      );
    }
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isHandling) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _isHandling = true;
    final BuildContext ctx = context;
    
    // Send code to backend
    await _redeemCode(ctx, code);
  }

  Future<void> _redeemCode(BuildContext ctx, String code) async {
    try {
      final homeController = Get.find<HomeController>();
      final result = await homeController.redeemEnrollmentCode(code);
      
      Get.back();
      
      if (!mounted) return;
      
      ShamraSnackBar.show(
        context: ctx,
        message: result['message'] ?? (result['success'] ? 'تم التسجيل بنجاح' : 'فشل التحقق من الكود'),
        type: result['success'] ? SnackBarType.success : SnackBarType.error,
      );
    } catch (e) {
      Get.back();
      
      if (!mounted) return;
      
      ShamraSnackBar.show(
        context: ctx,
        message: 'حدث خطأ أثناء التحقق من الكود',
        type: SnackBarType.error,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? courseId = Get.parameters['courseId'];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: ColorTheme.primary,
        title: Text('مسح رمز QR'),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () async {
              await _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
          ),
          IconButton(
            icon: Icon(Icons.cameraswitch_outlined),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: ColorTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.qr_code_scanner, color: ColorTheme.primary),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('وجه الكاميرا نحو رمز QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('يمكنك أيضاً إدخال الكود يدوياً أدناه', style: TextStyle(color: Colors.grey[600])),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  _ManualCodeEntry(courseId: courseId),
                ],
              ),
            ),
            SizedBox(height: 16),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: _hasPermission
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          MobileScanner(
                            controller: _controller,
                            onDetect: _onDetect,
                          ),
                          _ScannerOverlay(animation: _scanAnimation),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 56,
                            child: Center(
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.45),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: Colors.black.withOpacity(0.35),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  IconButton(
                                    onPressed: () async {
                                      await _controller.toggleTorch();
                                      setState(() => _torchOn = !_torchOn);
                                    },
                                    icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off, color: Colors.white),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    _torchOn ? 'الفلاش: تشغيل' : 'الفلاش: إيقاف',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                                  ),
                                  Spacer(),
                                  IconButton(
                                    onPressed: () => _controller.switchCamera(),
                                    icon: Icon(Icons.cameraswitch_outlined, color: Colors.white),
                                  ),
                                  SizedBox(width: 8),
                                  Text('تبديل الكاميرا', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        color: Colors.grey[100],
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.camera_alt_outlined, color: Colors.grey[500], size: 48),
                            SizedBox(height: 8),
                            Text('إذن الكاميرا غير متاح', style: TextStyle(color: Colors.grey[600])),
                            SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _requestCameraPermission,
                              child: Text('منح الإذن'),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualCodeEntry extends StatefulWidget {
  final String? courseId;
  const _ManualCodeEntry({Key? key, this.courseId}) : super(key: key);

  @override
  State<_ManualCodeEntry> createState() => _ManualCodeEntryState();
}

class _ManualCodeEntryState extends State<_ManualCodeEntry> {
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitCode() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      ShamraSnackBar.show(
        context: context,
        message: 'يرجى إدخال الكود أولاً',
        type: SnackBarType.warning,
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final homeController = Get.find<HomeController>();
      final result = await homeController.redeemEnrollmentCode(value);
      
      if (!mounted) return;
      
      if (result['success']) {
        Get.back();
      }
      
      ShamraSnackBar.show(
        context: context,
        message: result['message'] ?? (result['success'] ? 'تم التسجيل بنجاح' : 'فشل التحقق من الكود'),
        type: result['success'] ? SnackBarType.success : SnackBarType.error,
      );
    } catch (e) {
      if (!mounted) return;
      
      ShamraSnackBar.show(
        context: context,
        message: 'حدث خطأ أثناء التحقق من الكود',
        type: SnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          textDirection: TextDirection.rtl,
          enabled: !_isSubmitting,
          decoration: InputDecoration(
            labelText: 'أو أدخل الكود يدوياً',
            hintText: 'XXXX-XXXX',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            prefixIcon: Icon(Icons.key_outlined),
          ),
        ),
        SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: _isSubmitting ? null : _submitCode,
          icon: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(Icons.check_circle_outline),
          label: Text(_isSubmitting ? 'جاري التحقق...' : 'تأكيد الكود'),
          style: ElevatedButton.styleFrom(backgroundColor: ColorTheme.primary),
        ),
      ],
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final Animation<double> animation;
  const _ScannerOverlay({Key? key, required this.animation}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double size = constraints.maxWidth * 0.72;
        return Stack(
          children: [
            Container(color: Colors.black.withOpacity(0.4)),
            Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.9), width: 2),
                ),
              ),
            ),
            Center(
              child: SizedBox(
                width: size,
                height: size,
                child: CustomPaint(
                  painter: _CornerPainter(color: Colors.white, stroke: 4, corner: 22),
                ),
              ),
            ),
            // Animated scan line
            Center(
              child: SizedBox(
                width: size,
                height: size,
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final double y = (size - 4) * animation.value;
                    return CustomPaint(painter: _ScanLinePainter(y: y));
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double stroke;
  final double corner;

  _CornerPainter({required this.color, required this.stroke, required this.corner});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Top-left
    canvas.drawLine(Offset(0, corner), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(corner, 0), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - corner, 0), Offset(size.width, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, corner), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, size.height - corner), Offset(0, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(corner, size.height), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - corner, size.height), Offset(size.width, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height - corner), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLinePainter extends CustomPainter {
  final double y;
  _ScanLinePainter({required this.y});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, y),
        Offset(size.width, y),
        [
          Colors.transparent,
          Colors.redAccent.withOpacity(0.95),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      ) 
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) => oldDelegate.y != y;
}
