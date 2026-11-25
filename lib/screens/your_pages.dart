import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

/// Review page, public directory listing, and website embeds.
class YourPagesScreen extends StatefulWidget {
  const YourPagesScreen({super.key});
  @override
  State<YourPagesScreen> createState() => _YourPagesScreenState();
}

class _YourPagesScreenState extends State<YourPagesScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => AppPage(children: [
        const Muted('Where your customers find your proof: your review page, public listing and website.'),
        const SizedBox(height: 14),
        Pills(const ['Review page', 'Public listing', 'Website embed'], tab, (i) => setState(() => tab = i)),
        const SizedBox(height: 14),
        if (tab == 0) const _ReviewPage(),
        if (tab == 1) const _Listing(),
        if (tab == 2) const _Embed(),
        const SizedBox(height: 80),
      ]);
}

class _LinkBox extends StatelessWidget {
  final String link;
  const _LinkBox(this.link);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(rMd)),
        child: Row(children: [
          Expanded(child: Text(link, style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5), overflow: TextOverflow.ellipsis)),
          IconButton(icon: const Icon(Icons.copy_rounded, size: 18), onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            showMsg(context, 'Link copied');
          }),
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            onPressed: () async {
              final u = Uri.tryParse(link.startsWith('http') ? link : 'https://$link');
              if (u == null || !await launchUrl(u, mode: LaunchMode.externalApplication)) {
                if (context.mounted) showMsg(context, "Couldn't open the link");
              }
            },
          ),
        ]),
      );
}

class _ReviewPage extends StatefulWidget {
  const _ReviewPage();
  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  bool live = true, showRatings = true, showVideo = true;
  @override
  Widget build(BuildContext context) {
    final vids = demoVideos().where((v) => v.status == 'published').take(2).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _LinkBox('https://viewrec.com/r/demo'),
      const SizedBox(height: 14),
      AppCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          Container(
            height: 90,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF3A2A8C), Color(0xFF0B5FC4)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(rLg)),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Column(children: [
              CircleAvatar(radius: 30, backgroundColor: C.surface2, child: Text('HR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: C.text))),
              const SizedBox(height: 8),
              const Text('Hartley Roofing', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Row(mainAxisSize: MainAxisSize.min, children: [Stars(5), SizedBox(width: 6), Muted('5.0 · 7 testimonials', size: 12.5)]),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(children: [
                  for (final v in vids)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(rMd)),
                      child: Row(children: [
                        SizedBox(width: 72, child: VideoThumb(hue: v.hue, height: 56)),
                        const SizedBox(width: 12),
                        Expanded(child: Text('“${v.quote}”', maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, height: 1.35))),
                      ]),
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
      const SectionHeader('Page settings'),
      AppCard(
        child: Column(children: [
          SwitchTile('Page is live', live, (v) => setState(() => live = v)),
          Divider(color: C.border),
          SwitchTile('Show star ratings', showRatings, (v) => setState(() => showRatings = v)),
          Divider(color: C.border),
          SwitchTile('Show video testimonials first', showVideo, (v) => setState(() => showVideo = v)),
        ]),
      ),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: AppButton('Edit page', icon: Icons.edit_rounded, small: true, onTap: () => showMsg(context, 'Page editor opens here'))),
        const SizedBox(width: 8),
        Expanded(child: AppButton('QR code', icon: Icons.qr_code_2_rounded, small: true, style: BtnStyle.ghost, onTap: () => _qr(context))),
      ]),
    ]);
  }

  void _qr(BuildContext context) => showSheet(
        context,
        Column(children: [
          const H2('Scan to leave a video'),
          const SizedBox(height: 16),
          Container(
            width: 190,
            height: 190,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: GridView.count(
              crossAxisCount: 11,
              physics: const NeverScrollableScrollPhysics(),
              children: [for (var i = 0; i < 121; i++) Container(margin: const EdgeInsets.all(0.7), color: ((i * 7 + i ~/ 11 * 3) % 5 < 2) ? Colors.black : Colors.white)],
            ),
          ),
          const SizedBox(height: 14),
          const Muted('Print it for your van, invoices or counter.', size: 13),
          const SizedBox(height: 14),
          AppButton('Download QR', icon: Icons.download_rounded, onTap: () => Navigator.pop(context)),
        ]),
      );
}

class _Listing extends StatefulWidget {
  const _Listing();
  @override
  State<_Listing> createState() => _ListingState();
}

class _ListingState extends State<_Listing> {
  bool listed = true, requests = true;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const InfoBanner('Your free public listing lets customers find you in the ViewRec directory and send a request.', icon: Icons.travel_explore_rounded),
        const SizedBox(height: 14),
        AppCard(
          child: Column(children: [
            SwitchTile('Listed in the directory', listed, (v) => setState(() => listed = v)),
            Divider(color: C.border),
            SwitchTile('Show "Request" button', requests, (v) => setState(() => requests = v), subtitle: 'Leads arrive under Leads and Requests'),
          ]),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Column(children: [
            const Tile(icon: Icons.category_rounded, title: 'Category', subtitle: 'Home & Trades'),
            const Tile(icon: Icons.place_rounded, title: 'Service area', subtitle: 'Greater Manchester · 25 miles'),
            const Tile(icon: Icons.schedule_rounded, title: 'Opening hours', subtitle: 'Mon–Fri 8:00–18:00'),
            Tile(icon: Icons.workspace_premium_rounded, title: 'Pro badge', subtitle: 'Shown on Pro and above', iconColor: C.amber, divider: false, onTap: () => showMsg(context, 'The Pro badge appears on your public page automatically')),
          ]),
        ),
        const SizedBox(height: 14),
        AppButton('Edit listing', icon: Icons.edit_rounded, onTap: () => showMsg(context, 'Listing editor opens here')),
      ]);
}

class _Embed extends StatefulWidget {
  const _Embed();
  @override
  State<_Embed> createState() => _EmbedState();
}

class _EmbedState extends State<_Embed> {
  int style = 0;
  bool subtitles = true;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Show reviews on your website'),
        const SizedBox(height: 4),
        const Muted('Paste one snippet into your site. It updates itself as you approve new videos.', size: 13),
        const SizedBox(height: 14),
        Pills(const ['Wall', 'Carousel', 'Single video', 'Badge'], style, (i) => setState(() => style = i)),
        const SizedBox(height: 12),
        AppCard(
          child: Column(children: [
            Row(children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Container(
                    height: style == 2 || style == 3 ? 100 : 80 + i * 16.0,
                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [demoVideos()[i].hue, C.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Icon(Icons.play_circle_outline_rounded, size: 26, color: Colors.white)),
                  ),
                ),
            ]),
            const SizedBox(height: 10),
            SwitchTile('Video subtitles', subtitles, (v) => setState(() => subtitles = v)),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(rMd)),
          child: const Text('<script src="https://viewrec.com/embed.js"\n  data-business="demo" data-style="wall"></script>',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12, height: 1.5)),
        ),
        const SizedBox(height: 12),
        AppButton('Copy embed code', icon: Icons.copy_rounded, onTap: () => showMsg(context, 'Embed code copied')),
        const SizedBox(height: 8),
        const Muted('0 embeds installed so far. Embeds, wall and subtitles are part of the Pro plan.', size: 12.5),
      ]);
}
