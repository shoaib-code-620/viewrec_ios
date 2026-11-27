import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

String _k(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

/// How the Media page is doing, laid out like Instagram's insights: a period, reach, interactions, followers and your best posts.
class MediaInsightsScreen extends StatefulWidget {
  const MediaInsightsScreen({super.key});
  @override
  State<MediaInsightsScreen> createState() => _MediaInsightsScreenState();
}

class _MediaInsightsScreenState extends State<MediaInsightsScreen> {
  int days = 7;
  MediaInsights? d;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final want = days;
    try {
      final r = await repo.mediaInsights(want);
      if (mounted && want == days) {
        setState(() {
          d = r;
          failed = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  void _period(int v) {
    if (v == days) return;
    setState(() => days = v);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final m = d;
    return Scaffold(
      body: AppPage(children: [
        const BackHeader('Insights'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final v in const [7, 30, 90]) AppChip('Last $v days', active: days == v, onTap: () => _period(v)),
        ]),
        const SizedBox(height: 16),
        if (failed && m == null)
          const EmptyState(Icons.cloud_off_rounded, "Couldn't load your insights", 'Go back and try again in a moment.')
        else if (m == null)
          const Padding(padding: EdgeInsets.symmetric(vertical: 60), child: Center(child: CircularProgressIndicator()))
        else
          ..._body(m),
        const SizedBox(height: 60),
      ]),
    );
  }

  List<Widget> _body(MediaInsights m) {
    final maxDaily = m.daily.isEmpty ? 1 : m.daily.reduce((a, b) => a > b ? a : b);
    final inter = m.interactions == 0 ? 1 : m.interactions;
    final placeTotal = m.topPlaces.fold<int>(0, (a, b) => a + b.views);
    return [
      AppCard(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Accounts reached', style: TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_k(m.reach), key: const ValueKey('reach'), style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('${m.reachDelta >= 0 ? '+' : ''}${m.reachDelta}% vs the period before', style: TextStyle(color: m.reachDelta >= 0 ? C.green : const Color(0xFFE5484D), fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 70,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < m.daily.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: 64 * m.daily[i] / maxDaily + 3,
                      decoration: BoxDecoration(color: C.primary.withValues(alpha: i == m.daily.length - 1 ? 1 : 0.4), borderRadius: BorderRadius.circular(3)),
                    ).animate(delay: (12 * i).ms).scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, duration: 500.ms, curve: Curves.easeOutCubic),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 14),
          Text('${m.pctFollowers}% from people who follow you, ${100 - m.pctFollowers}% from people who do not', style: TextStyle(color: C.muted, fontSize: 12.5, height: 1.4)),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatCard(icon: Icons.visibility_rounded, label: 'Views', value: _k(m.impressions))),
        const SizedBox(width: 12),
        Expanded(child: StatCard(icon: Icons.person_search_rounded, label: 'Profile visits', value: _k(m.profileVisits))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatCard(icon: Icons.ads_click_rounded, label: 'Link taps', value: _k(m.linkTaps))),
        const SizedBox(width: 12),
        Expanded(child: StatCard(icon: Icons.favorite_rounded, label: 'Interactions', value: _k(m.interactions))),
      ]),
      const SectionHeader('Interactions'),
      AppCard(
        child: Column(children: [
          for (final r in [
            ('Likes', m.likes, Icons.favorite_rounded, const Color(0xFFE5484D)),
            ('Comments', m.comments, Icons.chat_bubble_rounded, C.blue),
            ('Saves', m.saves, Icons.bookmark_rounded, C.amber),
            ('Shares', m.shares, Icons.send_rounded, C.green),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                Icon(r.$3, size: 20, color: r.$4),
                const SizedBox(width: 12),
                Expanded(child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(
                  width: 90,
                  child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: r.$2 / inter, minHeight: 7, backgroundColor: C.surface2, color: r.$4)),
                ),
                const SizedBox(width: 12),
                SizedBox(width: 44, child: Text('${r.$2}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
            ),
        ]),
      ),
      const SectionHeader('Followers'),
      AppCard(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(child: _num('${m.followers}', 'Followers')),
          Expanded(child: _num('+${m.followersGained}', 'Gained', color: C.green)),
          Expanded(child: _num('-${m.followersLost}', 'Left', color: const Color(0xFFE5484D))),
        ]),
      ),
      const SectionHeader('Where people found you'),
      AppCard(
        child: Column(children: [
          for (final p in m.topPlaces)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(children: [
                Expanded(child: Text(p.platform, style: const TextStyle(fontWeight: FontWeight.w600))),
                Text('${placeTotal == 0 ? 0 : (p.views * 100 / placeTotal).round()}%', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
      ),
      const SectionHeader('Your best posts'),
      for (var i = 0; i < m.topPosts.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AppCard(
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(colors: [HSLColor.fromAHSL(1, m.topPosts[i].hue.toDouble(), 0.7, 0.55).toColor(), HSLColor.fromAHSL(1, (m.topPosts[i].hue + 40) % 360.0, 0.7, 0.35).toColor()]),
                ),
                child: Icon(m.topPosts[i].kind == 'reel' ? Icons.play_arrow_rounded : Icons.image_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${i + 1}. ${m.topPosts[i].title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Muted('${_k(m.topPosts[i].reach)} reached · ${m.topPosts[i].likes} likes · ${m.topPosts[i].comments} comments', size: 12.5),
                ]),
              ),
            ]),
          ),
        ),
    ];
  }

  Widget _num(String v, String label, {Color? color}) => Column(children: [
        Text(v, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: C.muted, fontSize: 12.5)),
      ]);
}
