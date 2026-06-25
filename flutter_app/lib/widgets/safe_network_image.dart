import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Safely loads and displays an image from either a network URL or a local file
/// path. Uses [CachedNetworkImage] for network images so previously-downloaded
/// media does not need to be re-fetched.
///
/// Shows a shimmer placeholder while loading and a fallback icon on error.
class SafeNetworkImage extends StatelessWidget {
  final String? imageUrl;
  final String? localFilePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final Color? fallbackColor;
  final Widget Function(BuildContext, String)? placeholder;

  const SafeNetworkImage({
    super.key,
    this.imageUrl,
    this.localFilePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
    this.fallbackColor,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    // Prefer local file over network URL
    if (localFilePath != null) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: Image.file(
          File(localFilePath!),
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, __, ___) => _fallback,
        ),
      );
    }

    if (imageUrl == null || imageUrl!.isEmpty) {
      return _fallback;
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder != null
            ? (context, url) => placeholder!(context, url)
            : (context, url) => _buildPlaceholder(context),
        errorWidget: (_, __, ___) => _fallback,
      ),
    );
  }

  Widget get _fallback {
    return Container(
      width: width,
      height: height,
      color: fallbackColor ?? Colors.grey[300],
      child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: fallbackColor ?? Colors.grey[200],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}
