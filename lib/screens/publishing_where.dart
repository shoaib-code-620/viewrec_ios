import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../data.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'settings_extra.dart';
import 'verification.dart';

/// What each channel can do today. [auto] channels post for you once connected; the rest are posted by hand.
class _Channel {
  final String id, name, does, why;
  final bool auto;
  final IconData icon;
  const _Channel(this.id, this.name, this.icon, this.does, {this.auto = false, this.why = ''});
}

const _channels = [
  _Channel('fb', 'Facebook Page', Icons.facebook_rounded, 'Posts the testimonial to your Page as a video with its caption.', auto: true),
  _Channel('ig', 'Instagram', Icons.photo_camera_rounded, 'Posts the testimonial as a Reel.', auto: true),
  _Channel('threads', 'Threads', Icons.alternate_email_rounded, 'Posts the caption with a link to the testimonial.', auto: true),
  _Channel('li', 'LinkedIn Page', Icons.work_outline_rounded, 'Posts the testimonial to your company Page.', auto: true),
  _Channel('yt', 'YouTube', Icons.smart_display_rounded, 'The testimonial as a Short, with its caption and a link.', why: 'A Google API project and YouTube\'s own audit, which it grants per app rather than per account.'),
  _Channel('tt', 'TikTok', Icons.music_note_rounded, 'The testimonial as a video post.', why: 'TikTok\'s Content Posting API, which is reviewed per app and not open to most of them.'),
  _Channel('pin', 'Pinterest', Icons.push_pin_rounded, 'A Pin of the testimonial, linking back to your page.', why: 'A Pinterest app with write access. A video Pin also needs a still cover image, which is chosen when it is posted.'),
  _Channel('x', 'X (Twitter)', Icons.close_rounded, 'The caption with a link to the testimonial, or the video itself.', why: 'An X developer account on a paid tier. Posting on somebody else\'s behalf is not on the free one, which is the part that decides it.'),
  _Channel('google', 'Google Business Profile', Icons.storefront_rounded, 'The testimonial as a post on your Business Profile.', why: 'Nothing we can apply for. Google does not accept this kind of post from a third party, so it stays a person\'s job.'),
];

typedef _Data = (List<Video>, Verification, Map<String, String>, List<PublishDestination>);

/// Publishing > Where they go: is everything ready, which channels post for you, your own website, and what waits for you.
class PublishingWhereScreen extends StatelessWidget {
  const PublishingWhereScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<_Data>(
        load: () async => (await repo.videos(), await webRepo.verification(), await repo.accounts(), await webRepo.destinations()),
        builder: (context, d, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _Body(data: d)),
      );
}

class _Body extends StatefulWidget {
  final _Data data;
  const _Body({required this.data});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final List<Video> videos = widget.data.$1;
  late final Verification verification = widget.data.$2;
  late final Map<String, String> accounts = Map.of(widget.data.$3);
  late final List<PublishDestination> destinations = List.of(widget.data.$4);

  String addKind = 'website';
  final name = TextEditingController(), url = TextEditingController();
  bool adding = false;
  String? error;

  @override
  void dispose() {
    name.dispose();
    url.dispose();
    super.dispose();
  }

  List<Video> get ready => videos.where((v) => v.status == 'approved').toList();
  int get linked => accounts.length;

  Future<void> _connect(_Channel c) async {
    try {
      await repo.connectAccount(c.id);
      final next = await repo.accounts();
      if (!mounted) return;
      setState(() => accounts
        ..clear()
        ..addAll(next));
      showMsg(context, '${c.name} connected');
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _add() async {
    final isSite = addKind == 'website';
    if (name.text.trim().isEmpty) return setState(() => error = 'Give it a name');
    if (isSite && url.text.trim().isEmpty) return setState(() => error = 'Enter the web address your site listens on');
    setState(() {
      error = null;
      adding = true;
    });
    try {
      final d = await webRepo.addDestination(kind: addKind, name: name.text.trim(), url: url.text.trim());
      if (!mounted) return;
      setState(() {
        destinations.add(d);
        name.clear();
        url.clear();
      });
      showSuccess(context, isSite ? 'Website added' : 'Destination added');
    } catch (e) {
      if (mounted) setState(() => error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  Future<void> _remove(PublishDestination d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Remove ${d.name}?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Approved testimonials will no longer be sent there.', style: TextStyle(color: C.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Keep', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Remove', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await webRepo.deleteDestination(d.id);
      if (mounted) setState(() => destinations.removeWhere((x) => x.id == d.id));
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't remove it. Try again.");
    }
  }

  Future<void> _copyPost(Video v) async {
    await Clipboard.setData(ClipboardData(text: '"${v.quote}"\n\n- ${v.name}, customer of Hartley Roofing\n\nhttps://viewrec.com/t/${v.id}'));
    if (mounted) showMsg(context, 'Caption and link copied. Paste it where you post.');
  }

  Widget _badge(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c)),
      );

  Widget _step(int n, String title, String sub, bool done, {VoidCallback? onTap}) => Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, color: done ? C.green : C.surface2, border: done ? null : Border.all(color: C.border)),
              child: done ? const Icon(Icons.check_rounded, size: 17, color: Colors.white) : Text('$n', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: C.muted)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                Muted(sub, size: 13),
              ]),
            ),
            if (onTap != null && !done) Icon(Icons.chevron_right_rounded, color: C.muted),
          ]),
        ),
      );

  Widget _channelRow(_Channel c, {required bool last}) {
    final connected = accounts.containsKey(c.id);
    final Widget status = c.auto
        ? (connected ? _badge('Connected', C.green) : IntrinsicWidth(child: AppButton('Connect', small: true, style: BtnStyle.ghost, onTap: () => _connect(c))))
        : _badge('Posted by hand', C.amber);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: C.border))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GlossIcon(c.icon, c.auto && connected ? C.green : C.primary, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
              const SizedBox(width: 8),
              status,
            ]),
            const SizedBox(height: 3),
            Muted(c.does, size: 13),
            if (c.why.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Muted('Why: ${c.why}', size: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _destinationRow(PublishDestination d) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(18)),
          child: Row(children: [
            Icon(d.isWebsite ? Icons.language_rounded : Icons.edit_note_rounded, color: C.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                Muted(d.isWebsite ? d.url : 'Posted by hand', size: 12.5, maxLines: 1),
                if (d.isWebsite && d.secret.isNotEmpty)
                  GestureDetector(
                    onTap: () async {
                      await Clipboard.setData(ClipboardData(text: d.secret));
                      if (mounted) showMsg(context, 'Signing secret copied');
                    },
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Copy signing secret', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: C.primary)),
                    ),
                  ),
              ]),
            ),
            IconButton(onPressed: () => _remove(d), icon: Icon(Icons.delete_outline_rounded, color: C.muted, size: 20)),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final haveReady = ready.isNotEmpty;
    final verified = verification.status == 'verified';
    final all = haveReady && verified && linked > 0;
    final kinds = <(String, String)>[
      ('website', 'Website / CMS'),
      for (final c in _channels.where((c) => c.id != 'x')) (c.id, '${c.name} (post by hand)'),
    ];
    return AppPage(reveal: false, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            GlossIcon(all ? Icons.rocket_launch_rounded : Icons.hourglass_top_rounded, all ? C.green : C.amber, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(all ? 'Everything is ready to publish' : 'A few steps to go', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Muted(all ? 'Approved testimonials can go straight to your connected accounts.' : 'Finish these and approved testimonials can go to your accounts.', size: 13),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          _step(1, 'Something to publish', haveReady ? '${ready.length} approved and ready' : 'Approve a testimonial first', haveReady),
          _step(2, 'Your business verified', verified ? 'Checked and confirmed' : (verification.status == 'in_review' ? 'In review' : 'Not verified yet'), verified,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SubPageShell(title: 'Verification', child: VerificationScreen())))),
          _step(3, 'An account connected', linked > 0 ? '$linked linked' : 'Connect a channel below', linked > 0),
        ]),
      ),
      const SectionHeader('Where it can go'),
      const Muted('What each channel can do today, and what it is still waiting on.', size: 13),
      const SizedBox(height: 12),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(children: [for (var i = 0; i < _channels.length; i++) _channelRow(_channels[i], last: i == _channels.length - 1)]),
      ),
      const SectionHeader('Your own website'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Muted('A webhook your site listens on, so an approved testimonial can post itself there. It is for a developer building against it. If you just want your reviews on your website, use "On your website" instead, which gives you a line of script to paste into your page.', size: 13),
          const SizedBox(height: 14),
          if (destinations.isEmpty)
            const Muted('Nowhere to publish yet. Add your website below and approved testimonials can post themselves to it.', size: 13)
          else
            for (final d in destinations) _destinationRow(d),
        ]),
      ),
      const SectionHeader('Add a destination'),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Muted('When you approve a testimonial you choose which of these it goes to. It is never sent everywhere automatically.', size: 13),
          const SizedBox(height: 12),
          Wrap(children: [for (final k in kinds) AppChip(k.$2, active: addKind == k.$1, onTap: () => setState(() => addKind = k.$1))]),
          const SizedBox(height: 12),
          Field('Name', controller: name, hint: addKind == 'website' ? 'My website' : 'Our company page'),
          if (addKind == 'website') ...[
            Field('Web address', controller: url, hint: 'https://example.com/hooks/viewrec', keyboard: TextInputType.url),
            const Muted('We POST the testimonial as JSON and sign it with a secret, so your site can check the request really came from us.', size: 12.5),
            const SizedBox(height: 12),
          ],
          if (error != null) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(error!, style: TextStyle(color: C.rec, fontSize: 13))),
          AppButton(adding ? 'Adding…' : 'Add destination', icon: Icons.add_rounded, loading: adding, onTap: adding ? null : _add),
        ]),
      ),
      const SectionHeader('Waiting for you to post'),
      const Muted('Social platforms that need an account connection we cannot make yet. These are ready for you to post by hand.', size: 13),
      const SizedBox(height: 12),
      if (ready.isEmpty)
        const EmptyState(Icons.inbox_outlined, 'Nothing waiting', 'Approved testimonials show here when they are ready to post.')
      else
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < ready.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(border: i == ready.length - 1 ? null : Border(bottom: BorderSide(color: C.border))),
                child: Row(children: [
                  Avatar(ready[i].name, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(ready[i].name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Muted(ready[i].quote, size: 12.5, maxLines: 2),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  IntrinsicWidth(child: AppButton('Copy', icon: Icons.copy_rounded, small: true, style: BtnStyle.ghost, onTap: () => _copyPost(ready[i]))),
                ]),
              ),
          ]),
        ),
      const SizedBox(height: 120),
    ]);
  }
}
