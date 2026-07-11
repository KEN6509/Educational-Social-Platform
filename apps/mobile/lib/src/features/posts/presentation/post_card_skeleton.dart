import 'package:flutter/material.dart';

import '../../../core/widgets/shimmer_skeleton.dart';

class PostCardSkeleton extends StatelessWidget {
  const PostCardSkeleton({
    required this.imageHeight,
    super.key,
  });

  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shadowColor: const Color(0x160B1F3E),
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE6F0F1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBlock(width: double.infinity, height: imageHeight, radius: 0),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBlock(
                  width: double.infinity,
                  height: 13,
                  radius: 6.5,
                ),
                SizedBox(height: 8),
                ShimmerBlock(width: 72, height: 12, radius: 6),
                SizedBox(height: 8),
                Row(
                  children: [
                    ShimmerBlock(width: 20, height: 20, radius: 10),
                    SizedBox(width: 6),
                    Expanded(
                      child: ShimmerBlock(
                        width: double.infinity,
                        height: 12,
                        radius: 6,
                      ),
                    ),
                    SizedBox(width: 12),
                    ShimmerBlock(width: 18, height: 18, radius: 9),
                    SizedBox(width: 6),
                    ShimmerBlock(width: 18, height: 11, radius: 5.5),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PostWaterfallSkeleton extends StatelessWidget {
  const PostWaterfallSkeleton({
    this.padding = const EdgeInsets.all(12),
    super.key,
  });

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                PostCardSkeleton(imageHeight: 190),
                SizedBox(height: 12),
                PostCardSkeleton(imageHeight: 150),
              ],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                PostCardSkeleton(imageHeight: 150),
                SizedBox(height: 12),
                PostCardSkeleton(imageHeight: 190),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
