import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../theme/color_theme.dart';
import './splash_controller.dart';

class SplashScreen extends StatelessWidget {
  final SplashController controller = Get.put(SplashController());

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              ColorTheme.primary.withOpacity(0.95),
              ColorTheme.primaryDark,
            ],
            stops: [0.2, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: CustomPaint(
                  painter: BackgroundPatternPainter(),
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with animated container for entrance
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.8, end: 1.0),
                    duration: Duration(milliseconds: 1200),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Hero(
                            tag: 'app_logo',
                            child: Image.asset(
                              'assets/images/logo_2.png',
                              width: size.width * 0.25,
                              height: size.width * 0.25,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 50),

                  // Main title with animated opacity
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Text(
                          'منصة التعلم',
                          style: textTheme.displaySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                offset: Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 16),

                  // Subtitle with delayed animated opacity
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 800),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            'التعليم بين يديك',
                            style: textTheme.headlineSmall?.copyWith(
                              color: Colors.white.withOpacity(0.95),
                              fontWeight: FontWeight.w300,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  SizedBox(height: 70),

                  // Animated loading indicator
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: Duration(milliseconds: 500),
                    curve: Curves.easeIn,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Column(
                          children: [
                            // Custom animated loader
                            LoadingIndicator(size: 60),

                            SizedBox(height: 24),

                            // Loading text with animated dots
                            LoadingText(),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Bottom version info
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: 0.7,
                  child: Text(
                    'إصدار 1.0.0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                    ),
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

class BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final spacing = 30;

    // Draw grid of small circles
    for (var x = 0; x < size.width; x += spacing) {
      for (var y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x.toDouble(), y.toDouble()), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoadingIndicator extends StatelessWidget {
  final double size;

  const LoadingIndicator({Key? key, required this.size}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer circle
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (_, value, __) {
              return CircularProgressIndicator(
                value: null,  // Indeterminate
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.8)),
              );
            },
          ),

          // Inner circle with pulse animation
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.8, end: 1.2),
            duration: Duration(milliseconds: 1000),
            curve: Curves.easeInOut,
            builder: (_, double value, __) {
              return Container(
                width: size * 0.6 * value,
                height: size * 0.6 * value,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              );
            },
            child: Container(),
          ),
        ],
      ),
    );
  }
}

class LoadingText extends StatefulWidget {
  @override
  _LoadingTextState createState() => _LoadingTextState();
}

class _LoadingTextState extends State<LoadingText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<int> _dotsAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();

    _dotsAnimation = IntTween(begin: 0, end: 3).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _dotsAnimation,
      builder: (context, child) {
        String dots = '';
        for (int i = 0; i < _dotsAnimation.value; i++) {
          dots += '.';
        }

        return Text(
          'جاري التحميل$dots',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.5,
          ),
        );
      },
    );
  }
}