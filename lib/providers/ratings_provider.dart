import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';

/// Aggregated rating data for an app
class RatingAggregate {
  final double average;
  final int totalCount;
  final Map<int, int> breakdown; // star -> count
  final List<Comment> ratingComments; // all comments with rating tags

  const RatingAggregate({
    required this.average,
    required this.totalCount,
    required this.breakdown,
    required this.ratingComments,
  });

  const RatingAggregate.empty()
      : average = 0,
        totalCount = 0,
        breakdown = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        ratingComments = const [];

  /// Get the percentage (0-1) for a given star level
  double percentageFor(int star) {
    if (totalCount == 0) return 0;
    return (breakdown[star] ?? 0) / totalCount;
  }
}

/// Extract rating value from a Comment's event tags.
/// Returns null if no valid rating tag is present.
int? extractRating(Comment comment) {
  // Look for ["rating", "N"] tag
  for (final tag in comment.event.tags) {
    if (tag.length >= 2 && tag[0] == 'rating') {
      final value = int.tryParse(tag[1]);
      if (value != null && value >= 1 && value <= 5) {
        return value;
      }
    }
  }
  return null;
}

/// Compute aggregate from a list of comments that have rating tags.
/// Takes only the latest rating per user.
RatingAggregate computeAggregate(List<Comment> allComments) {
  // Filter to only those with valid rating tags
  final rated = <Comment>[];
  for (final c in allComments) {
    if (extractRating(c) != null) {
      rated.add(c);
    }
  }

  if (rated.isEmpty) return const RatingAggregate.empty();

  // Keep only latest rating per pubkey
  final byAuthor = <String, Comment>{};
  for (final c in rated) {
    final existing = byAuthor[c.event.pubkey];
    if (existing == null || c.createdAt.isAfter(existing.createdAt)) {
      byAuthor[c.event.pubkey] = c;
    }
  }

  final unique = byAuthor.values.toList();
  final breakdown = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  double sum = 0;

  for (final c in unique) {
    final r = extractRating(c)!;
    breakdown[r] = (breakdown[r] ?? 0) + 1;
    sum += r;
  }

  return RatingAggregate(
    average: sum / unique.length,
    totalCount: unique.length,
    breakdown: breakdown,
    ratingComments: unique..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
}

/// Filter aggregate to only ratings from followed pubkeys.
RatingAggregate filterByFollows(
  RatingAggregate full,
  Set<String>? followingPubkeys,
) {
  if (followingPubkeys == null || followingPubkeys.isEmpty) {
    return const RatingAggregate.empty();
  }

  final followed = full.ratingComments
      .where((c) => followingPubkeys.contains(c.event.pubkey))
      .toList();

  if (followed.isEmpty) return const RatingAggregate.empty();

  final breakdown = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  double sum = 0;

  for (final c in followed) {
    final r = extractRating(c)!;
    breakdown[r] = (breakdown[r] ?? 0) + 1;
    sum += r;
  }

  return RatingAggregate(
    average: sum / followed.length,
    totalCount: followed.length,
    breakdown: breakdown,
    ratingComments: followed,
  );
}
