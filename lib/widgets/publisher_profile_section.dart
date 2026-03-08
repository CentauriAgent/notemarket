import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:models/models.dart';
import 'package:notemarket/utils/extensions.dart';
import 'package:notemarket/widgets/common/profile_avatar.dart';
import 'package:notemarket/widgets/common/profile_name_widget.dart';

/// Enhanced publisher profile section for app detail page
/// Shows developer's Nostr profile with picture, NIP-05, and about info
class PublisherProfileSection extends HookConsumerWidget {
  const PublisherProfileSection({
    super.key,
    required this.pubkey,
    this.profile,
    this.isLoading = false,
  });

  final String pubkey;
  final Profile? profile;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (isLoading && profile == null) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Text(
            'Publisher',
            style: context.textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),

          // Profile row
          Row(
            children: [
              // Avatar
              SizedBox(
                width: 48,
                height: 48,
                child: ProfileAvatar(profile: profile, radius: 24),
              ),
              const SizedBox(width: 12),

              // Name and NIP-05
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ProfileNameWidget(
                      pubkey: pubkey,
                      profile: profile,
                      isLoading: isLoading,
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile?.nip05 != null && profile!.nip05!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            size: 14,
                            color: Color(0xFF8B5CF6),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              profile!.nip05!,
                              style: context.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF8B5CF6),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Lightning address indicator
              if (profile?.lud16 != null && profile!.lud16!.isNotEmpty)
                Tooltip(
                  message: 'Lightning: ${profile!.lud16}',
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('⚡', style: TextStyle(fontSize: 18)),
                  ),
                ),
            ],
          ),

          // About text
          if (profile?.about != null && profile!.about!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile!.about!,
              style: context.textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
