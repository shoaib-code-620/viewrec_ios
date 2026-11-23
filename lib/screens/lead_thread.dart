import 'package:flutter/material.dart';
import '../async_view.dart';
import '../models.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

/// Conversation with a person who sent a request, with a reply box.
class LeadThreadScreen extends StatelessWidget {
  final Lead lead;
  const LeadThreadScreen({super.key, required this.lead});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader(lead.name)),
            Expanded(
              child: AsyncView<List<ThreadMessage>>(
                load: () => repo.leadMessages(lead.id),
                skeletonCards: 2,
                builder: (context, msgs, refresh) => _ThreadBody(lead: lead, initial: msgs),
              ),
            ),
          ]),
        ),
      );
}

class _ThreadBody extends StatefulWidget {
  final Lead lead;
  final List<ThreadMessage> initial;
  const _ThreadBody({required this.lead, required this.initial});
  @override
  State<_ThreadBody> createState() => _ThreadBodyState();
}

class _ThreadBodyState extends State<_ThreadBody> {
  late final List<ThreadMessage> msgs = List.of(widget.initial);
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;

  static const quick = ['Thanks - when suits you?', 'Can you send a photo?', 'I can come Thursday morning'];

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? input.text).trim();
    if (t.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      final m = await repo.sendLeadMessage(widget.lead.id, t);
      if (!mounted) return;
      setState(() {
        msgs.add(m);
        input.clear();
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 100, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't send. Try again.");
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(child: Muted('${widget.lead.service} · via ${widget.lead.source}', size: 12.5)),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), children: [
            for (final m in msgs)
              Align(
                alignment: m.from == 'business' ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: m.from == 'business' ? C.primary : C.surface,
                    border: m.from == 'business' ? null : Border.all(color: C.border),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(m.from == 'business' ? 18 : 4),
                      bottomRight: Radius.circular(m.from == 'business' ? 4 : 18),
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.text, style: TextStyle(height: 1.4, fontSize: 14.5, color: m.from == 'business' ? Colors.white : C.text)),
                    const SizedBox(height: 4),
                    Text(m.when, style: TextStyle(fontSize: 10.5, color: m.from == 'business' ? Colors.white70 : C.muted)),
                  ]),
                ),
              ),
          ]),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final q in quick)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12.5)),
                  backgroundColor: C.surface,
                  side: BorderSide(color: C.border),
                  onPressed: sending ? null : () => _send(q),
                ),
              ),
          ]),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: input,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Write a reply',
                  hintStyle: TextStyle(color: C.muted),
                  filled: true,
                  fillColor: C.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: C.primary,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : _send,
                child: SizedBox(
                  width: 46,
                  height: 46,
                  child: sending
                      ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Icon(Icons.arrow_upward_rounded, size: 20, color: Colors.white),
                ),
              ),
            ),
          ]),
        ),
      ]);
}
