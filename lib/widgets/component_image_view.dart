import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';

class ComponentImageView extends StatelessWidget {
  final String? imageSource;
  final double? height;
  final double? width;
  final BoxFit fit;

  const ComponentImageView({
    super.key,
    required this.imageSource,
    this.height,
    this.width,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final src = imageSource?.trim();

    if (src == null || src.isEmpty || src == 'none') {
      return _buildPlaceholder();
    }

    // 1. Check if it's an asset or starts with /res/
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        height: height ?? double.infinity,
        width: width ?? double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    if (src.startsWith('/res/')) {
      final assetPath = 'assets$src';
      return Image.asset(
        assetPath,
        height: height ?? double.infinity,
        width: width ?? double.infinity,
        fit: fit,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    // 2. Check if it's a web/http URL
    if (src.startsWith('http://') || src.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: src,
        height: height ?? double.infinity,
        width: width ?? double.infinity,
        fit: fit,
        placeholder: (_, _) => _buildLoading(),
        errorWidget: (_, _, _) => _buildPlaceholder(),
      );
    }

    // 3. Local file path (saved from camera/gallery)
    final file = File(src);
    if (file.existsSync()) {
      final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
      final int? cacheW = (width != null && width!.isFinite && width! > 0)
          ? (width! * pixelRatio).round()
          : null;
      final int? cacheH = (height != null && height!.isFinite && height! > 0)
          ? (height! * pixelRatio).round()
          : null;

      return Image.file(
        file,
        height: height ?? double.infinity,
        width: width ?? double.infinity,
        cacheWidth: cacheW,
        cacheHeight: cacheH,
        fit: fit,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, _, _) => _buildPlaceholder(),
      );
    }

    // Fallback if path doesn't exist on disk
    return _buildPlaceholder();
  }

  Widget _buildLoading() {
    return Container(
      height: height ?? double.infinity,
      width: width ?? double.infinity,
      color: AppColors.cardBgHighlight,
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: height ?? double.infinity,
      width: width ?? double.infinity,
      color: AppColors.cardBgElevated,
      child: Center(
        child: Text(
          '[NO MEDIA LINKED]',
          style: AppTypography.caption(color: AppColors.dimmer),
        ),
      ),
    );
  }
}
