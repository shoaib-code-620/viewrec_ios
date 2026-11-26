import 'package:flutter/material.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';
import 'invitations.dart';
import 'lead_thread.dart';
import 'settings_extra.dart';
import 'video_detail.dart';

/// What happened: a video came in, customers were suggested, a request arrived. Tap one to open what it is about.
class NotificationsScreen extends StatelessWidget {
  /// Used to go to a tab (Business Phonebook, Leads) from a notification.
  final ShellState? shell;
  const NotificationsScreen({super.key, this.shell});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          bottom: false,
          child: AsyncView<List<AppNotification>>(
            load: repo.notifications,
            skeletonCards: 4,
            builder: (context, items, refresh) => _Body(items: items, refresh: refresh, shell: shell),
          ),
        ),
      );
}

class _Body extends StatefulWidget {
  final List<AppNotification> items;
  final Future<void> Function() refresh;
  final ShellState? shell;
  const _Body({required this.items, required this.refresh, required this.shell});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final List<AppNotification> items = List.of(widget.items);

  (IconData, Color) _look(String kind) => switch (kind) {
        'video' => (Icons.videocam_rounded, C.green),
        'suggestion' => (Icons.people_rounded, C.amber),
        'views' => (Icons.visibility_rounded, C.primary),
        'invite' => (Icons.send_rounded, C.blue),
        'lead' => (Icons.handshake_rounded, C.amber),
        _ => (Icons.notifications_none_rounded, C.primary),
      };

  int get unread => items.where((n) => !n.read).length;

  Future<void> _markAll() async {
    setState(() {
      for (final n in items) {
        n.read = true;
      }
    });
    try {
      await repo.markAllNotificationsRead();
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't save that. Try again.");
    }
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      setState(() => n.read = true);
      repo.markNotificationRead(n.id).catchError((_) {});
    }
    final nav = Navigator.of(context);
    try {
      switch (n.kind) {
        case 'video' || 'views':
          final videos = await repo.videos();
          final v = videos.where((x) => x.id == n.refId).firstOrNull;
          if (v == null) return _gone();
          nav.push(MaterialPageRoute(builder: (_) => VideoDetailScreen(video: v)));
        case 'lead':
          final leads = await repo.leads();
          final l = leads.where((x) => x.id == n.refId).firstOrNull;
          if (l == null) {
            nav.pop();
            widget.shell?.goTo(4);
          } else {
            nav.push(MaterialPageRoute(builder: (_) => LeadThreadScreen(lead: l)));
          }
        case 'suggestion':
          nav.pop();
          widget.shell?.goTo(3);
        case 'invite':
          nav.push(MaterialPageRoute(builder: (_) => const SubPageShell(title: 'Invitations sent', child: InvitationsScreen())));
        default:
          break;
      }
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't open that. Try again.");
    }
  }

  void _gone() {
    if (mounted) showMsg(context, 'That is no longer available.');
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: BackHeader(
            'Notifications',
            trailing: unread == 0
                ? null
                : GestureDetector(
                    onTap: _markAll,
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8), child: Text('Mark all as read', style: TextStyle(color: C.primary, fontWeight: FontWeight.w700, fontSize: 13.5))),
                  ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.refresh,
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
              if (items.isEmpty) const EmptyState(Icons.notifications_none_rounded, 'All caught up', 'New activity will show up here.'),
              for (final n in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AppCard(
                    onTap: () => _open(n),
                    child: Row(children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _look(n.kind).$2.withValues(alpha: 0.15),
                        child: Icon(_look(n.kind).$1, size: 18, color: _look(n.kind).$2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(n.title, style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800)),
                          const SizedBox(height: 2),
                          Muted(n.subtitle, size: 13),
                        ]),
                      ),
                      const SizedBox(width: 8),
                      if (!n.read) Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: C.primary)) else Icon(Icons.chevron_right_rounded, color: C.muted),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
      ]);
}
