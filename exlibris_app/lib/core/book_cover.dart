import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

const Map<String, String> bookCoverHttpHeaders = {
  'User-Agent':
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
};

class BookCover extends StatelessWidget {
  final String? imageUrl;
  final BoxFit fit;
  final double iconSize;
  final bool showLoader;

  const BookCover({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.iconSize = 32,
    this.showLoader = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return _BookCoverFallback(iconSize: iconSize);
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      httpHeaders: bookCoverHttpHeaders,
      placeholder: showLoader
          ? (_, __) => const Center(
              child: CircularProgressIndicator(
                color: AppColors.success,
                strokeWidth: 2,
              ),
            )
          : null,
      errorWidget: (_, __, ___) => _BookCoverFallback(iconSize: iconSize),
    );
  }
}

class _BookCoverFallback extends StatelessWidget {
  final double iconSize;

  const _BookCoverFallback({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Icon(
        Icons.menu_book_rounded,
        color: Colors.white24,
        size: iconSize,
      ),
    );
  }
}
