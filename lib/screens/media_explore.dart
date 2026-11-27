import 'package:flutter/material.dart';
import '../async_view.dart';
import '../media_data.dart';
import '../motion.dart';
import '../repo.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets.dart';
import 'media.dart';
import 'media_profile.dart';
import 'media_viewers.dart';

/// A post or reel as a square in a grid, with its likes shown, like Instagram's grid.
class ReelTile extends StatelessWidget {
  final Reel reel;
  final VoidCallback onTap;
  const ReelTile({super.key, required this.reel, required this.onTap});

  static String compact(int n) => n >= 1000 ? '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k' : '$n';

  @override
  Widget build(BuildContext context) => Pressable(
        scale: 0.97,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [reel.hue, Color.lerp(reel.hue, Colors.black, 0.55)!]),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Align(alignment: Alignment.topRight, child: Icon(reel.isVideo || reel.kind == 'testimonial' ? Icons.play_circle_fill_rounded : Icons.image_rounded, size: 18, color: Colors.white70)),
            const Spacer(),
            Row(children: [
              const Icon(Icons.favorite_rounded, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Text(compact(reel.likes), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
              const SizedBox(width: 10),
              const Icon(Icons.chat_bubble_rounded, size: 12, color: Colors.white70),
              const SizedBox(width: 4),
              Text(compact(reel.comments), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ]),
        ),
      );
}

/// Media > Explore: search for businesses and reviews, and a grid of what is new.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});
  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  String q = '';

  void _open(List<Reel> list, int i) => Navigator.of(context).push(PageRouteBuilder(
        opaque: false,
        pageBuilder: (_, __, ___) => ReelsViewer(reels: list, startIndex: i, onChanged: () {
          if (mounted) setState(() {});
        }),
      ));

  @override
  Widget build(BuildContext context) => AsyncView<List<Reel>>(
        load: repo.reels,
        skeletonCards: 3,
        builder: (context, all, refresh) {
          final words = q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
          bool hit(String t) => words.every(t.toLowerCase().contains);
          final posts = q.isEmpty ? all : all.where((r) => hit('${r.business} ${r.handle} ${r.category} ${r.caption} ${r.reviewer}')).toList();
          final seen = <String>{};
          final accounts = q.isEmpty ? <Reel>[] : all.where((r) => hit('${r.business} ${r.handle} ${r.category}') && seen.add(r.businessId)).take(5).toList();
          return RefreshIndicator(
            color: C.primary,
            onRefresh: refresh,
            child: AppPage(reveal: false, children: [
              TextField(
                onChanged: (v) => setState(() => q = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search businesses and reviews',
                  hintStyle: TextStyle(color: C.muted),
                  prefixIcon: Icon(Icons.search_rounded, color: C.muted),
                  filled: true,
                  fillColor: C.dark ? C.surface : Colors.white.withValues(alpha: 0.9),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.dark ? C.border : Colors.white)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: C.primary)),
                ),
              ),
              if (q.startsWith('#') && q.length > 1) ...[
                const SectionHeader('Tag'),
                AppCard(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => HashtagScreen(tag: q.substring(1)))),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: C.gradBlue)), alignment: Alignment.center, child: const Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20))),
                    const SizedBox(width: 14),
                    Expanded(child: Text(q, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ]),
                ),
              ],
              if (accounts.isNotEmpty) ...[
                const SectionHeader('Accounts'),
                AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(children: [
                    for (var i = 0; i < accounts.length; i++)
                      Tile(
                        icon: Icons.storefront_rounded,
                        leading: Avatar(accounts[i].business, size: 40),
                        title: accounts[i].business,
                        subtitle: '${accounts[i].handle} · ${accounts[i].category}',
                        divider: i < accounts.length - 1,
                        onTap: () => openProfile(context, accounts[i].businessId),
                      ),
                  ]),
                ),
              ],
              SectionHeader(q.isEmpty ? 'Explore' : 'Posts'),
              if (posts.isEmpty)
                const EmptyState(Icons.search_off_rounded, 'Nothing found', 'Try a business name or a word from a review.')
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.78,
                  children: [for (var i = 0; i < posts.length; i++) ReelTile(reel: posts[i], onTap: () => _open(posts, i))],
                ),
            ]),
          );
        },
      );
}

/// Everything posted with a #tag, as a grid.
class HashtagScreen extends StatelessWidget {
  final String tag;
  const HashtagScreen({super.key, required this.tag});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AsyncView<List<Reel>>(
          load: repo.reels,
          skeletonCards: 2,
          builder: (context, all, refresh) {
            final posts = all.where((r) => RegExp('#${RegExp.escape(tag)}\\b', caseSensitive: false).hasMatch(r.caption)).toList();
            return AppPage(children: [
              BackHeader('#$tag'),
              Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: C.gradBlue)),
                  alignment: Alignment.center,
                  child: const Text('#', style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('#$tag', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    Muted('${posts.length} ${posts.length == 1 ? 'post' : 'posts'}', size: 14),
                  ]),
                ),
              ]),
              const SizedBox(height: 18),
              if (posts.isEmpty)
                const EmptyState(Icons.tag_rounded, 'Nothing here yet', 'Posts that use this tag show up here.')
              else
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.78,
                  children: [
                    for (var i = 0; i < posts.length; i++)
                      ReelTile(
                        reel: posts[i],
                        onTap: () => Navigator.of(context).push(PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) => ReelsViewer(reels: posts, startIndex: i, onChanged: () {}))),
                      ),
                  ],
                ),
            ]);
          },
        ),
      );
}

/// The Media tab's body: the feed, Explore, or your own profile, depending on the Instagram-style bar.
class MediaHome extends StatelessWidget {
  final ShellState shell;
  const MediaHome({super.key, required this.shell});
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: kFast,
        child: KeyedSubtree(
          key: ValueKey(shell.mediaTab),
          child: switch (shell.mediaTab) {
            1 => const ExploreScreen(),
            3 => const PublicProfileScreen(businessId: kMyBusinessId, embedded: true),
            _ => const MediaScreen(),
          },
        ),
      );
}
