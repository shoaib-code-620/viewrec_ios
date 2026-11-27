import 'package:flutter/material.dart';
import '../async_view.dart';
import '../liquid_widgets.dart';
import '../media_data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'media_explore.dart';
import 'media_insights.dart';
import 'media_viewers.dart';
import 'settings.dart';
import 'media_widgets.dart';

/// The business that is "you" in the sample data. You cannot report or block yourself.
const kMyBusinessId = 'b0';

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
  final mine = r.businessId == kMyBusinessId;
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
  /// Inside the Media tab (your own profile): no back arrow, because the bar at the bottom is the way around.
  final bool embedded;
  const PublicProfileScreen({super.key, required this.businessId, this.embedded = false});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(children: [
          const Positioned.fill(child: LiquidBackdrop()),
          SafeArea(
            bottom: false,
            child: AsyncView<PublicProfile>(
              load: () => repo.publicProfile(businessId),
              skeletonCards: 3,
              builder: (context, p, refresh) => _ProfileBody(profile: p, refresh: refresh, embedded: embedded),
            ),
          ),
        ]),
      );
}

class _ProfileBody extends StatefulWidget {
  final PublicProfile profile;
  final Future<void> Function() refresh;
  final bool embedded;
  const _ProfileBody({required this.profile, required this.refresh, this.embedded = false});
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  late final p = widget.profile;
  bool busy = false;
  /// 0 Posts, 1 Reels, 2 Saved (only on your own profile), 3 Tagged.
  int gridTab = 0;
  List<Reel> savedPosts = [];
  /// A few of the people who follow this business, shown so visitors can see who trusts it.
  List<BusinessRef> followers = [];

  @override
  void initState() {
    super.initState();
    repo.followersOf(p.businessId).then((f) {
      if (mounted) setState(() => followers = f);
    }).catchError((_) {});
    if (p.mine) {
      repo.reels().then((all) {
        if (mounted) setState(() => savedPosts = all.where((r) => r.saved).toList());
      }).catchError((_) {});
    }
  }

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

  Widget _gridTabs() {
    final tabs = <(int, IconData, String)>[
      (0, Icons.grid_on_rounded, 'Posts'),
      (1, Icons.movie_creation_outlined, 'Reels'),
      if (p.mine) (2, Icons.bookmark_border_rounded, 'Saved'),
      (3, Icons.person_pin_outlined, 'Tagged'),
    ];
    return Row(children: [
      for (final t in tabs)
        Expanded(
          child: Semantics(
            label: t.$3,
            button: true,
            selected: gridTab == t.$1,
            child: GestureDetector(
              key: ValueKey('gridtab_${t.$3}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => gridTab = t.$1),
              child: Column(children: [
                Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Icon(t.$2, color: gridTab == t.$1 ? C.text : C.muted)),
                AnimatedContainer(duration: kFast, height: 2, color: gridTab == t.$1 ? C.text : Colors.transparent),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _grid() {
    final list = switch (gridTab) {
      1 => p.posts.where((r) => r.isVideo || r.kind != 'post').toList(),
      2 => savedPosts,
      3 => <Reel>[],
      _ => p.posts,
    };
    if (list.isEmpty) {
      return switch (gridTab) {
        2 => const EmptyState(Icons.bookmark_border_rounded, 'Nothing saved yet', 'Tap the bookmark on a post to keep it here. Only you can see this.'),
        3 => const EmptyState(Icons.person_pin_outlined, 'No tagged posts', 'Posts where this business is mentioned show here.'),
        1 => const EmptyState(Icons.movie_creation_outlined, 'No reels yet', 'Short videos show here.'),
        _ => const EmptyState(Icons.video_library_outlined, 'No posts yet', 'Reviews and updates from this business show here.'),
      };
    }
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.78,
      children: [
        for (var i = 0; i < list.length; i++)
          ReelTile(
            reel: list[i],
            onTap: () => gridTab == 2 ? _openList(list, i) : (gridTab == 0 ? _openPosts(i) : _openList(list, i)),
          ),
      ],
    );
  }

  void _openList(List<Reel> list, int i) => Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ReelsViewer(reels: list, startIndex: i, onChanged: () {
          if (mounted) setState(() {});
        }),
      ));

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
              Text('${p.handle} · ${p.category}${p.rating > 0 ? ' · ${p.rating.toStringAsFixed(1)} stars' : ''}', textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
              if (p.about.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(p.about, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.4)),
              ],
              const SizedBox(height: 18),
              Row(children: [
                _stat('${p.posts.length}', 'Posts'),
                _stat(ReelTile.compact(p.likes), 'Likes'),
                _stat('${p.followers}', 'Followers', onTap: () => _lists(0)),
                _stat('${p.followingCount}', 'Following', onTap: () => _lists(1)),
              ]),
            ]),
          ]),
        ),
      );

  /// "Followed by Brightside Dental, Northgate Autos and 115 others", with their avatars.
  Widget _followedBy() {
    if (followers.isEmpty) return const SizedBox.shrink();
    final shown = followers.take(3).toList();
    final others = p.followers - shown.length;
    final names = shown.map((f) => f.name).take(2).join(', ');
    return Pressable(
      onTap: () => _lists(0),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          SizedBox(
            width: 28.0 + (shown.length - 1) * 20,
            height: 32,
            child: Stack(children: [
              for (var i = 0; i < shown.length; i++)
                Positioned(left: i * 20.0, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(shape: BoxShape.circle, color: C.bg), child: Avatar(shown[i].name, size: 28))),
            ]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Followed by $names${others > 0 ? ' and $others others' : ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: C.muted, fontWeight: FontWeight.w600, height: 1.3),
            ),
          ),
        ]),
      ),
    );
  }

  /// Saved stories on the profile, as round covers. Tap one to watch it.
  Widget _highlights() => SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: p.highlights.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (_, i) {
            final h = p.highlights[i];
            return Pressable(
              onTap: () => Navigator.of(context).push(PageRouteBuilder(
                opaque: false,
                pageBuilder: (_, __, ___) => StoryViewer(groups: [StoryGroup(id: h.id, business: p.name, category: h.title, items: h.items)]),
              )),
              child: SizedBox(
                width: 70,
                child: Column(children: [
                  Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.border, width: 2)),
                    child: Container(
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [h.hue, Color.lerp(h.hue, Colors.black, 0.4)!])),
                      child: const Icon(Icons.auto_awesome_motion_rounded, color: Colors.white70, size: 22),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ]),
              ),
            );
          },
        ),
      );

  void _openPosts(int i) => Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ReelsViewer(reels: p.posts, startIndex: i, onChanged: () {
          if (mounted) setState(() {});
        }),
      ));

  @override
  Widget build(BuildContext context) {
    final menuButton = p.mine ? null : IconButton(onPressed: _menu, icon: Icon(Icons.more_horiz_rounded, color: C.text));
    return RefreshIndicator(
      onRefresh: widget.refresh,
      child: ListView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
        children: [
          if (widget.embedded)
            Padding(padding: const EdgeInsets.fromLTRB(4, 4, 0, 14), child: Text(p.handle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6)))
          else
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
            _followedBy(),
            if (p.mine) ...[
              AppButton('Edit profile', icon: Icons.edit_rounded, style: BtnStyle.ghost, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BusinessProfileScreen()))),
              const SizedBox(height: 10),
              AppButton('Insights', icon: Icons.insights_rounded, style: BtnStyle.ghost, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MediaInsightsScreen()))),
            ]
            else
              AppButton(p.following ? 'Following' : 'Follow', icon: p.following ? Icons.check_rounded : Icons.person_add_alt_1_rounded, style: p.following ? BtnStyle.ghost : BtnStyle.primary, loading: busy, onTap: _follow),
            if (p.highlights.isNotEmpty) ...[
              const SectionHeader('Highlights'),
              _highlights(),
            ],
            const SizedBox(height: 14),
            _gridTabs(),
            const SizedBox(height: 12),
            _grid(),
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
