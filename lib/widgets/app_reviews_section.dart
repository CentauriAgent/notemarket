import 'package:async_button_builder/async_button_builder.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:models/models.dart';
import 'package:notemarket/providers/ratings_provider.dart';
import 'package:notemarket/services/notification_service.dart';
import 'package:notemarket/utils/extensions.dart';
import 'package:notemarket/widgets/auth_widgets.dart';
import 'package:notemarket/widgets/common/profile_avatar.dart';
import 'package:notemarket/widgets/common/profile_name_widget.dart';
import 'package:notemarket/widgets/star_rating_widget.dart';

/// Full ratings & reviews section for the app detail screen.
class AppReviewsSection extends HookConsumerWidget {
  const AppReviewsSection({super.key, required this.app});

  final App app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch all kind 1111 comments tagged with this app
    final commentsState = ref.watch(
      query<Comment>(
        tags: {
          '#A': {app.id},
        },
        source: LocalAndRemoteSource(stream: true, relays: 'social'),
        subscriptionPrefix: 'app-ratings',
      ),
    );

    final List<Comment> allComments = switch (commentsState) {
      StorageData(:final models) => models,
      _ => [],
    };

    // Compute aggregate from comments that have rating tags
    final aggregate = computeAggregate(allComments);

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
    final followsAggregate = filterByFollows(aggregate, followingPubkeys);

    // Find current user's existing rating
    final currentUserRating = signedInPubkey != null
        ? aggregate.ratingComments
            .where((c) => c.event.pubkey == signedInPubkey)
            .firstOrNull
        : null;
    final existingStars = currentUserRating != null
        ? extractRating(currentUserRating)
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

          // Rating input
          _RatingInputSection(
            app: app,
            existingStars: existingStars,
          ),
          const SizedBox(height: 16),

          // Tab selector (only show if signed in with follows)
          if (signedInPubkey != null && followingPubkeys != null && followingPubkeys.isNotEmpty)
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

          // Recent ratings list
          if (activeAggregate.ratingComments.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Recent Ratings',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...activeAggregate.ratingComments.take(20).map(
                  (comment) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _RatingCard(comment: comment),
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
                    'No ratings yet — be the first!',
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

// ─── Rating Input ───────────────────────────────────────────────────────────

class _RatingInputSection extends HookConsumerWidget {
  const _RatingInputSection({
    required this.app,
    required this.existingStars,
  });

  final App app;
  final int? existingStars;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(Signer.activePubkeyProvider) != null;
    final selectedRating = useState(existingStars ?? 0);
    final isPublishing = useState(false);

    // Sync with prop when it changes (e.g. after publishing)
    useEffect(() {
      if (existingStars != null) selectedRating.value = existingStars!;
      return null;
    }, [existingStars]);

    if (!isSignedIn) {
      return const SignInPrompt(
        message: 'Sign in to rate this app and help others discover great apps.',
      );
    }

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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  existingStars != null ? 'Your rating' : 'Rate this app',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 6),
                StarRatingWidget(
                  rating: selectedRating.value,
                  size: 32,
                  onChanged: isPublishing.value
                      ? null
                      : (value) async {
                          selectedRating.value = value;
                          isPublishing.value = true;
                          try {
                            await _publishRating(ref, value, context);
                          } finally {
                            if (context.mounted) {
                              isPublishing.value = false;
                            }
                          }
                        },
                ),
              ],
            ),
          ),
          if (isPublishing.value)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }

  Future<void> _publishRating(
    WidgetRef ref,
    int stars,
    BuildContext context,
  ) async {
    try {
      final signer = ref.read(Signer.activeSignerProvider);
      if (signer == null) {
        if (context.mounted) {
          context.showError('Sign in required',
              description: 'You need to sign in to rate apps.');
        }
        return;
      }

      // Build a PartialComment with rating tags
      final comment = PartialComment(
        content: '$stars/5 stars',
        rootModel: app,
      );

      // Add rating-specific tags
      comment.event.tags.add(['rating', '$stars']);
      comment.event.tags.add(['L', 'app-rating']);
      comment.event.tags.add(['l', '$stars', 'app-rating']);

      final signedComment = await comment.signWith(signer);
      await signedComment.save();
      await signedComment.publish(source: RemoteSource(relays: 'social'));

      if (context.mounted) {
        context.showInfo('Rated $stars/5 ⭐');
      }
    } catch (e) {
      if (context.mounted) {
        context.showError('Failed to publish rating', technicalDetails: '$e');
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

  final RatingAggregate aggregate;

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

// ─── Individual Rating Card ─────────────────────────────────────────────────

class _RatingCard extends HookConsumerWidget {
  const _RatingCard({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stars = extractRating(comment) ?? 0;

    // Query author profile
    final authorState = ref.watch(
      query<Profile>(
        authors: {comment.event.pubkey},
        source: const LocalAndRemoteSource(
          relays: {'social', 'vertex'},
          stream: false,
          cachedFor: Duration(hours: 2),
        ),
      ),
    );
    final author = authorState.models.firstOrNull;
    final isLoading = authorState is StorageLoading && author == null;

    // Check if content is just "N/5 stars" (auto-generated) or has real text
    final hasText = comment.content.isNotEmpty &&
        !RegExp(r'^\d/5 stars$').hasMatch(comment.content.trim());

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
                        pubkey: comment.event.pubkey,
                        profile: author,
                        isLoading: isLoading,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                            ),
                        skeletonWidth: 80,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d, y').format(comment.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                StarRatingDisplay(average: stars.toDouble(), size: 14),
                if (hasText) ...[
                  const SizedBox(height: 4),
                  Text(
                    comment.content,
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
