import 'package:models/models.dart';

/// A NIP-32 app review (kind 1985) — unified rating + text review.
///
/// Event format:
/// ```json
/// {
///   "kind": 1985,
///   "content": "Works great, love the Nostr integration",
///   "tags": [
///     ["L", "review/app"],
///     ["l", "4/5", "review/app"],
///     ["a", "32267:<pubkey>:<app-identifier>"],
///     ["k", "32267"]
///   ]
/// }
/// ```
class AppReview extends RegularModel<AppReview> {
  AppReview.fromMap(super.map, super.ref) : super.fromMap();

  /// The review text content
  String get reviewContent => event.content;

  /// Extract the numeric score (1-5) from the `l` tag
  int? get score {
    for (final tag in event.tags) {
      if (tag.length >= 3 && tag[0] == 'l' && tag[2] == 'review/app') {
        final match = RegExp(r'^(\d)/5$').firstMatch(tag[1]);
        if (match != null) {
          final value = int.parse(match.group(1)!);
          if (value >= 1 && value <= 5) return value;
        }
      }
    }
    return null;
  }

  /// The `a` tag referencing the app being reviewed
  String? get appAddress => event.getFirstTagValue('a');

  /// The pubkey of the reviewer
  String get reviewerPubkey => event.pubkey;

  /// Whether this review has text content (not empty)
  bool get hasText => reviewContent.trim().isNotEmpty;
}

/// Partial model for creating new app reviews (kind 1985).
class PartialAppReview extends RegularPartialModel<AppReview> {
  PartialAppReview.fromMap(super.map) : super.fromMap();

  /// Creates a new NIP-32 app review
  ///
  /// [content] - Review text (can be empty for rating-only)
  /// [score] - Star rating 1-5
  /// [appAddress] - The addressable ID of the app (e.g. "32267:<pubkey>:<identifier>")
  PartialAppReview({
    required String content,
    required int score,
    required String appAddress,
  }) {
    assert(score >= 1 && score <= 5, 'Score must be between 1 and 5');
    event.content = content;
    event.addTag('L', ['review/app']);
    event.addTag('l', ['$score/5', 'review/app']);
    event.addTag('a', [appAddress]);
    event.addTag('k', ['32267']);
  }
}
