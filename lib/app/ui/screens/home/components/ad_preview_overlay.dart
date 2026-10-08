import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/ad.dart';
import '../../../global_widgets/network_cover_image.dart';

class AdPreviewOverlay extends StatefulWidget {
  final Ad ad;
  final VoidCallback onWhatsApp;

  const AdPreviewOverlay({
    Key? key,
    required this.ad,
    required this.onWhatsApp,
  }) : super(key: key);

  static Future<void> show(
    BuildContext context, {
    required Ad ad,
    required VoidCallback onWhatsApp,
  }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'إغلاق الإعلان',
      barrierColor: Colors.black.withOpacity(0.92),
      transitionDuration: Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => AdPreviewOverlay(
        ad: ad,
        onWhatsApp: onWhatsApp,
      ),
      transitionBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOut),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AdPreviewOverlay> createState() => _AdPreviewOverlayState();
}

class _AdPreviewOverlayState extends State<AdPreviewOverlay> {
  static const Color _whatsappGreen = Color(0xFF25D366);
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: NetworkCoverImage(
                    url: widget.ad.imageUrl,
                    cacheKey: widget.ad.image,
                    fit: BoxFit.contain,
                    fallback: Icon(
                      Icons.campaign_outlined,
                      color: Colors.white54,
                      size: 72,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: _circleButton(
                icon: Icons.close_rounded,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    child: _showDetails
                        ? GestureDetector(
                            onTap: () {},
                            child: Container(
                              width: double.infinity,
                              margin: EdgeInsets.only(bottom: 16),
                              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: _AdLinkedText(text: widget.ad.title),
                            ),
                          )
                        : SizedBox.shrink(),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _circleButton(
                        icon: _showDetails
                            ? Icons.info_rounded
                            : Icons.info_outline_rounded,
                        onTap: () => setState(() => _showDetails = !_showDetails),
                        tooltip: 'التفاصيل',
                      ),
                      SizedBox(width: 22),
                      _whatsAppButton(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whatsAppButton() {
    return Tooltip(
      message: 'تواصل عبر واتساب',
      child: GestureDetector(
        onTap: widget.onWhatsApp,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _whatsappGreen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _whatsappGreen.withOpacity(0.45),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.chat_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    final button = GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip, child: button);
  }
}

class _AdLinkedText extends StatefulWidget {
  final String text;

  const _AdLinkedText({required this.text});

  @override
  State<_AdLinkedText> createState() => _AdLinkedTextState();
}

class _AdLinkedTextState extends State<_AdLinkedText> {
  static final _urlPattern = RegExp(
    r'(https?:\/\/[^\s]+|www\.[^\s]+)',
    caseSensitive: false,
  );

  final List<TapGestureRecognizer> _recognizers = [];
  late final List<InlineSpan> _spans;

  @override
  void initState() {
    super.initState();
    _spans = _buildSpans();
  }

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _openLink(String raw) async {
    var value = raw.replaceAll(RegExp(r'[),.]+$'), '');
    if (!value.toLowerCase().startsWith('http')) {
      value = 'https://$value';
    }
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  List<InlineSpan> _buildSpans() {
    const linkStyle = TextStyle(
      color: Color(0xFF7DD3FC),
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.45,
      decoration: TextDecoration.underline,
      decorationColor: Color(0xFF7DD3FC),
    );

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in _urlPattern.allMatches(widget.text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _openLink(url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(text: url, style: linkStyle, recognizer: recognizer));
      start = match.end;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    const baseStyle = TextStyle(
      color: Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.45,
    );

    return Text.rich(
      TextSpan(style: baseStyle, children: _spans),
      textAlign: TextAlign.center,
    );
  }
}
