import 'package:flutter/material.dart';
import '../theme.dart';
import '../widgets.dart';

class _Msg {
  final String text;
  final bool mine;
  const _Msg(this.text, this.mine);
}

/// "Ask me anything" assistant chat.
class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});
  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final input = TextEditingController();
  final scroll = ScrollController();
  final msgs = <_Msg>[
    const _Msg("Hello. I am the ViewRec assistant. Ask me how to get more videos, who to invite, or how to post a testimonial.", false),
  ];
  bool typing = false;

  static const suggestions = ['Who should I invite first?', 'How do I post to Facebook?', 'Write a thank-you reply', 'What does Pro include?'];

  String _answer(String q) {
    final s = q.toLowerCase();
    if (s.contains('invite')) return 'Start with customers from the last 30 days who replied to you or left a 5-star review. They are the most likely to record. You will see them marked "Suggested" in your Phonebook.';
    if (s.contains('facebook') || s.contains('post')) return 'Open Connected accounts, connect Facebook, then go to Create content, pick a testimonial and choose Facebook. Nothing is posted until you press Schedule.';
    if (s.contains('thank')) return 'Try: "Thank you so much for taking the time to record that - it means a lot to the whole team. See you next time!"';
    if (s.contains('pro')) return 'Pro adds your logo on invitations, up to 5 reminders, Facebook and Instagram posting with no monthly limit, embeds and a testimonial wall, subtitles, and avatar mode for camera-shy customers.';
    return 'Good question. I can help with invitations, publishing and your plan. Try asking "Who should I invite first?"';
  }

  Future<void> _send([String? text]) async {
    final t = (text ?? input.text).trim();
    if (t.isEmpty) return;
    input.clear();
    setState(() {
      msgs.add(_Msg(t, true));
      typing = true;
    });
    _toEnd();
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      msgs.add(_Msg(_answer(t), false));
      typing = false;
    });
    _toEnd();
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 80, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });

  @override
  void dispose() {
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: BackHeader('Ask me anything')),
            Expanded(
              child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 4, 16, 8), children: [
                for (final m in msgs)
                  Align(
                    alignment: m.mine ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: m.mine ? C.primary : C.surface,
                        border: m.mine ? null : Border.all(color: C.border),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(m.mine ? 18 : 4),
                          bottomRight: Radius.circular(m.mine ? 4 : 18),
                        ),
                      ),
                      child: Text(m.text, style: const TextStyle(height: 1.4, fontSize: 15)),
                    ),
                  ),
                if (typing)
                  const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.all(8), child: Muted('Thinking…', size: 13))),
                if (msgs.length == 1)
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final s in suggestions)
                      ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 13)),
                        backgroundColor: C.surface,
                        side: BorderSide(color: C.border),
                        onPressed: () => _send(s),
                      ),
                  ]),
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
                      hintText: 'Ask me anything',
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
                  child: InkWell(customBorder: const CircleBorder(), onTap: _send, child: const SizedBox(width: 46, height: 46, child: Icon(Icons.arrow_upward_rounded, size: 20))),
                ),
              ]),
            ),
          ]),
        ),
      );
}
