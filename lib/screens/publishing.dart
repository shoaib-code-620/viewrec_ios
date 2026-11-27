import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import '../async_view.dart';
import '../data.dart';
import '../models.dart';
import '../repo.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';

class PublishingScreen extends StatelessWidget {
  const PublishingScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<PostsData>(
        load: repo.posts,
        builder: (context, data, refresh) => _PublishingBody(data: data, refresh: refresh),
      );
}

class _PublishingBody extends StatefulWidget {
  final PostsData data;
  final Future<void> Function() refresh;
  const _PublishingBody({required this.data, required this.refresh});
  @override
  State<_PublishingBody> createState() => _PublishingBodyState();
}

class _PublishingBodyState extends State<_PublishingBody> {
  int tab = 0;

  IconData _icon(String p) => platforms.firstWhere((x) => x.name.startsWith(p), orElse: () => platforms.first).icon;
  Color _col(String s) => switch (s) { 'scheduled' => C.blue, 'published' => C.green, _ => C.rec };

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final shown = d.posts.where((p) => tab == 0 || p.status == ['', 'scheduled', 'published', 'failed'][tab]).toList();
    final scheduled = d.posts.where((p) => p.status == 'scheduled').length;
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: AppPage(children: [
        const Muted('Post approved videos to your accounts. You choose each one - nothing goes out on its own.'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatCard(icon: Icons.schedule_rounded, label: 'Scheduled', value: '$scheduled')),
          const SizedBox(width: 12),
          Expanded(child: StatCard(icon: Icons.check_circle_outline_rounded, label: 'This month', value: '${d.usedThisMonth}', delta: 'of ${d.monthlyLimit} posts')),
        ]),
        const SizedBox(height: 14),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Monthly posts', style: TextStyle(fontWeight: FontWeight.w700)),
              Text('${d.usedThisMonth} / ${d.monthlyLimit}', style: TextStyle(color: C.primary, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LiquidProgress(
                value: d.monthlyLimit == 0 ? 0 : d.usedThisMonth / d.monthlyLimit,
                minHeight: 8,
                backgroundColor: C.surface2,
                color: C.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Muted('Facebook and Instagram have no monthly limit on Pro.', size: 12.5),
          ]),
        ),
        const SizedBox(height: 14),
        AppButton('Plan a month of posts', icon: Icons.calendar_month_rounded, onTap: () => _plan(context)),
        const SizedBox(height: 16),
        Pills(const ['All', 'Scheduled', 'Published', 'Failed'], tab, (i) => setState(() => tab = i)),
        const SizedBox(height: 12),
        if (shown.isEmpty) EmptyState(Icons.rocket_launch_rounded, 'No posts here', 'Create content and schedule it to see it here.', action: 'Create a post', onAction: () => context.findAncestorStateOfType<ShellState>()?.goTo(2)),
        for (final p in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Row(children: [
                CircleAvatar(radius: 20, backgroundColor: C.surface2, child: Icon(_icon(p.platform), size: 19)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    const SizedBox(height: 2),
                    Muted('${p.platform} · ${p.when}', size: 12.5),
                    if (p.status == 'published')
                      Padding(padding: const EdgeInsets.only(top: 4), child: Text('${p.reactions} reactions', style: TextStyle(fontSize: 12, color: C.green))),
                  ]),
                ),
                if (p.status == 'failed')
                  TextButton(onPressed: () => showMsg(context, 'Retrying…'), child: const Text('Retry'))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: _col(p.status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
                    child: Text(p.status[0].toUpperCase() + p.status.substring(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _col(p.status))),
                  ),
              ]),
            ),
          ),
        const SizedBox(height: 80),
      ]),
    );
  }

  void _plan(BuildContext context) {
    showSheet(
      context,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Plan this month'),
        const SizedBox(height: 4),
        const Muted('We spread your best testimonials across the month at the best times.', size: 13),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S']) Center(child: Text(d, style: TextStyle(color: C.muted, fontSize: 12))),
            for (var i = 1; i <= 28; i++)
              Container(
                decoration: BoxDecoration(
                  color: (i % 3 == 0) ? C.primarySoft : C.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: i % 3 == 0 ? Border.all(color: C.primary) : null,
                ),
                child: Center(child: Text('$i', style: TextStyle(fontSize: 12, color: i % 3 == 0 ? C.primary : C.muted, fontWeight: FontWeight.w600))),
              ),
          ],
        ),
        const SizedBox(height: 14),
        AppButton('Schedule 9 posts', icon: Icons.check_rounded, onTap: () {
          Navigator.pop(context);
          showMsg(context, '9 posts scheduled');
        }),
      ]),
    );
  }
}
