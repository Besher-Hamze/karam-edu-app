import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Image from a signed URL. [cacheKey] must be stable (the storage key), because
/// the signed URL changes on every request.
class NetworkCoverImage extends StatelessWidget {
  final String? url;
  final String? cacheKey;
  final Widget fallback;
  final BoxFit fit;

  const NetworkCoverImage({
    Key? key,
    required this.url,
    required this.cacheKey,
    required this.fallback,
    this.fit = BoxFit.cover,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) return fallback;

    return CachedNetworkImage(
      imageUrl: url!,
      cacheKey: cacheKey,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(color: Colors.white),
      ),
      errorWidget: (_, __, ___) => fallback,
    );
  }
}
