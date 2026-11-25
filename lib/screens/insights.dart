import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

/// How your testimonials are performing: views over time, where they're watched, and reply rate.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  String _k(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(1)}k' : '$n';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader('Insights')),
            Expanded(
              child: AsyncView<InsightsData>(
                load: repo.insights,
                skeletonCards: 3,
                builder: (context, d, refresh) {
                  final maxWeek = d.weeklyViews.isEmpty ? 1 : d.weeklyViews.reduce((a, b) => a > b ? a : b);
                  final maxPlat = d.byPlatform.isEmpty ? 1 : d.byPlatform.map((p) => p.views).reduce((a, b) => a > b ? a : b);
                  final growth = d.weeklyViews.length >= 2 && d.weeklyViews[d.weeklyViews.length - 2] > 0
                      ? ((d.weeklyViews.last - d.weeklyViews[d.weeklyViews.length - 2]) * 100 / d.weeklyViews[d.weeklyViews.length - 2]).round()
                      : 0;
                  return RefreshIndicator(
                    onRefresh: refresh,
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                      Row(children: [
                        Expanded(child: StatCard(icon: Icons.visibility_rounded, label: 'Views', value: _k(d.totalViews), delta: growth >= 0 ? '+$growth% this week' : '$growth% this week')),
                        const SizedBox(width: 12),
                        Expanded(child: StatCard(icon: Icons.play_circle_outline_rounded, label: 'Plays', value: _k(d.plays))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: StatCard(icon: Icons.ads_click_rounded, label: 'Link clicks', value: _k(d.linkClicks))),
                        const SizedBox(width: 12),
                        Expanded(child: StatCard(icon: Icons.timelapse_rounded, label: 'Avg. watched', value: '${d.avgWatchPercent}%')),
                      ]),
                      const SectionHeader('Views per week'),
                      AppCard(
                        child: SizedBox(
                          height: 190,
                          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            for (var i = 0; i < d.weeklyViews.length; i++)
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                                    Text('${d.weeklyViews[i]}', style: TextStyle(fontSize: 10.5, color: i == d.weeklyViews.length - 1 ? C.primary : C.muted, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 110 * d.weeklyViews[i] / maxWeek + 4,
                                      decoration: BoxDecoration(
                                        color: i == d.weeklyViews.length - 1 ? C.primary : C.primary.withValues(alpha: 0.35),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ).animate(delay: (70 * i).ms).scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, duration: 700.ms, curve: Curves.easeOutCubic),
                                    const SizedBox(height: 6),
                                    Text(i == d.weeklyViews.length - 1 ? 'Now' : '-${d.weeklyViews.length - 1 - i}w', style: TextStyle(fontSize: 10, color: C.muted)),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                      ),
                      const SectionHeader('Where they are watched'),
                      AppCard(
                        child: Column(children: [
                          for (final p in d.byPlatform)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Column(children: [
                                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                  Text(p.platform, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text('${p.views}', style: TextStyle(color: C.muted, fontWeight: FontWeight.w600)),
                                ]),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LiquidProgress(value: p.views / maxPlat, minHeight: 8, backgroundColor: C.surface2, color: C.primary),
                                ),
                              ]),
                            ),
                        ]),
                      ),
                      const SectionHeader('Invitation replies'),
                      AppCard(
                        child: Row(children: [
                          SizedBox(
                            width: 76,
                            height: 76,
                            child: Stack(alignment: Alignment.center, children: [
                              SizedBox(width: 76, height: 76, child: CircularProgressIndicator(value: d.responseRate, strokeWidth: 8, backgroundColor: C.surface2, color: C.green)),
                              Text('${(d.responseRate * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                            ]),
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Response rate', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                              SizedBox(height: 4),
                              Muted('Share of invited customers who recorded or wrote a testimonial. Recent customers reply more often than older ones.', size: 12.5),
                            ]),
                          ),
                        ]),
                      ),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      );
}
