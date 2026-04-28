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
    this.fit = BoxFit.contain,
    this.iconSize = 32,
    this.showLoader = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF18373D), Color(0xFF0B252B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: url == null || url.isEmpty
          ? _BookCoverFallback(iconSize: iconSize)
          : CachedNetworkImage(
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
              errorWidget: (_, __, ___) =>
                  _BookCoverFallback(iconSize: iconSize),
            ),
    );
  }
}

class _BookCoverFallback extends StatelessWidget {
  final double iconSize;

  const _BookCoverFallback({required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: iconSize * 1.7,
        height: iconSize * 2.3,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(iconSize * 0.22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          Icons.auto_stories_rounded,
          color: AppColors.accent.withValues(alpha: 0.72),
          size: iconSize,
        ),
      ),
    );
  }
}
