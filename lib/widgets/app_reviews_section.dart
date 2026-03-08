import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:notemarket/utils/extensions.dart';
import 'package:notemarket/widgets/common/profile_avatar.dart';
import 'package:notemarket/widgets/common/profile_name_widget.dart';

/// Star rating widget for reviews
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 16,
    this.color = const Color(0xFFFFD700),
    this.onChanged,
  });

  final int rating;
  final double size;
  final Color color;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        return GestureDetector(
          onTap: onChanged != null ? () => onChanged!(starIndex) : null,
          child: Icon(
            starIndex <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: starIndex <= rating ? color : color.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

/// App reviews section showing user reviews fetched from Nostr
/// Reviews are kind 1111 notes tagged with the app's event ID
class AppReviewsSection extends HookConsumerWidget {
  const AppReviewsSection({
    super.key,
    required this.app,
  });

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // For now, show a placeholder reviews section with the ability to add reviews
    // In production, this would query kind 1111 events tagged with app ID
    final showAddReview = useState(false);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reviews',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  showAddReview.value = !showAddReview.value;
                },
                icon: Icon(
                  showAddReview.value ? Icons.close : Icons.rate_review_outlined,
                  size: 18,
                ),
                label: Text(showAddReview.value ? 'Cancel' : 'Write Review'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Add review form
          if (showAddReview.value)
            _AddReviewForm(
              app: app,
              onClose: () => showAddReview.value = false,
            ),

          // Placeholder message for reviews
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.reviews_outlined,
                  size: 32,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reviews are published as Nostr notes (kind 1111)',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Be the first to review this app!',
                  style: context.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF8B5CF6),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Form to add a new review
class _AddReviewForm extends HookWidget {
  const _AddReviewForm({
    required this.app,
    required this.onClose,
  });

  final App app;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final rating = useState(0);
    final reviewController = useTextEditingController();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rate this app',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),

          // Star rating
          StarRating(
            rating: rating.value,
            size: 32,
            onChanged: (value) => rating.value = value,
          ),
          const SizedBox(height: 12),

          // Review text
          TextField(
            controller: reviewController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Write your review...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                ),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 12),

          // Submit button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: rating.value > 0
                    ? () {
                        // In production, this would publish a kind 1111 note
                        // tagged with the app's event ID and the star rating
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Review publishing requires Nostr sign-in via Amber',
                            ),
                            backgroundColor: Color(0xFF8B5CF6),
                          ),
                        );
                        onClose();
                      }
                    : null,
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Publish Review'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
