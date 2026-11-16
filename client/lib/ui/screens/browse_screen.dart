import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/errors.dart';
import '../../data/discovery_providers.dart';
import '../../theme/tokens.dart';
import '../widgets/busy_banner.dart';
import '../widgets/error_state.dart';
import '../widgets/screen_scaffold.dart';
import '../widgets/section_header.dart';
import '../widgets/shelf_section.dart';
import '../widgets/skeleton.dart';

class BrowseScreen extends ConsumerWidget {
  const BrowseScreen({super.key});

  Color _hashColor(String title, MelodiaTokens tokens) {
    final hue = (title.hashCode.abs() % 360).toDouble();
    return HSVColor.fromAHSV(1.0, hue, 0.55, 0.35).toColor();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = Theme.of(context).extension<MelodiaTokens>()!;
    final chartsAsync = ref.watch(chartsProvider(null));
    final moodsAsync = ref.watch(moodsProvider);

    return ScreenScaffold(
      title: 'Browse',
      slivers: [
        // 1. Charts Section
        chartsAsync.when(
          data: (chartShelves) {
            if (chartShelves.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }
            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return ShelfSection(shelf: chartShelves[index]);
                },
                childCount: chartShelves.length,
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MelodiaTokens.spacingLg,
                vertical: MelodiaTokens.spacingMd,
              ),
              child: SkeletonCardList(count: 3),
            ),
          ),
          error: (err, _) {
            if (err is UpstreamBusyError) {
              return SliverToBoxAdapter(
                child: BusyBanner(
                  retryAfterSeconds: err.retryAfterSeconds,
                  onRetry: () => ref.invalidate(chartsProvider(null)),
                ),
              );
            }
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          },
        ),

        // 2. Moods & Genres Section
        moodsAsync.when(
          data: (moods) {
            if (moods.sections.isEmpty) {
              return const SliverToBoxAdapter(child: SizedBox.shrink());
            }

            final slivers = <Widget>[];

            for (final section in moods.sections) {
              slivers.add(
                Padding(
                  padding: const EdgeInsets.only(
                    left: MelodiaTokens.spacingLg,
                    right: MelodiaTokens.spacingLg,
                    top: MelodiaTokens.spacingLg,
                    bottom: MelodiaTokens.spacingMd,
                  ),
                  child: SectionHeader(
                    title: section.title,
                    subtitle: 'Explore playlists curated for ${section.title.toLowerCase()}',
                  ),
                ),
              );

              slivers.add(
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MelodiaTokens.spacingLg),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 200,
                      mainAxisSpacing: MelodiaTokens.spacingMd,
                      crossAxisSpacing: MelodiaTokens.spacingMd,
                      childAspectRatio: 1.6,
                    ),
                    itemCount: section.categories.length,
                    itemBuilder: (context, catIndex) {
                      final cat = section.categories[catIndex];
                      final tileColor = _hashColor(cat.title, tokens);

                      return Semantics(
                        button: true,
                        label: '${cat.title} category',
                        child: GestureDetector(
                          onTap: () {
                            final encodedParams = Uri.encodeComponent(cat.params);
                            final encodedTitle = Uri.encodeComponent(cat.title);
                            context.push('/mood/$encodedParams?title=$encodedTitle');
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: tileColor,
                              borderRadius: BorderRadius.circular(MelodiaTokens.radiusCard),
                              boxShadow: MelodiaTokens.cardShadow,
                            ),
                            padding: const EdgeInsets.all(MelodiaTokens.spacingMd),
                            alignment: Alignment.bottomLeft,
                            child: Text(
                              cat.title,
                              style: MelodiaTokens.headline.copyWith(
                                color: tokens.text,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );

              slivers.add(const SizedBox(height: MelodiaTokens.spacingXl));
            }

            return SliverList(delegate: SliverChildListDelegate(slivers));
          },
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(MelodiaTokens.spacingLg),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (err, _) {
            if (err is UpstreamBusyError) {
              return SliverToBoxAdapter(
                child: BusyBanner(
                  retryAfterSeconds: err.retryAfterSeconds,
                  onRetry: () => ref.invalidate(moodsProvider),
                ),
              );
            }
            return SliverFillRemaining(
              hasScrollBody: false,
              child: ErrorState(
                message: 'Failed to load browse categories.',
                onRetry: () => ref.invalidate(moodsProvider),
              ),
            );
          },
        ),
      ],
    );
  }
}
