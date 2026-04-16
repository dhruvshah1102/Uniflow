import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.ink100,
        borderRadius: borderRadius,
      ),
    );
  }
}

class LoadingSkeletonPage extends StatelessWidget {
  final int cardCount;
  final bool showHeader;

  const LoadingSkeletonPage({
    super.key,
    this.cardCount = 4,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (showHeader) ...[
          const SkeletonBox(width: 180, height: 28),
          const SizedBox(height: 10),
          const SkeletonBox(width: 240, height: 16),
          const SizedBox(height: 20),
        ],
        ...List.generate(cardCount, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(width: 120, height: 18),
                  const SizedBox(height: 10),
                  const SkeletonBox(height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 220, height: 14),
                  const SizedBox(height: 8),
                  const SkeletonBox(width: 150, height: 14),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
