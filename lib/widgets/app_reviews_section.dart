import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:notemarket/models/app_review.dart';
import 'package:notemarket/providers/reviews_provider.dart';
import 'package:notemarket/services/notification_service.dart';
import 'package:notemarket/utils/extensions.dart';
import 'package:notemarket/widgets/auth_widgets.dart';
import 'package:notemarket/widgets/common/profile_avatar.dart';
import 'package:notemarket/widgets/common/profile_name_widget.dart';
import 'package:notemarket/widgets/star_rating_widget.dart';

/// Unified ratings & reviews section using NIP-32 (kind 1985).
class AppReviewsSection extends HookConsumerWidget {
  const AppReviewsSection({super.key, required this.app});

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch all kind 1985 reviews tagged with this app via `a` tag
    final reviewsState = ref.watch(
      query<AppReview>(
        tags: {
          '#a': {app.id},
          '#L': {'review/app'},
        },
        source: const LocalAndRemoteSource(stream: true, relays: 'social'),
        subscriptionPrefix: 'app-reviews',
      ),
    );

    final List<AppReview> allReviews = switch (reviewsState) {
      StorageData(:final models) => models,
      _ => [],
    };

    // Compute aggregate
    final aggregate = computeReviewAggregate(allReviews);

    // Get following pubkeys for "from follows" filter
    final signedInPubkey = ref.watch(Signer.activePubkeyProvider);
    final contactListState = signedInPubkey != null
        ? ref.watch(
            query<ContactList>(
              authors: {signedInPubkey},
              source: const LocalAndRemoteSource(
                relays: 'social',
                cachedFor: Duration(hours: 1),
              ),
            ),
          )
        : null;
    final followingPubkeys =
        contactListState?.models.firstOrNull?.followingPubkeys;
    final followsAggregate = aggregate.filteredByFollows(followingPubkeys);

    // Find current user's existing review
    final currentUserReview = signedInPubkey != null
        ? aggregate.reviews
            .where((r) => r.reviewerPubkey == signedInPubkey)
            .firstOrNull
        : null;

    // Tab state: 0 = All, 1 = From Follows
    final selectedTab = useState(0);
    final activeAggregate =
        selectedTab.value == 0 ? aggregate : followsAggregate;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text('Ratings & Reviews',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),

          // Write a review / edit existing
          _ReviewInputSection(
            app: app,
            existingReview: currentUserReview,
          ),
          const SizedBox(height: 16),

          // Tab selector (only show if signed in with follows)
          if (signedInPubkey != null &&
              followingPubkeys != null &&
              followingPubkeys.isNotEmpty)
            _TabSelector(
              selected: selectedTab.value,
              onChanged: (v) => selectedTab.value = v,
              followsCount: followsAggregate.totalCount,
              allCount: aggregate.totalCount,
            ),

          // Aggregate display
          if (activeAggregate.totalCount >= 1) ...[
            const SizedBox(height: 16),
            _AggregateDisplay(aggregate: activeAggregate),
          ],

          // Review list
          if (activeAggregate.reviews.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Reviews',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...activeAggregate.reviews.take(20).map(
                  (review) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ReviewCard(review: review),
                  ),
                ),
          ],

          // Empty state
          if (aggregate.totalCount == 0)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.star_outline_rounded,
                      size: 32,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.3)),
                  const SizedBox(height: 8),
                  Text(
                    'No reviews yet — be the first!',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

// ─── Review Input Section ───────────────────────────────────────────────────

class _ReviewInputSection extends HookConsumerWidget {
  const _ReviewInputSection({
    required this.app,
    required this.existingReview,
  });

  final App app;
  final AppReview? existingReview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(Signer.activePubkeyProvider) != null;
    final selectedRating = useState(existingReview?.score ?? 0);
    final reviewController =
        useTextEditingController(text: existingReview?.reviewContent ?? '');
    final isEditing = useState(existingReview == null);
    final isPublishing = useState(false);

    // Sync with prop when it changes
    useEffect(() {
      if (existingReview != null) {
        selectedRating.value = existingReview!.score ?? 0;
        reviewController.text = existingReview!.reviewContent;
        isEditing.value = false;
      }
      return null;
    }, [existingReview]);

    if (!isSignedIn) {
      return const SignInPrompt(
        message:
            'Sign in to review this app and help others discover great apps.',
      );
    }

    // Show existing review with edit button
    if (existingReview != null && !isEditing.value) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Your review',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => isEditing.value = true,
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF8B5CF6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            StarRatingDisplay(
                average: (existingReview!.score ?? 0).toDouble(), size: 20),
            if (existingReview!.hasText) ...[
              const SizedBox(height: 8),
              Text(
                existingReview!.reviewContent,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      );
    }

    // Review input form
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            existingReview != null ? 'Edit your review' : 'Rate this app',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),

          // Star selector
          StarRatingWidget(
            rating: selectedRating.value,
            size: 36,
            onChanged: isPublishing.value
                ? null
                : (value) => selectedRating.value = value,
          ),
          const SizedBox(height: 12),

          // Review text field
          TextField(
            controller: reviewController,
            maxLines: 3,
            minLines: 1,
            decoration: InputDecoration(
              hintText: 'Share your experience... (optional)',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .outline
                      .withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF8B5CF6),
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 12),

          // Submit / Cancel buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (existingReview != null)
                TextButton(
                  onPressed: () {
                    isEditing.value = false;
                    selectedRating.value = existingReview!.score ?? 0;
                    reviewController.text = existingReview!.reviewContent;
                  },
                  child: const Text('Cancel'),
                ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: selectedRating.value == 0 || isPublishing.value
                    ? null
                    : () async {
                        isPublishing.value = true;
                        try {
                          await _publishReview(
                            ref,
                            selectedRating.value,
                            reviewController.text.trim(),
                            context,
                          );
                          if (context.mounted) {
                            isEditing.value = false;
                          }
                        } finally {
                          if (context.mounted) {
                            isPublishing.value = false;
                          }
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                child: isPublishing.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(existingReview != null
                        ? 'Update Review'
                        : 'Submit Review'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _publishReview(
    WidgetRef ref,
    int stars,
    String text,
    BuildContext context,
  ) async {
    try {
      final signer = ref.read(Signer.activeSignerProvider);
      if (signer == null) {
        if (context.mounted) {
          context.showError('Sign in required',
              description: 'You need to sign in to review apps.');
        }
        return;
      }

      final review = PartialAppReview(
        content: text,
        score: stars,
        appAddress: app.id,
      );

      final signedReview = await review.signWith(signer);
      await signedReview.save();
      await signedReview.publish(source: RemoteSource(relays: 'social'));

      if (context.mounted) {
        context.showInfo(
            text.isNotEmpty ? 'Review published ⭐' : 'Rated $stars/5 ⭐');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Failed to publish review', technicalDetails: '$e');
      }
    }
  }
}

// ─── Tab Selector ───────────────────────────────────────────────────────────

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.selected,
    required this.onChanged,
    required this.followsCount,
    required this.allCount,
  });

  final int selected;
  final ValueChanged<int> onChanged;
  final int followsCount;
  final int allCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TabChip(
          label: 'All ($allCount)',
          isSelected: selected == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 8),
        _TabChip(
          label: 'From follows ($followsCount)',
          isSelected: selected == 1,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF8B5CF6)
              : Theme.of(context)
                  .colorScheme
                  .surfaceContainerHighest
                  .withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: isSelected ? Colors.white : null,
                fontWeight: isSelected ? FontWeight.w600 : null,
              ),
        ),
      ),
    );
  }
}

// ─── Aggregate Display ──────────────────────────────────────────────────────

class _AggregateDisplay extends StatelessWidget {
  const _AggregateDisplay({required this.aggregate});

  final ReviewAggregate aggregate;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Big score
        Column(
          children: [
            Text(
              aggregate.average.toStringAsFixed(1),
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            StarRatingDisplay(average: aggregate.average, size: 18),
            const SizedBox(height: 4),
            Text(
              '${aggregate.totalCount} rating${aggregate.totalCount != 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
          ],
        ),
        const SizedBox(width: 24),
        // Breakdown bars
        Expanded(
          child: Column(
            children: List.generate(5, (i) {
              final star = 5 - i;
              final pct = aggregate.percentageFor(star);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    SizedBox(
                      width: 14,
                      child: Text(
                        '$star',
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const Icon(Icons.star_rounded,
                        size: 12, color: Color(0xFFFFD700)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFFFD700)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${aggregate.breakdown[star] ?? 0}',
                        style: Theme.of(context).textTheme.labelSmall,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ─── Individual Review Card ─────────────────────────────────────────────────

class _ReviewCard extends HookConsumerWidget {
  const _ReviewCard({required this.review});

  final AppReview review;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stars = review.score ?? 0;

    // Query author profile
    final authorState = ref.watch(
      query<Profile>(
        authors: {review.reviewerPubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
      ),
    );
    final author = authorState.models.firstOrNull;
    final isLoading = authorState is StorageLoading && author == null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileAvatar(profile: author, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ProfileNameWidget(
                        pubkey: review.reviewerPubkey,
                        profile: author,
                        isLoading: isLoading,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                            ),
                        skeletonWidth: 80,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, y').format(review.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                StarRatingDisplay(average: stars.toDouble(), size: 14),
                if (review.hasText) ...[
                  const SizedBox(height: 4),
                  Text(
                    review.reviewContent,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
