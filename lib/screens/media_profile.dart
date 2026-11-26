import 'package:flutter/material.dart';
import '../async_view.dart';
import '../liquid_widgets.dart';
import '../media_data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'media_viewers.dart';
import 'media_widgets.dart';

/// The business that is "you" in the sample data. You cannot report or block yourself.
const _myBusinessId = 'b0';

void openProfile(BuildContext context, String businessId) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PublicProfileScreen(businessId: businessId)));

// ---------------------------------------------------------------- report and block

/// Asks why, then sends a report. [targetType] is post, comment, profile or message.
Future<void> showReportSheet(BuildContext context, {required String targetType, required String targetId, required String subject}) {
  String reason = 'spam';
  final note = TextEditingController();
  var sending = false;
  return showSheet(
    context,
    StatefulBuilder(
      builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        H2('Report $subject'),
        const SizedBox(height: 4),
        const Muted('Tell us what is wrong. We review every report and the business is not told who sent it.', size: 13),
        const SizedBox(height: 10),
        for (final r in reportReasons)
          Pressable(
            scale: 0.99,
            onTap: () => set(() => reason = r.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(children: [
                Expanded(child: Text(r.$2, style: TextStyle(fontSize: 15, fontWeight: reason == r.$1 ? FontWeight.w800 : FontWeight.w600))),
                AnimatedContainer(
                  duration: kFast,
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: reason == r.$1 ? C.primary : C.border, width: reason == r.$1 ? 7 : 2)),
                ),
              ]),
            ),
          ),
        const SizedBox(height: 4),
        Field('Anything to add? (optional)', controller: note, lines: 2),
        AppButton(sending ? 'Sending…' : 'Send report', loading: sending, style: BtnStyle.danger, icon: Icons.flag_rounded, onTap: sending
            ? null
            : () async {
                set(() => sending = true);
                try {
                  await repo.report(targetType: targetType, targetId: targetId, reason: reason, note: note.text.trim());
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (context.mounted) showSuccess(context, 'Thanks. We will review this.');
                } catch (_) {
                  set(() => sending = false);
                  if (ctx.mounted) showMsg(ctx, "Couldn't send the report. Try again.");
                }
              }),
      ]),
    ),
  );
}

/// Asks first, then blocks. Blocked businesses vanish from the feed, stories and comments. Returns true if blocked.
Future<bool> blockBusiness(BuildContext context, {required String businessId, required String name, List<Reel>? all, VoidCallback? refresh}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: C.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text('Block $name?', style: const TextStyle(fontWeight: FontWeight.w800)),
      content: Text('You will not see their posts, stories or comments, and they will not see yours. You can unblock them any time in Settings.', style: TextStyle(color: C.muted, height: 1.4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Block', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    await repo.setBlock(businessId, true);
  } catch (_) {
    if (context.mounted) showMsg(context, "Couldn't block $name. Try again.");
    return false;
  }
  all?.removeWhere((r) => r.businessId == businessId);
  refresh?.call();
  if (context.mounted) showMsg(context, '$name blocked');
  return true;
}

/// The "..." menu on a post or reel.
void showPostMenu(BuildContext context, Reel r, {required List<Reel> all, required VoidCallback onChanged}) {
  final mine = r.businessId == _myBusinessId;
  showSheet(
    context,
    Column(mainAxisSize: MainAxisSize.min, children: [
      Tile(icon: Icons.storefront_rounded, title: mine ? 'View your page' : 'View ${r.business}', onTap: () {
        Navigator.pop(context);
        openProfile(context, r.businessId);
      }),
      if (!mine) ...[
        Tile(icon: Icons.flag_rounded, iconColor: C.amber, title: 'Report this post', subtitle: 'Spam, abuse, misleading or inappropriate', onTap: () {
          Navigator.pop(context);
          showReportSheet(context, targetType: 'post', targetId: r.id, subject: 'this post');
        }),
        Tile(icon: Icons.block_rounded, iconColor: C.rec, title: 'Block ${r.business}', subtitle: 'Hide everything from this business', divider: false, onTap: () {
          Navigator.pop(context);
          blockBusiness(context, businessId: r.businessId, name: r.business, all: all, refresh: onChanged);
        }),
      ],
    ]),
  );
}

// ---------------------------------------------------------------- public profile

class PublicProfileScreen extends StatelessWidget {
  final String businessId;
  const PublicProfileScreen({super.key, required this.businessId});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            bottom: false,
            child: AsyncView<PublicProfile>(
              load: () => repo.publicProfile(businessId),
              skeletonCards: 3,
              builder: (context, p, refresh) => _ProfileBody(profile: p, refresh: refresh),
            ),
          ),
        ]),
      );
}

class _ProfileBody extends StatefulWidget {
  final PublicProfile profile;
  final Future<void> Function() refresh;
  const _ProfileBody({required this.profile, required this.refresh});
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late final p = widget.profile;
  bool busy = false;

  Future<void> _follow() async {
    if (busy) return;
    final next = !p.following;
    setState(() {
      busy = true;
      p.following = next;
      p.followers += next ? 1 : -1;
    });
    try {
      await repo.setFollow(p.businessId, next);
    } catch (_) {
      if (mounted) {
        setState(() {
          p.following = !next;
          p.followers += next ? -1 : 1;
        });
        showMsg(context, "Couldn't update that. Try again.");
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _unblock() async {
    try {
      await repo.setBlock(p.businessId, false);
      if (mounted) setState(() => p.blocked = false);
      if (mounted) showMsg(context, '${p.name} unblocked');
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't unblock. Try again.");
    }
  }

  void _menu() {
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, children: [
        Tile(icon: Icons.flag_rounded, iconColor: C.amber, title: 'Report ${p.name}', subtitle: 'Tell us what is wrong with this profile', onTap: () {
          Navigator.pop(context);
          showReportSheet(context, targetType: 'profile', targetId: p.businessId, subject: p.name);
        }),
        Tile(
          icon: p.blocked ? Icons.lock_open_rounded : Icons.block_rounded,
          iconColor: p.blocked ? C.green : C.rec,
          title: p.blocked ? 'Unblock ${p.name}' : 'Block ${p.name}',
          divider: false,
          onTap: () async {
            Navigator.pop(context);
            if (p.blocked) {
              _unblock();
            } else if (await blockBusiness(context, businessId: p.businessId, name: p.name) && mounted) {
              setState(() => p.blocked = true);
            }
          },
        ),
      ]),
    );
  }

  void _lists(int tab) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FollowListScreen(businessId: p.businessId, name: p.name, initialTab: tab)));

  Widget _stat(String value, String label, {VoidCallback? onTap}) => Expanded(
        child: Pressable(
          onTap: onTap,
          child: Column(children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
            const SizedBox(height: 1),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      );

  Widget _hero() => ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradBlueDeep, stops: [0, 0.55, 1]),
            boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 12))],
          ),
          child: Stack(children: [
            const Positioned.fill(child: PlayPattern()),
            Column(children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white24),
                child: Avatar(p.name, size: 84),
              ),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Flexible(child: Text(p.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
                if (p.verified) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.verified_rounded, size: 20, color: Color(0xFFFFD65A))),
              ]),
              const SizedBox(height: 2),
              Text('${p.handle} · ${p.category}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
              if (p.about.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.about, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4)),
              ],
              const SizedBox(height: 18),
              Row(children: [
                _stat('${p.posts.length}', 'Posts'),
                _stat('${p.followers}', 'Followers', onTap: () => _lists(0)),
                _stat('${p.followingCount}', 'Following', onTap: () => _lists(1)),
                _stat(p.rating.toStringAsFixed(1), 'Rating'),
              ]),
            ]),
          ]),
        ),
      );

  Widget _tile(Reel r, int i) => Pressable(
        scale: 0.97,
        onTap: () => Navigator.of(context).push(PageRouteBuilder(
          opaque: false,
          pageBuilder: (_, __, ___) => ReelsViewer(reels: p.posts, startIndex: i, onChanged: () {
            if (mounted) setState(() {});
          }),
        )),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [r.hue, Color.lerp(r.hue, Colors.black, 0.55)!]),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(alignment: Alignment.topRight, child: Icon(r.isVideo || r.kind == 'testimonial' ? Icons.play_circle_fill_rounded : Icons.image_rounded, size: 18, color: Colors.white70)),
            const Spacer(),
            Row(children: [for (var k = 0; k < r.rating.clamp(0, 5); k++) const Icon(Icons.star_rounded, size: 11, color: Color(0xFFFFC21A))]),
            const SizedBox(height: 2),
            Text(r.reviewer, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final menuButton = p.mine ? null : IconButton(onPressed: _menu, icon: Icon(Icons.more_horiz_rounded, color: C.text));
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          BackHeader(p.handle, trailing: menuButton),
          _hero(),
          const SizedBox(height: 16),
          if (p.blocked)
            AppCard(
              child: Column(children: [
                Icon(Icons.block_rounded, size: 36, color: C.rec),
                const SizedBox(height: 8),
                Text('You blocked ${p.name}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 4),
                const Muted('Their posts, stories and comments are hidden from you.', size: 13, align: TextAlign.center),
                const SizedBox(height: 14),
                AppButton('Unblock', style: BtnStyle.ghost, onTap: _unblock),
              ]),
            )
          else ...[
            if (!p.mine)
              AppButton(p.following ? 'Following' : 'Follow', icon: p.following ? Icons.check_rounded : Icons.person_add_alt_1_rounded, style: p.following ? BtnStyle.ghost : BtnStyle.primary, loading: busy, onTap: _follow),
            const SectionHeader('Posts'),
            if (p.posts.isEmpty)
              const EmptyState(Icons.video_library_outlined, 'No posts yet', 'Reviews and updates from this business show here.')
            else
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.72,
                children: [for (var i = 0; i < p.posts.length; i++) _tile(p.posts[i], i)],
              ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- followers and following

class FollowListScreen extends StatefulWidget {
  final String businessId, name;
  final int initialTab; // 0 followers, 1 following
  const FollowListScreen({super.key, required this.businessId, required this.name, this.initialTab = 0});
  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  late int tab = widget.initialTab;
  String q = '';

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: BackHeader(widget.name)),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: Pills(const ['Followers', 'Following'], tab, (i) => setState(() => tab = i)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
                child: TextField(
                  onChanged: (v) => setState(() => q = v),
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: C.muted),
                    prefixIcon: Icon(Icons.search_rounded, size: 20, color: C.muted),
                    filled: true,
                    fillColor: C.dark ? C.surface : Colors.white.withValues(alpha: 0.9),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.dark ? C.border : Colors.white)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.primary)),
                  ),
                ),
              ),
              Expanded(
                child: AsyncView<List<BusinessRef>>(
                  key: ValueKey(tab),
                  load: () => tab == 0 ? repo.followersOf(widget.businessId) : repo.followingOf(widget.businessId),
                  builder: (context, list, refresh) {
                    final shown = list.where((b) => b.name.toLowerCase().contains(q.toLowerCase()) || b.handle.toLowerCase().contains(q.toLowerCase())).toList();
                    return RefreshIndicator(
                      onRefresh: refresh,
                      child: ListView(
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 40),
                        children: [
                          if (shown.isEmpty)
                            EmptyState(Icons.people_outline_rounded, tab == 0 ? 'No followers yet' : 'Not following anyone yet', 'Businesses will show here.')
                          else
                            AppCard(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                              child: Column(children: [for (var i = 0; i < shown.length; i++) _BusinessRow(ref: shown[i], last: i == shown.length - 1)]),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ]),
          ),
        ]),
      );
}

class _BusinessRow extends StatefulWidget {
  final BusinessRef ref;
  final bool last;
  /// Shows an Unblock button instead of Follow.
  final VoidCallback? onUnblock;
  const _BusinessRow({required this.ref, required this.last, this.onUnblock});
  @override
  State<_BusinessRow> createState() => _BusinessRowState();
}

class _BusinessRowState extends State<_BusinessRow> {
  BusinessRef get b => widget.ref;

  Future<void> _toggle() async {
    final next = !b.following;
    setState(() => b.following = next);
    try {
      await repo.setFollow(b.businessId, next);
    } catch (_) {
      if (mounted) {
        setState(() => b.following = !next);
        showMsg(context, "Couldn't update that. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.99,
        onTap: () => openProfile(context, b.businessId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(border: widget.last ? null : Border(bottom: BorderSide(color: C.border.withValues(alpha: 0.7)))),
          child: Row(children: [
            Avatar(b.name, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                  if (b.verified) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.verified_rounded, size: 14, color: C.blue)),
                ]),
                Text(b.handle.isEmpty ? b.category : '${b.handle} · ${b.category}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: C.muted)),
              ]),
            ),
            const SizedBox(width: 8),
            if (widget.onUnblock != null)
              AppButton('Unblock', small: true, style: BtnStyle.ghost, onTap: widget.onUnblock)
            else
              FollowButton(following: b.following, onTap: _toggle),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- blocked accounts (Settings)

class BlockedAccountsScreen extends StatefulWidget {
  const BlockedAccountsScreen({super.key});
  @override
  State<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends State<BlockedAccountsScreen> {
  int version = 0;

  Future<void> _unblock(BusinessRef b) async {
    try {
      await repo.setBlock(b.businessId, false);
      if (!mounted) return;
      setState(() => version++);
      showMsg(context, '${b.name} unblocked');
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't unblock. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            bottom: false,
            child: Column(children: [
              const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 0), child: BackHeader('Blocked accounts')),
              Expanded(
                child: AsyncView<List<BusinessRef>>(
                  key: ValueKey(version),
                  load: repo.blockedAccounts,
                  builder: (context, list, refresh) => ListView(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
                    children: [
                      const Muted('You do not see posts, stories or comments from these businesses, and they do not see yours.', size: 13),
                      const SizedBox(height: 14),
                      if (list.isEmpty)
                        const EmptyState(Icons.block_rounded, 'No blocked accounts', 'Businesses you block show here, so you can undo it.')
                      else
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          child: Column(children: [for (var i = 0; i < list.length; i++) _BusinessRow(ref: list[i], last: i == list.length - 1, onUnblock: () => _unblock(list[i]))]),
                        ),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ]),
      );
}
