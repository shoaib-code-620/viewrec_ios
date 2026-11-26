import 'package:flutter/material.dart';
import '../data.dart';
import '../liquid_widgets.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';
import 'caption_studio.dart';

/// Create content: a hub of things to make. Each tile opens its own full-screen maker.
class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});
  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

const _styles = [
  ('Bold', [Color(0xFF3E94F5), Color(0xFF0847A0)]),
  ('Fresh', [Color(0xFF5BE8C6), Color(0xFF0FA386)]),
  ('Warm', [Color(0xFFFFB199), Color(0xFFE4513F)]),
  ('Sunny', [Color(0xFFFFE07A), Color(0xFFF2A100)]),
];

class _CreateContentScreenState extends State<CreateContentScreen> {
  final drafts = <(String, String, String)>[
    ('Priya Nair', 'Quote card · Instagram, Facebook', 'Draft'),
    ('Aisha Rahman', 'Video clip · YouTube', 'Scheduled · Tue 10:00'),
    ('Seasonal gutter check offer', 'Facebook', 'Draft'),
  ];

  void _open(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  Widget _tile(String title, String sub, IconData icon, List<Color> g, VoidCallback onTap, {bool wide = false}) => Pressable(
        onTap: onTap,
        scale: 0.97,
        child: Container(
          height: wide ? 134 : 170,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [g.first, g.last]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          child: Stack(children: [
              wide
                  ? Row(children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.4)),
                          const SizedBox(height: 3),
                          Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, height: 1.3)),
                        ]),
                      ),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ])
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                        child: Icon(icon, color: Colors.white, size: 22),
                      ),
                      const Spacer(),
                      Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.3)),
                      Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                    ]),
            ]),
        ),
      );

  Widget _rail(String title, {String? action}) => Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 12),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.8))),
          if (action != null) Text(action, style: TextStyle(color: C.primary, fontWeight: FontWeight.w700, fontSize: 14)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    const names = ['Quote card', '5-star spotlight', 'Before & after', 'Thank you', 'Customer story', 'Offer banner', 'Meet the team', 'Seasonal'];
    return AppPage(children: [
      Text('What will you make today?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1.1, color: C.text)),
      const SizedBox(height: 6),
      const Muted('Turn a happy customer into a post in a few taps.'),
      const SizedBox(height: 18),
      _tile('Record a video', 'Script, captions and your logos', Icons.videocam_rounded, const [Color(0xFFFF9D92), Color(0xFFE4513F)], () => _open(const CaptionStudioScreen()), wide: true),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _tile('Quote card', 'From a review', Icons.format_quote_rounded, const [Color(0xFF3E94F5), Color(0xFF0847A0)], () => _open(const _Maker(format: 0)))),
        const SizedBox(width: 12),
        Expanded(child: _tile('Video clip', 'Short and shareable', Icons.movie_creation_rounded, const [Color(0xFF5BE8C6), Color(0xFF0FA386)], () => _open(const _Maker(format: 1)))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _tile('Story', 'Vertical, 24 hours', Icons.auto_stories_rounded, const [Color(0xFFFFD65A), Color(0xFFF2A100)], () => _open(const _Maker(format: 2)))),
        const SizedBox(width: 12),
        Expanded(child: _tile('Carousel', 'Swipe through', Icons.view_carousel_rounded, const [Color(0xFF8CC3FF), Color(0xFF2F6FE0)], () => _open(const _Maker(format: 3)))),
      ]),
      const SizedBox(height: 26),
      _rail('Start from a template'),
      SizedBox(
        height: 150,
        child: ListView.separated(
          clipBehavior: Clip.none,
          scrollDirection: Axis.horizontal,
          itemCount: names.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final g = _styles[i % _styles.length].$2;
            return Pressable(
              onTap: () => _open(_Maker(format: 0, style: i % _styles.length)),
              child: Container(
                width: 118,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
                  boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.format_quote_rounded, color: Colors.white70, size: 26),
                  const Spacer(),
                  Text(names[i], maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, height: 1.2)),
                ]),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 22),
      _rail('Drafts and scheduled', action: '${drafts.length}'),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Column(children: [
          for (var i = 0; i < drafts.length; i++)
            Tile(
              icon: drafts[i].$3 == 'Draft' ? Icons.edit_note_rounded : Icons.schedule_rounded,
              iconColor: drafts[i].$3 == 'Draft' ? C.amber : C.green,
              title: drafts[i].$1,
              subtitle: '${drafts[i].$2}\n${drafts[i].$3}',
              divider: i < drafts.length - 1,
              onTap: () => _open(const _Maker(format: 0)),
            ),
        ]),
      ),
      const SizedBox(height: 90),
    ]);
  }
}

/// Quote card / clip / story / carousel maker: a live preview on top, one small step at a time underneath.
class _Maker extends StatefulWidget {
  final int format;
  final int style;
  const _Maker({required this.format, this.style = 0});
  @override
  State<_Maker> createState() => _MakerState();
}

class _MakerState extends State<_Maker> {
  static const formats = ['Quote card', 'Video clip', 'Story', 'Carousel'];
  static const stepNames = ['Review', 'Style', 'Words', 'Post to'];
  final vids = demoVideos();
  final caption = TextEditingController(text: '“They turned up when they said they would…” Thank you for the kind words.');
  final chosen = <String>{'Facebook', 'Instagram'};
  final page = PageController();
  int step = 0, source = 0, style = 0, format = 0;

  @override
  void initState() {
    super.initState();
    format = widget.format;
    style = widget.style;
  }

  @override
  void dispose() {
    caption.dispose();
    page.dispose();
    super.dispose();
  }

  void _go(int s) {
    setState(() => step = s);
    page.animateToPage(s, duration: kMed, curve: kCurve);
  }

  Widget _preview() {
    final g = _styles[style].$2;
    final v = vids[source];
    return Container(
      height: 230,
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
        boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.35), blurRadius: 26, offset: const Offset(0, 12))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(999)),
            child: Text(formats[format], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          Stars(v.rating),
        ]),
        const Spacer(),
        Text('“${v.quote}”', maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: -0.4)),
        const SizedBox(height: 10),
        Text('${v.name} · ${v.job}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _stepReview() => ListView(padding: const EdgeInsets.only(top: 6), children: [
        const Muted('Pick the review to feature.', size: 13.5),
        const SizedBox(height: 12),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vids.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => Pressable(
              onTap: () => setState(() => source = i),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [vids[i].hue, Color.lerp(vids[i].hue, Colors.black, 0.5)!], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: source == i ? C.primary : Colors.transparent, width: 3),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Stars(vids[i].rating),
                  const SizedBox(height: 4),
                  Text(vids[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                  Text(vids[i].job, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                ]),
              ),
            ),
          ),
        ),
      ]);

  Widget _stepStyle() => ListView(padding: const EdgeInsets.only(top: 6), children: [
        const Muted('Choose a format and a look.', size: 13.5),
        const SizedBox(height: 12),
        Wrap(children: [for (var i = 0; i < formats.length; i++) AppChip(formats[i], active: format == i, onTap: () => setState(() => format = i))]),
        const SizedBox(height: 16),
        Row(children: [
          for (var i = 0; i < _styles.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => setState(() => style = i),
                child: Container(
                  height: 78,
                  margin: EdgeInsets.only(right: i < _styles.length - 1 ? 10 : 0),
                  padding: const EdgeInsets.all(10),
                  alignment: Alignment.bottomLeft,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _styles[i].$2),
                    border: Border.all(color: style == i ? C.text : Colors.transparent, width: 2.5),
                  ),
                  child: Text(_styles[i].$1, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                ),
              ),
            ),
        ]),
      ]);

  Widget _stepWords() => ListView(padding: const EdgeInsets.only(top: 6), children: [
        Field('Post text', controller: caption, lines: 5),
        Align(
          alignment: Alignment.centerRight,
          child: AppButton('Suggest new wording', icon: Icons.edit_note_rounded, small: true, style: BtnStyle.ghost, onTap: () {
            setState(() => caption.text = 'Five stars from ${vids[source].name}: “${vids[source].quote}” Thank you for the kind words.');
            showMsg(context, 'New wording added');
          }),
        ),
      ]);

  Widget _stepPost() => ListView(padding: const EdgeInsets.only(top: 6), children: [
        const Muted('Where should it go?', size: 13.5),
        const SizedBox(height: 12),
        Wrap(children: [
          for (final p in platforms)
            AppChip(p.name.split(' ').first, active: chosen.contains(p.name.split(' ').first), onTap: () {
              final n = p.name.split(' ').first;
              setState(() => chosen.contains(n) ? chosen.remove(n) : chosen.add(n));
            }),
        ]),
      ]);

  @override
  Widget build(BuildContext context) {
    final last = step == stepNames.length - 1;
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: LiquidBackdrop()),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
            child: Column(children: [
              BackHeader(formats[format]),
              _preview(),
              const SizedBox(height: 14),
              Row(children: [
                for (var i = 0; i < stepNames.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _go(i),
                      child: Column(children: [
                        AnimatedContainer(
                          duration: kMed,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: i <= step ? C.primary : C.border),
                        ),
                        const SizedBox(height: 6),
                        Text(stepNames[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: i == step ? C.text : C.muted)),
                      ]),
                    ),
                  ),
              ]),
              const SizedBox(height: 6),
              Expanded(
                child: PageView(
                  controller: page,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [_stepReview(), _stepStyle(), _stepWords(), _stepPost()],
                ),
              ),
              Row(children: [
                if (step > 0) ...[
                  Expanded(child: AppButton('Back', style: BtnStyle.ghost, onTap: () => _go(step - 1))),
                  const SizedBox(width: 10),
                ],
                if (!last)
                  Expanded(flex: 2, child: AppButton('Next', icon: Icons.arrow_forward_rounded, onTap: () => _go(step + 1)))
                else ...[
                  Expanded(
                    child: AppButton('Save draft', style: BtnStyle.ghost, onTap: () {
                      showMsg(context, 'Saved to drafts');
                      Navigator.pop(context);
                    }),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton('Schedule', icon: Icons.schedule_rounded, onTap: () {
                      showSuccess(context, 'Scheduled for tomorrow, 10:00');
                      Navigator.pop(context);
                    }),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}
