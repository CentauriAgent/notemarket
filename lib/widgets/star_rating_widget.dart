import 'package:flutter/material.dart';

/// Reusable star rating display/input widget.
///
/// When [onChanged] is provided, stars are tappable (input mode).
/// When [onChanged] is null, stars are display-only.
class StarRatingWidget extends StatelessWidget {
  const StarRatingWidget({
    super.key,
    required this.rating,
    this.size = 24,
    this.color = const Color(0xFFFFD700),
    this.unselectedColor,
    this.onChanged,
    this.spacing = 2,
  });

  /// Current rating value (1-5). Use 0 for "no rating".
  final int rating;

  /// Size of each star icon.
  final double size;

  /// Color for filled stars.
  final Color color;

  /// Color for unfilled stars. Defaults to [color] at 30% opacity.
  final Color? unselectedColor;

  /// Called when user taps a star. Null = display only.
  final ValueChanged<int>? onChanged;

  /// Space between stars.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final filled = starIndex <= rating;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(starIndex) : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing / 2),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled
                  ? color
                  : (unselectedColor ?? color.withValues(alpha: 0.3)),
            ),
          ),
        );
      }),
    );
  }
}

/// Displays a fractional star rating (e.g. 4.2) using filled/half/empty icons.
class StarRatingDisplay extends StatelessWidget {
  const StarRatingDisplay({
    super.key,
    required this.average,
    this.size = 16,
    this.color = const Color(0xFFFFD700),
  });

  final double average;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        IconData icon;
        if (average >= starIndex) {
          icon = Icons.star_rounded;
        } else if (average >= starIndex - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
