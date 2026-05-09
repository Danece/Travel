import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/app_localizations.dart';
import '../../../../core/utils/country_flag.dart';
import '../../../marker/domain/entities/marker_category.dart';
import '../../../marker/domain/entities/marker_entity.dart';
import '../../../marker/presentation/providers/marker_provider.dart';
import '../providers/home_provider.dart';


// ══════════════════════════════════════════════════════════════════════════════
// AppShell — 底部導覽列的持久容器
// ══════════════════════════════════════════════════════════════════════════════

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static int _locationToIndex(String location) {
    if (location.startsWith('/marker')) return 1;
    if (location.startsWith('/map')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  static String _indexToLocation(int index) {
    switch (index) {
      case 1:
        return '/marker';
      case 2:
        return '/map';
      case 3:
        return '/settings';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_indexToLocation(i)),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.place_outlined),
            selectedIcon: const Icon(Icons.place),
            label: l10n.navMarkers,
          ),
          NavigationDestination(
            icon: const Icon(Icons.map_outlined),
            selectedIcon: const Icon(Icons.map),
            label: l10n.navMap,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.navSettings,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HomePage
// ══════════════════════════════════════════════════════════════════════════════

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  void _showCountryBreakdown(
      BuildContext context, List<MarkerEntity> markers, AppLocalizations l10n) {
    final counts = <String, int>{};
    for (final m in markers) {
      counts[m.country] = (counts[m.country] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _showDetailSheet(
      context: context,
      title: l10n.footprintDistrib,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (_, i) {
          final e = sorted[i];
          final pct = markers.isEmpty ? 0.0 : e.value / markers.length;
          return ListTile(
            dense: true,
            leading: Text(countryFlag(e.key), style: const TextStyle(fontSize: 24)),
            title: Text(e.key),
            subtitle: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            trailing: Text(l10n.recordCount(e.value),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }

  void _showCountriesList(
      BuildContext context, List<MarkerEntity> markers, AppLocalizations l10n) {
    final countries = markers.map((m) => m.country).toSet().toList()..sort();

    _showDetailSheet(
      context: context,
      title: l10n.countriesListTitle(countries.length),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: countries.map((c) {
          return Chip(
            avatar: Text(countryFlag(c), style: const TextStyle(fontSize: 16)),
            label: Text(c),
          );
        }).toList(),
      ),
    );
  }

  void _showRatingBreakdown(
      BuildContext context, List<MarkerEntity> markers, AppLocalizations l10n) {
    final counts = List.filled(5, 0);
    for (final m in markers) {
      if (m.rating >= 1 && m.rating <= 5) counts[m.rating - 1]++;
    }
    final maxCount = counts.reduce((a, b) => a > b ? a : b);

    _showDetailSheet(
      context: context,
      title: l10n.ratingDistrib,
      child: Column(
        children: List.generate(5, (i) {
          final star = 5 - i;
          final count = counts[star - 1];
          final pct = maxCount == 0 ? 0.0 : count / maxCount;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Text('$star ★',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 14,
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.amber,
                    backgroundColor: Colors.amber.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text('$count',
                      textAlign: TextAlign.end,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showCategoryBreakdown(
      BuildContext context, List<MarkerEntity> markers, AppLocalizations l10n) {
    final counts = <MarkerCategory, int>{};
    for (final m in markers) {
      final cat = MarkerCategory.fromString(m.category);
      counts[cat] = (counts[cat] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    _showDetailSheet(
      context: context,
      title: l10n.categoryDistrib,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 56),
        itemBuilder: (_, i) {
          final e = sorted[i];
          final pct = markers.isEmpty ? 0.0 : e.value / markers.length;
          return ListTile(
            dense: true,
            leading: Text(e.key.emoji, style: const TextStyle(fontSize: 24)),
            title: Text(e.key.localizedLabel(l10n.isEn)),
            subtitle: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            trailing: Text(l10n.recordCount(e.value),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          );
        },
      ),
    );
  }

  void _showDetailSheet({
    required BuildContext context,
    required String title,
    required Widget child,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, controller) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final summaryAsync = ref.watch(travelSummaryProvider);
    final markersAsync = ref.watch(markerNotifierProvider);

    return Scaffold(
      body: SafeArea(
        child: summaryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('${l10n.loadFailed}：$e')),
          data: (summary) {
            final allMarkers = markersAsync.valueOrNull ?? [];
            final recentMarkers = () {
              final sorted = [...allMarkers]
                ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              return sorted.take(5).toList();
            }();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                _Header(l10n: l10n),
                const SizedBox(height: 20),

                // ── 快速入口 ──────────────────────────────────────────────
                _SectionTitle(l10n.homeQuickActions),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.add_location_alt_outlined,
                        label: l10n.homeAddMarker,
                        onTap: () => context.push('/marker/create'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.search_outlined,
                        label: l10n.homeSearchRecords,
                        onTap: () => context.go('/marker'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.map_outlined,
                        label: l10n.homeOpenMap,
                        onTap: () => context.go('/map'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── 統計概覽 ──────────────────────────────────────────────
                _SectionTitle(l10n.homeStats),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.35,
                  children: [
                    _StatCard(
                      icon: Icons.place_rounded,
                      value: '${summary.totalMarkers}',
                      unit: l10n.isEn ? '' : '筆',
                      label: l10n.homeTotalMarkers,
                      gradientColors: const [
                        Color(0xFFFF6B35),
                        Color(0xFFFF9500),
                      ],
                      onTap: allMarkers.isEmpty
                          ? null
                          : () => _showCountryBreakdown(
                              context, allMarkers, l10n),
                    ),
                    _StatCard(
                      icon: Icons.public_rounded,
                      value: '${summary.totalCountries}',
                      unit: l10n.isEn ? '' : '個',
                      label: l10n.homeTotalCountries,
                      gradientColors: const [
                        Color(0xFF8B5CF6),
                        Color(0xFFEC4899),
                      ],
                      onTap: allMarkers.isEmpty
                          ? null
                          : () =>
                              _showCountriesList(context, allMarkers, l10n),
                    ),
                    _StatCard(
                      icon: Icons.star_rounded,
                      value: summary.averageRating > 0
                          ? summary.averageRating.toStringAsFixed(1)
                          : '--',
                      unit: '',
                      label: l10n.homeAvgRating,
                      prefix: summary.averageRating > 0 ? '★ ' : '',
                      gradientColors: const [
                        Color(0xFF06B6D4),
                        Color(0xFF2563EB),
                      ],
                      onTap: allMarkers.isEmpty
                          ? null
                          : () =>
                              _showRatingBreakdown(context, allMarkers, l10n),
                    ),
                    _StatCard(
                      icon: Icons.category_rounded,
                      value: () {
                        if (allMarkers.isEmpty) return '--';
                        final counts = <MarkerCategory, int>{};
                        for (final m in allMarkers) {
                          final cat = MarkerCategory.fromString(m.category);
                          counts[cat] = (counts[cat] ?? 0) + 1;
                        }
                        final top = counts.entries
                            .reduce((a, b) => a.value >= b.value ? a : b)
                            .key;
                        return top.emoji;
                      }(),
                      unit: () {
                        if (allMarkers.isEmpty) return '';
                        final counts = <MarkerCategory, int>{};
                        for (final m in allMarkers) {
                          final cat = MarkerCategory.fromString(m.category);
                          counts[cat] = (counts[cat] ?? 0) + 1;
                        }
                        return counts.entries
                            .reduce((a, b) => a.value >= b.value ? a : b)
                            .key
                            .localizedLabel(l10n.isEn);
                      }(),
                      label: l10n.homeTopCategory,
                      gradientColors: const [
                        Color(0xFF10B981),
                        Color(0xFF059669),
                      ],
                      onTap: allMarkers.isEmpty
                          ? null
                          : () => _showCategoryBreakdown(
                              context, allMarkers, l10n),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // ── 最近新增 ──────────────────────────────────────────────
                Row(
                  children: [
                    _SectionTitle(l10n.homeRecentAdded),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/marker'),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        l10n.homeViewAll,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: recentMarkers.isEmpty
                      ? _EmptyRecentCard(l10n: l10n)
                      : PageView.builder(
                          padEnds: false,
                          controller:
                              PageController(viewportFraction: 0.88),
                          itemCount: recentMarkers.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: _RecentMarkerCard(
                              marker: recentMarkers[i],
                              onTap: () => context.push(
                                '/marker/${recentMarkers[i].id}',
                                extra: recentMarkers[i],
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 私有元件
// ══════════════════════════════════════════════════════════════════════════════

class _Header extends StatelessWidget {
  const _Header({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Travel Mark',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.homeSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.travel_explore,
          size: 36,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.unit,
    required this.label,
    required this.gradientColors,
    this.prefix = '',
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String unit;
  final String label;
  final String prefix;
  final List<Color> gradientColors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shadowColor = gradientColors.last.withValues(alpha: 0.45);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned(
                right: -22,
                top: -22,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                right: 16,
                bottom: -30,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.white),
                            children: [
                              TextSpan(
                                text: '$prefix$value',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  height: 1.1,
                                ),
                              ),
                              if (unit.isNotEmpty)
                                TextSpan(
                                  text: ' $unit',
                                  style: const TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                style: TextStyle(
                                  color:
                                      Colors.white.withValues(alpha: 0.85),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (onTap != null)
                              Icon(Icons.arrow_forward_ios_rounded,
                                  color:
                                      Colors.white.withValues(alpha: 0.6),
                                  size: 11),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentMarkerCard extends StatelessWidget {
  const _RecentMarkerCard({required this.marker, required this.onTap});

  final MarkerEntity marker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = marker.photoPaths.isNotEmpty;
    final firstPhoto = hasPhoto ? marker.photoPaths.first : null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (firstPhoto != null && File(firstPhoto).existsSync())
              Image.file(
                File(firstPhoto),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _defaultBackground(),
              )
            else
              _defaultBackground(),

            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                  stops: [0.4, 1.0],
                ),
              ),
            ),

            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    marker.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(countryFlag(marker.country),
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          marker.country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ),
                      _StarRow(rating: marker.rating),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultBackground() => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF283593)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      );
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.rating});
  final int rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_outline,
          color: Colors.amber,
          size: 12,
        ),
      ),
    );
  }
}

class _EmptyRecentCard extends StatelessWidget {
  const _EmptyRecentCard({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.homeNoRecords,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.homeStartRecord,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
