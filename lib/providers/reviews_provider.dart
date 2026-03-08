import 'package:notemarket/models/app_review.dart';

/// Aggregated review data for an app
class ReviewAggregate {
  final double average;
  final int totalCount;
  final Map<int, int> breakdown; // star -> count
  final List<AppReview> reviews; // deduplicated, sorted by date desc

  const ReviewAggregate({
    required this.average,
    required this.totalCount,
    required this.breakdown,
    required this.reviews,
  });

  const ReviewAggregate.empty()
      : average = 0,
        totalCount = 0,
        breakdown = const {1: 0, 2: 0, 3: 0, 4: 0, 5: 0},
        reviews = const [];

  /// Get the percentage (0.0–1.0) for a given star level
  double percentageFor(int star) {
    if (totalCount == 0) return 0;
    return (breakdown[star] ?? 0) / totalCount;
  }

  /// Filter to only reviews from followed pubkeys
  ReviewAggregate filteredByFollows(Set<String>? followPubkeys) {
    if (followPubkeys == null || followPubkeys.isEmpty) {
      return const ReviewAggregate.empty();
    }
    final filtered =
        reviews.where((r) => followPubkeys.contains(r.reviewerPubkey)).toList();
    return _buildAggregate(filtered);
  }
}

/// Compute aggregate from a list of AppReview models.
/// Deduplicates by pubkey (keeps latest review per user).
ReviewAggregate computeReviewAggregate(List<AppReview> allReviews) {
  // Filter to only those with valid scores
  final scored = allReviews.where((r) => r.score != null).toList();
  if (scored.isEmpty) return const ReviewAggregate.empty();

  // Keep only latest review per pubkey
  final byAuthor = <String, AppReview>{};
  for (final r in scored) {
    final existing = byAuthor[r.reviewerPubkey];
    if (existing == null || r.createdAt.isAfter(existing.createdAt)) {
      byAuthor[r.reviewerPubkey] = r;
    }
  }

  return _buildAggregate(byAuthor.values.toList());
}

ReviewAggregate _buildAggregate(List<AppReview> unique) {
  if (unique.isEmpty) return const ReviewAggregate.empty();

  final breakdown = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
  double sum = 0;

  for (final r in unique) {
    final s = r.score!;
    breakdown[s] = (breakdown[s] ?? 0) + 1;
    sum += s;
  }

  return ReviewAggregate(
    average: sum / unique.length,
    totalCount: unique.length,
    breakdown: breakdown,
    reviews: unique..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
  );
}
