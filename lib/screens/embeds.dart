import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../async_view.dart';
import '../entitlement.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Embeds: put your testimonials on your own website with one line of code. Pro and up.
class EmbedsScreen extends StatelessWidget {
  const EmbedsScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<(List<EmbedItem>, Entitlement)>(
        load: () async => (await webRepo.embeds(), await loadEntitlement()),
        builder: (context, d, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _Body(initial: d.$1, ent: d.$2)),
      );
}

class _Body extends StatefulWidget {
  final List<EmbedItem> initial;
  final Entitlement ent;
  const _Body({required this.initial, required this.ent});
  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  late final list = List.of(widget.initial);

  void _create() {
    if (!widget.ent.allows('embeds')) {
      showUpgrade(context, widget.ent, 'embeds', 'Embeds');
      return;
    }
    final name = TextEditingController();
    var layout = 'wall';
    var count = 6.0;
    showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('New embed'),
          const SizedBox(height: 14),
          Field('Name', controller: name, hint: 'Home page wall'),
          const Text('Layout', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(runSpacing: 8, children: [
            AppChip('Wall (grid)', active: layout == 'wall', onTap: () => set(() => layout = 'wall')),
            AppChip('Carousel', active: layout == 'carousel', onTap: () => set(() => layout = 'carousel')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Expanded(child: Text('Testimonials to show', style: TextStyle(fontWeight: FontWeight.w800))),
            Text('${count.round()}', style: TextStyle(fontWeight: FontWeight.w800, color: C.primary)),
          ]),
          Slider(value: count, min: 3, max: 12, divisions: 9, activeColor: C.primary, onChanged: (v) => set(() => count = v)),
          AppButton('Create embed', small: true, onTap: () async {
            if (name.text.trim().isEmpty) {
              showMsg(context, 'Give the embed a name.');
              return;
            }
            Navigator.pop(ctx);
            final e = await webRepo.createEmbed(name: name.text.trim(), layout: layout, count: count.round());
            if (!mounted) return;
            setState(() => list.insert(0, e));
            showSuccess(context, 'Embed created');
          }),
        ]),
      ),
    );
  }

  Future<void> _delete(EmbedItem e) async {
    setState(() => list.remove(e));
    try {
      await webRepo.deleteEmbed(e.id);
    } catch (_) {
      if (mounted) setState(() => list.insert(0, e));
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(reveal: false, children: [
        const Muted('Paste one line of code into your own website and your testimonials appear there. They update when you publish new ones.').reveal(context, 0),
        if (!widget.ent.allows('embeds')) ...[
          const SizedBox(height: 12),
          const InfoBanner('Embeds are a Pro feature. Change your plan under Plan & billing to create them.', icon: Icons.lock_rounded).reveal(context, 1),
        ],
        const SizedBox(height: 14),
        AppButton('New embed', icon: Icons.add_rounded, small: true, onTap: _create).reveal(context, 2),
        const SizedBox(height: 14),
        if (list.isEmpty) const EmptyState(Icons.code_rounded, 'No embeds yet', 'Create one to show your testimonials on your website.'),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  IconButton(onPressed: () => _delete(list[i]), icon: Icon(Icons.delete_outline_rounded, color: C.muted, size: 20), visualDensity: VisualDensity.compact),
                ]),
                Muted('${list[i].layout == 'wall' ? 'Wall' : 'Carousel'} · ${list[i].count} testimonials · ${list[i].created}', size: 12.5),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(14)),
                  child: Text(list[i].code, style: TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: C.text, height: 1.4)),
                ),
                const SizedBox(height: 10),
                AppButton('Copy code', icon: Icons.copy_rounded, small: true, style: BtnStyle.ghost, onTap: () async {
                  await Clipboard.setData(ClipboardData(text: list[i].code));
                  if (context.mounted) showMsg(context, 'Code copied. Paste it into your website.');
                }),
              ]),
            ),
          ).reveal(context, 3 + i, 0.08),
        const SizedBox(height: 80),
      ]);
}
