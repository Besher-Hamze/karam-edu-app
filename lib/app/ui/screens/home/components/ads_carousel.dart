import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../data/models/ad.dart';
import '../../../global_widgets/network_cover_image.dart';
import '../../../theme/color_theme.dart';

class AdsCarousel extends StatefulWidget {
  final List<Ad> ads;
  final void Function(Ad ad) onAdTap;

  const AdsCarousel({Key? key, required this.ads, required this.onAdTap})
      : super(key: key);

  @override
  State<AdsCarousel> createState() => _AdsCarouselState();
}

class _AdsCarouselState extends State<AdsCarousel> {
  static const Duration _autoScrollInterval = Duration(seconds: 5);

  final PageController _pageController = PageController(viewportFraction: 0.9);
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void didUpdateWidget(covariant AdsCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ads.length != widget.ads.length) {
      _currentPage = 0;
      _startAutoScroll();
    }
  }

  void _startAutoScroll() {
    _timer?.cancel();
    if (widget.ads.length < 2) return;
    _timer = Timer.periodic(_autoScrollInterval, (_) {
      if (!_pageController.hasClients) return;
      final next = (_currentPage + 1) % widget.ads.length;
      _pageController.animateToPage(
        next,
        duration: Duration(milliseconds: 480),
        curve: Curves.easeInOut,
      );
    });
  }

  void _pauseAutoScroll() => _timer?.cancel();

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ads.isEmpty) return SizedBox.shrink();

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollStartNotification) {
                _pauseAutoScroll();
              } else if (notification is ScrollEndNotification) {
                _startAutoScroll();
              }
              return false;
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.ads.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) => _buildAd(widget.ads[index]),
            ),
          ),
        ),
        if (widget.ads.length > 1) ...[
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.ads.length, (index) {
              final isActive = index == _currentPage;
              return AnimatedContainer(
                duration: Duration(milliseconds: 250),
                margin: EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive ? ColorTheme.primary : Colors.grey[300],
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildAd(Ad ad) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onAdTap(ad),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Hero(
                tag: 'ad-image-${ad.id}',
                child: NetworkCoverImage(
                  url: ad.imageUrl,
                  cacheKey: ad.image,
                  fallback: Container(
                    color: ColorTheme.primaryLight,
                    child: Icon(
                      Icons.campaign_outlined,
                      color: ColorTheme.primary,
                      size: 42,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
