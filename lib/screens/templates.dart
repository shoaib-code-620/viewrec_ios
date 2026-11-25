import 'package:flutter/material.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Review templates: the questions a customer is guided through while recording.
class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<List<ReviewTemplate>>(
        load: webRepo.templates,
        builder: (context, list, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _TemplatesBody(initial: list)),
      );
}

class _TemplatesBody extends StatefulWidget {
  final List<ReviewTemplate> initial;
  const _TemplatesBody({required this.initial});
  @override
  State<_TemplatesBody> createState() => _TemplatesBodyState();
}

class _TemplatesBodyState extends State<_TemplatesBody> {
  late final list = List.of(widget.initial);

  void _edit([ReviewTemplate? t]) {
    final name = TextEditingController(text: t?.name ?? '');
    final qs = [for (final q in (t?.questions ?? ['What did we do for you?'])) TextEditingController(text: q)];
    showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2(t == null ? 'New template' : 'Edit template'),
          const SizedBox(height: 14),
          Field('Template name', controller: name, hint: 'Roof job'),
          const Text('Questions', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.34),
            child: ListView(shrinkWrap: true, children: [
              for (var i = 0; i < qs.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: C.primarySoft, shape: BoxShape.circle), child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: C.primary))),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: qs[i],
                        decoration: InputDecoration(
                          hintText: 'Ask a question',
                          isDense: true,
                          filled: true,
                          fillColor: C.surface2,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    IconButton(onPressed: qs.length > 1 ? () => set(() => qs.removeAt(i)) : null, icon: Icon(Icons.close_rounded, size: 18, color: C.muted), visualDensity: VisualDensity.compact),
                  ]),
                ),
            ]),
          ),
          if (qs.length < 6) TextButton.icon(onPressed: () => set(() => qs.add(TextEditingController())), icon: const Icon(Icons.add_rounded, size: 18), label: const Text('Add a question')),
          const SizedBox(height: 8),
          AppButton('Save template', small: true, onTap: () async {
            final questions = [for (final c in qs) if (c.text.trim().isNotEmpty) c.text.trim()];
            if (name.text.trim().isEmpty || questions.isEmpty) {
              showMsg(context, 'Add a name and at least one question.');
              return;
            }
            Navigator.pop(ctx);
            final saved = await webRepo.saveTemplate(id: t?.id, name: name.text.trim(), questions: questions);
            if (!mounted) return;
            setState(() {
              final i = list.indexWhere((x) => x.id == saved.id);
              if (i >= 0) {
                list[i] = saved;
              } else {
                list.add(saved);
              }
            });
          }),
        ]),
      ),
    );
  }

  Future<void> _makeDefault(ReviewTemplate t) async {
    setState(() {
      for (final x in list) {
        x.isDefault = x.id == t.id;
      }
    });
    await webRepo.setDefaultTemplate(t.id);
  }

  Future<void> _delete(ReviewTemplate t) async {
    if (list.length == 1) {
      showMsg(context, 'Keep at least one template.');
      return;
    }
    setState(() => list.remove(t));
    if (t.isDefault && list.isNotEmpty) setState(() => list.first.isDefault = true);
    await webRepo.deleteTemplate(t.id);
  }

  @override
  Widget build(BuildContext context) => AppPage(reveal: false, children: [
        const Muted('The questions customers see while they record. Pick one as the default for new invitations.').reveal(context, 0),
        const SizedBox(height: 14),
        AppButton('New template', icon: Icons.add_rounded, small: true, onTap: _edit).reveal(context, 1),
        const SizedBox(height: 14),
        for (var i = 0; i < list.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: AppCard(
              onTap: () => _edit(list[i]),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                  if (list[i].isDefault)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: C.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(999)), child: Text('Default', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: C.green))),
                ]),
                const SizedBox(height: 8),
                for (var q = 0; q < list[i].questions.length; q++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('${q + 1}. ${list[i].questions[q]}', style: TextStyle(color: C.muted, fontSize: 13.5, height: 1.35)),
                  ),
                const SizedBox(height: 10),
                Row(children: [
                  if (!list[i].isDefault) Expanded(child: AppButton('Make default', small: true, style: BtnStyle.ghost, onTap: () => _makeDefault(list[i]))),
                  if (!list[i].isDefault) const SizedBox(width: 8),
                  IconButton(onPressed: () => _delete(list[i]), icon: Icon(Icons.delete_outline_rounded, color: C.muted)),
                ]),
              ]),
            ),
          ).reveal(context, 2 + i, 0.08),
        const SizedBox(height: 80),
      ]);
}
