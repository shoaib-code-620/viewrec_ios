import 'package:flutter/material.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Review access requests: people from your public page who ask to leave a review. Approve to send them a recording link.
class ReviewRequestsScreen extends StatelessWidget {
  const ReviewRequestsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<ReviewAccessRequest>>(
        load: webRepo.reviewRequests,
        builder: (context, list, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _Body(initial: list)),
      );
}

class _Body extends StatefulWidget {
  final List<ReviewAccessRequest> initial;
  const _Body({required this.initial});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final list = List.of(widget.initial);
  int tab = 0; // Waiting, Decided

  Future<void> _decide(ReviewAccessRequest r, bool approve) async {
    final prev = r.status;
    setState(() => r.status = approve ? 'approved' : 'declined');
    try {
      await webRepo.decideReviewRequest(r.id, approve: approve);
      if (!mounted) return;
      if (approve) {
        showSuccess(context, 'Link sent to ${r.name.split(' ').first}');
      } else {
        showMsg(context, '${r.name} declined');
      }
    } catch (_) {
      if (mounted) {
        setState(() => r.status = prev);
        showMsg(context, "Couldn't update that. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shown = list.where((r) => tab == 0 ? r.status == 'pending' : r.status != 'pending').toList();
    final waiting = list.where((r) => r.status == 'pending').length;
    return AppPage(reveal: false, children: [
      const Muted('People who found you in the directory and asked to leave a review. Approve to send them a link to record.').reveal(context, 0),
      const SizedBox(height: 14),
      Pills(['Waiting${waiting > 0 ? ' ($waiting)' : ''}', 'Decided'], tab, (i) => setState(() => tab = i)).reveal(context, 1),
      const SizedBox(height: 14),
      if (shown.isEmpty) EmptyState(Icons.how_to_reg_rounded, tab == 0 ? 'No requests waiting' : 'Nothing decided yet', 'New requests from your public page show up here.'),
      for (var i = 0; i < shown.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Avatar(shown[i].name, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(shown[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Muted('${shown[i].email} · ${shown[i].when}', size: 12.5, maxLines: 1),
                  ]),
                ),
                if (shown[i].status != 'pending') StatusBadge(shown[i].status == 'approved' ? 'approved' : 'skipped'),
              ]),
              const SizedBox(height: 10),
              Text(shown[i].message, style: TextStyle(color: C.muted, fontSize: 14, height: 1.4)),
              if (shown[i].status == 'pending') ...[
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: AppButton('Approve', icon: Icons.check_rounded, small: true, onTap: () => _decide(shown[i], true))),
                  const SizedBox(width: 8),
                  Expanded(child: AppButton('Decline', small: true, style: BtnStyle.ghost, onTap: () => _decide(shown[i], false))),
                ]),
              ],
            ]),
          ),
        ).reveal(context, 2 + i, 0.08),
      const SizedBox(height: 80),
    ]);
  }
}
