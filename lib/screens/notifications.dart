import 'package:flutter/material.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  (IconData, Color) _look(String kind) => switch (kind) {
        'video' => (Icons.videocam_rounded, C.green),
        'suggestion' => (Icons.people_rounded, C.amber),
        'views' => (Icons.visibility_rounded, C.primary),
        'invite' => (Icons.send_rounded, C.blue),
        'lead' => (Icons.handshake_rounded, C.amber),
        _ => (Icons.notifications_none_rounded, C.primary),
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader('Notifications')),
            Expanded(
              child: AsyncView<List<AppNotification>>(
                load: repo.notifications,
                skeletonCards: 4,
                builder: (context, items, refresh) => RefreshIndicator(
                  onRefresh: refresh,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                    if (items.isEmpty) const EmptyState(Icons.notifications_none_rounded, 'All caught up', 'New activity will show up here.'),
                    for (final n in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AppCard(
                          child: Row(children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: _look(n.kind).$2.withValues(alpha: 0.15),
                              child: Icon(_look(n.kind).$1, size: 18, color: _look(n.kind).$2),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Muted(n.subtitle, size: 13),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      );
}
