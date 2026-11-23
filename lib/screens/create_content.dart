import 'package:flutter/material.dart';
import '../data.dart';
import '../theme.dart';
import '../widgets.dart';

class CreateContentScreen extends StatefulWidget {
  const CreateContentScreen({super.key});
  @override
  State<CreateContentScreen> createState() => _CreateContentScreenState();
}

class _CreateContentScreenState extends State<CreateContentScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) => AppPage(children: [
        const Muted('Turn a testimonial into posts, clips and quote cards in a few taps.'),
        const SizedBox(height: 14),
        Pills(const ['Create', 'Templates', 'Drafts'], tab, (i) => setState(() => tab = i)),
        const SizedBox(height: 14),
        if (tab == 0) const _Create(),
        if (tab == 1) const _Templates(),
        if (tab == 2) const _Drafts(),
        const SizedBox(height: 80),
      ]);
}

class _Create extends StatefulWidget {
  const _Create();
  @override
  State<_Create> createState() => _CreateState();
}

class _CreateState extends State<_Create> {
  int source = 0;
  int template = 0;
  int format = 0;
  final caption = TextEditingController(text: 'Another happy customer! “They turned up when they said they would…” Thank you for the kind words.');
  final chosen = <String>{'Facebook', 'Instagram'};
  final vids = demoVideos();

  @override
  void dispose() {
    caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('1. Pick a testimonial'),
        const SizedBox(height: 10),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: vids.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => GestureDetector(
              onTap: () => setState(() => source = i),
              child: Container(
                width: 150,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [vids[i].hue, C.bg], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  borderRadius: BorderRadius.circular(rMd),
                  border: Border.all(color: source == i ? C.primary : C.border, width: source == i ? 2 : 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                  Stars(vids[i].rating),
                  const SizedBox(height: 4),
                  Text(vids[i].name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                  Text(vids[i].job, style: const TextStyle(fontSize: 11, color: Colors.white70)),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const H2('2. Choose a format'),
        const SizedBox(height: 10),
        Pills(const ['Quote card', 'Video clip', 'Story', 'Carousel'], format, (i) => setState(() => format = i)),
        const SizedBox(height: 10),
        const H2('3. Pick a style'),
        const SizedBox(height: 10),
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => template = i),
                child: Container(
                  height: 96,
                  margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      [const Color(0xFF6A4CF0), const Color(0xFF8B6DFF)],
                      [const Color(0xFF0E7C66), const Color(0xFF2DD4A0)],
                      [const Color(0xFFC2185B), const Color(0xFFFF6F91)],
                    ][i]),
                    borderRadius: BorderRadius.circular(rMd),
                    border: Border.all(color: template == i ? Colors.white : Colors.transparent, width: 2),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.format_quote_rounded, size: 20, color: Colors.white),
                    const Spacer(),
                    Text(['Bold', 'Fresh', 'Warm'][i], style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 20),
        const H2('4. Caption'),
        const SizedBox(height: 10),
        Field('Post text', controller: caption, lines: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showMsg(context, 'Caption rewritten'),
            icon: const Icon(Icons.auto_awesome_rounded, size: 16),
            label: const Text('Rewrite with AI'),
          ),
        ),
        const SizedBox(height: 6),
        const H2('5. Post to'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final p in platforms)
            FilterChip(
              label: Text(p.name.split(' ').first),
              avatar: Icon(p.icon, size: 15),
              selected: chosen.contains(p.name.split(' ').first),
              onSelected: (v) => setState(() => v ? chosen.add(p.name.split(' ').first) : chosen.remove(p.name.split(' ').first)),
              selectedColor: C.primarySoft,
              backgroundColor: C.surface,
              side: BorderSide(color: C.border),
              showCheckmark: false,
            ),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: AppButton('Save draft', style: BtnStyle.ghost, onTap: () => showMsg(context, 'Saved to drafts'))),
          const SizedBox(width: 10),
          Expanded(child: AppButton('Schedule', icon: Icons.schedule_rounded, onTap: () => showMsg(context, 'Scheduled for tomorrow, 10:00'))),
        ]),
      ]);
}

class _Templates extends StatelessWidget {
  const _Templates();
  @override
  Widget build(BuildContext context) {
    const names = ['Quote card', '5-star spotlight', 'Before & after', 'Thank you', 'Customer story', 'Offer banner', 'Meet the team', 'Seasonal'];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.95,
      children: [
        for (var i = 0; i < names.length; i++)
          AppCard(
            padding: EdgeInsets.zero,
            onTap: () => showMsg(context, '${names[i]} selected'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      HSLColor.fromAHSL(1, (i * 45.0) % 360, 0.6, 0.35).toColor(),
                      HSLColor.fromAHSL(1, ((i * 45.0) + 40) % 360, 0.6, 0.2).toColor(),
                    ]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(rLg)),
                  ),
                  child: const Center(child: Icon(Icons.format_quote_rounded, size: 34, color: Colors.white70)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(names[i], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
              ),
            ]),
          ),
      ],
    );
  }
}

class _Drafts extends StatelessWidget {
  const _Drafts();
  @override
  Widget build(BuildContext context) => Column(children: [
        for (final d in const [
          ('Priya Nair - Quote card', 'Instagram, Facebook', 'Draft'),
          ('Aisha Rahman - Video clip', 'YouTube', 'Scheduled · Tue 10:00'),
          ('Seasonal gutter check offer', 'Facebook', 'Draft'),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.image_rounded, color: C.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.$1, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Muted(d.$2, size: 12.5),
                    const SizedBox(height: 4),
                    Text(d.$3, style: TextStyle(fontSize: 12, color: d.$3 == 'Draft' ? C.amber : C.green, fontWeight: FontWeight.w600)),
                  ]),
                ),
                Icon(Icons.more_vert_rounded, color: C.muted),
              ]),
            ),
          ),
      ]);
}
