import 'package:flutter/material.dart';
import '../data.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';
import 'pricing.dart';

/// The rest of the ViewRec "premium HD look" landing page, section by section, for the Welcome screen.
class LandingSections extends StatefulWidget {
  final VoidCallback onStart;
  const LandingSections({super.key, required this.onStart});
  @override
  State<LandingSections> createState() => _LandingSectionsState();
}

const _navy = Color(0xFF0B1B3A);
const _body = Color(0xFF41567A);

class _LandingSectionsState extends State<LandingSections> {
  Widget _eyebrow(String t, Color c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: c)),
      );

  Widget _h(String t, {Color? color, double size = 30}) => Text(t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, letterSpacing: -1.3, height: 1.08, color: color ?? C.text));

  Widget _p(String t, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text(t, style: TextStyle(fontSize: 15, height: 1.55, color: color ?? (C.dark ? C.muted : _body))),
      );

  /// A big rounded panel, tinted like the design's coloured sections.
  Widget _panel(List<Color> tint, Widget child, {EdgeInsets padding = const EdgeInsets.all(22)}) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.dark ? [C.surface, C.surface2] : tint),
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: C.dark ? C.border : Colors.white.withValues(alpha: 0.9)),
          boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.10), blurRadius: 28, offset: const Offset(0, 12))],
        ),
        child: child,
      );

  Widget _pill(String t, List<Color> g, {Color fg = Colors.white}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: fg)),
      );

  Widget _glassPill(String t, {IconData? icon, Color? color}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: C.dark ? C.surface2 : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: C.dark ? C.border : Colors.white),
          boxShadow: C.shadow,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 15, color: color ?? C.primary), const SizedBox(width: 6)],
          Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.text)),
        ]),
      );

  // ---------- publishes to ----------
  Widget _publishes() {
    const icons = [Icons.language_rounded, Icons.bookmark_rounded, Icons.facebook_rounded, Icons.camera_alt_rounded, Icons.alternate_email_rounded, Icons.business_center_rounded];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.32), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Row(children: [
        const Text('PUBLISHES TO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Colors.white)),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: icons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 6, offset: const Offset(0, 3))]),
                child: Icon(icons[i], size: 17, color: C.primary),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ---------- why video ----------
  Widget _whyVideo() => _panel(const [Color(0xFFFFE3DE), Color(0xFFFFF4F1)], Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('WHY VIDEO', const Color(0xFFE4513F)),
        _h('People stopped believing reviews. They still believe people.'),
        _p('A face and a voice cannot be bulk-ordered. A real customer saying what you did for them is the proof a text review can no longer give.'),
        const SizedBox(height: 18),
        _glassCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: List.generate(5, (_) => const Icon(Icons.star_rounded, size: 18, color: Color(0xFFFFC21A)))),
          const SizedBox(height: 6),
          Text('Great service! Highly recommend. Five stars.', style: TextStyle(fontSize: 14, color: C.muted)),
          const SizedBox(height: 6),
          Text('A text review. Anyone can write one.', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.muted)),
        ])),
        const SizedBox(height: 12),
        _glassCard(Row(children: [
          const GlossIcon(Icons.play_arrow_rounded, Color(0xFFFF6B5E), size: 46, circle: true),
          const SizedBox(width: 14),
          Expanded(child: Text('A real person, on camera.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: C.text))),
        ])),
      ]));

  Widget _glassCard(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: C.dark ? C.surface : Colors.white.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: C.dark ? C.border : Colors.white),
          boxShadow: C.shadow,
        ),
        child: child,
      );

  // ---------- coach ----------
  Widget _bubble(String who, String text, {bool coach = false}) => Align(
        alignment: coach ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 270),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: coach ? const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFD65A), Color(0xFFF2A100)]) : null,
            color: coach ? null : (C.dark ? C.surface2 : Colors.white),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: (coach ? const Color(0xFFF2A100) : _navy).withValues(alpha: coach ? 0.35 : 0.08), blurRadius: 14, offset: const Offset(0, 5))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(who, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: coach ? _navy.withValues(alpha: 0.7) : C.muted)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(fontSize: 14, fontWeight: coach ? FontWeight.w800 : FontWeight.w500, height: 1.35, color: coach ? _navy : C.text)),
          ]),
        ),
      );

  Widget _wave() => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 26; i++)
          Container(
            width: 3,
            height: 6.0 + ((i * 7) % 5) * 4,
            margin: const EdgeInsets.only(right: 3),
            decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(2)),
          ),
      ]);

  Widget _coach() => _panel(const [Color(0xFFDCEBFF), Color(0xFFEEF5FF)], Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('LIVE AI COACH', C.primary),
        _h('It asks the follow-up a good interviewer would.'),
        _p('When an answer is vague, the AI asks one natural question while your customer is still talking. You get specifics, not "great service".'),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _glassPill('Script written for your business', icon: Icons.check_rounded, color: C.green),
          _glassPill('Asks follow-ups live', icon: Icons.check_rounded, color: C.green),
          _glassPill('Words on screen', icon: Icons.check_rounded, color: C.green),
        ]),
        const SizedBox(height: 18),
        _glassCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WITHOUT A COACH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: C.muted)),
          const SizedBox(height: 4),
          Text('"They were great. Would recommend."', style: TextStyle(fontSize: 14, color: C.muted)),
        ])),
        const SizedBox(height: 12),
        _glassCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('WITH THE AI COACH', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: C.primary)),
          const SizedBox(height: 12),
          _bubble('Customer', 'They were great, would recommend.'),
          _bubble('AI coach', 'What was the problem before you called them?', coach: true),
          _bubble('Customer', 'Our boiler died on a Sunday. They had it fixed in two hours.'),
          Row(children: [
            Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, physics: const NeverScrollableScrollPhysics(), child: _wave())),
            const SizedBox(width: 10),
            _pill('Specific. Believable.', C.gradTeal),
          ]),
        ])),
      ]));

  // ---------- who does what ----------
  Widget _whoDoesWhat() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('WHO DOES WHAT', C.green),
        _h('Your side is tiny. Ours is not.', size: 32),
        const SizedBox(height: 18),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('YOUR SIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: C.primary)),
            const SizedBox(height: 6),
            _h('Two things. That is all.', size: 22),
            const SizedBox(height: 16),
            Container(
              height: 150,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF7DB8FF), Color(0xFF0B5FC4)]),
              ),
              alignment: Alignment.bottomRight,
              padding: const EdgeInsets.all(10),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4), decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)), child: const Text('0:42', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _pill('Approve', C.gradTeal)),
              const SizedBox(width: 10),
              Expanded(child: _glassPill('Not this one')),
            ]),
          ]),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(36),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradBlueDeep, stops: [0, 0.55, 1]),
              boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 28, offset: const Offset(0, 12))],
            ),
            child: Stack(children: [
              const Positioned.fill(child: PlayPattern()),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('OUR SIDE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white70)),
                const SizedBox(height: 6),
                _h('Everything else is ours.', size: 24, color: Colors.white),
                _p('Your simple side is simple because our team does the thinking a self-serve tool would ask you to do.', color: Colors.white70),
                const SizedBox(height: 16),
                Wrap(spacing: 8, runSpacing: 10, children: [
                  _pill('Campaign goals', C.gradYellow, fg: _navy),
                  _pill('Review inbox', const [Colors.white, Color(0xFFEAF2FF)], fg: _navy),
                  _pill('Tags and sentiment', C.gradTeal),
                  _pill('Authenticity check', C.gradCoral),
                  _pill('Publish controls', C.gradYellow, fg: _navy),
                  _pill('Account-health alerts', const [Colors.white, Color(0xFFEAF2FF)], fg: _navy),
                  _pill('Monthly report', C.gradTeal),
                ]),
              ]),
            ]),
          ),
        ),
      ]);

  // ---------- six steps ----------
  Widget _steps() {
    const steps = [
      ('1', 'OUR TEAM', 'Pick this month\'s push', 'We set the goal with you, so every video helps one real business aim.', C.gradBlue, ['Pricing objection', 'Onboarding ease', 'Referral push']),
      ('2', 'AUTOMATIC', 'Invite and remind', 'A link by text, email or QR. No login. Reminders go out if they have not recorded.', C.gradTeal, <String>[]),
      ('3', 'CUSTOMER', 'Record with an AI coach', 'A script tailored to your business, and follow-up questions while they talk.', C.gradCoral, <String>[]),
      ('4', 'CUSTOMER', 'They choose where it can go', 'Consent for each place, before they submit.', C.gradYellow, ['Website', 'Social', 'Marketing']),
      ('5', 'AI + OUR TEAM', 'We check it', 'AI tags theme and tone and flags anything that looks off. A person on our team checks. A written case study is drafted from the same recording.', C.gradBlue, <String>[]),
      ('6', 'YOU', 'You tap approve', 'Approve or reject. Nothing goes live without you. Then it publishes for you.', C.gradTeal, <String>[]),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('HOW IT WORKS', C.primary),
      _h('Six steps. You only do one.', size: 32),
      const SizedBox(height: 18),
      for (final s in steps)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: s.$5),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    boxShadow: [BoxShadow(color: s.$5.last.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 5))],
                  ),
                  child: Text(s.$1, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: s.$5 == C.gradYellow ? _navy : Colors.white)),
                ),
                const Spacer(),
                _pill(s.$2, s.$5, fg: s.$5 == C.gradYellow ? _navy : Colors.white),
              ]),
              const SizedBox(height: 14),
              Text(s.$3, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
              _p(s.$4),
              if (s.$6.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final t in s.$6) _glassPill(t)]),
              ],
            ]),
          ),
        ),
    ]);
  }

  // ---------- one recording, four things ----------
  Widget _four() {
    const items = [
      (Icons.play_arrow_rounded, 'The video', 'A vertical 9:16 testimonial, ready for phones.', [Color(0xFFDCEBFF), Color(0xFFF4F9FF)], C.primary),
      (Icons.article_rounded, 'A written case study', 'Drafted from the same recording. A second asset, no extra effort from your customer.', [Color(0xFFFFEFB8), Color(0xFFFFFBEA)], Color(0xFFF2A100)),
      (Icons.sell_rounded, 'Tagged and searchable', 'Theme and tone tagged. Video markup so Google can show a thumbnail.', [Color(0xFFCFF5EA), Color(0xFFF1FFFA)], Color(0xFF1FC9A4)),
      (Icons.bar_chart_rounded, 'A monthly report', 'One page: what was collected, where it went, the best quote.', [Color(0xFFFFDDD7), Color(0xFFFFF6F4)], Color(0xFFFF6B5E)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('FROM ONE RECORDING', C.rec),
      _h('One recording, four things you can use.', size: 30),
      const SizedBox(height: 18),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.dark ? [C.surface, C.surface2] : it.$4),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: C.dark ? C.border : Colors.white),
              boxShadow: C.shadow,
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GlossIcon(it.$1, it.$5, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(it.$2, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(it.$3, style: TextStyle(fontSize: 14, height: 1.45, color: C.muted)),
                ]),
              ),
            ]),
          ),
        ),
    ]);
  }

  // ---------- human in the loop ----------
  Widget _human() {
    const items = [
      ('Content quality', 'Nothing awkward or off-brand goes out.', Icons.verified_rounded, C.primary),
      ('Consent', 'Edge cases and opt-outs are handled with care.', Icons.handshake_rounded, Color(0xFF1FC9A4)),
      ('Tag accuracy', 'A person spot-checks the AI against the video.', Icons.sell_rounded, Color(0xFFF2A100)),
      ('Publishing health', 'We catch failed posts before you notice.', Icons.monitor_heart_rounded, Color(0xFFFF6B5E)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('HUMAN IN THE LOOP', C.green),
      _h('AI does the heavy lifting. A person checks the work.', size: 28),
      const SizedBox(height: 18),
      AppCard(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
        child: Column(children: [
          for (var i = 0; i < items.length; i++) Tile(icon: items[i].$3, iconColor: items[i].$4, title: items[i].$1, subtitle: items[i].$2, divider: i < items.length - 1),
        ]),
      ),
    ]);
  }

  // ---------- agencies ----------
  Widget _agencies() => _panel(const [Color(0xFFD9F6EE), Color(0xFFF0FFFA)], Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('FOR AGENCIES', const Color(0xFF0FA386)),
        _h('Run it under your own name.', size: 28),
        _p('Add video proof to every client you serve. One partnership can carry dozens of clients, under your branding.'),
        const SizedBox(height: 16),
        Text('Built for', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.muted)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _glassPill('Local services'),
          _glassPill('Coaches and consultants'),
          _glassPill('Small B2B software'),
          _glassPill('Marketing agencies'),
        ]),
      ]));

  // ---------- pricing ----------
  Widget _pricing() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _eyebrow('PRICING', C.primary),
        _h('Choose how much we do for you', size: 32),
        const SizedBox(height: 18),
        for (final p in plans.where((p) => !p.custom)) Padding(padding: const EdgeInsets.only(bottom: 18), child: PlanTicket(plan: p, yearly: false)),
        AppCard(
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Managed and Agency', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text('Our team runs it, or you resell it', style: TextStyle(fontSize: 14, color: C.muted)),
            const SizedBox(height: 10),
            _h("Let's talk", size: 28),
            const SizedBox(height: 14),
            for (final f in const ['Campaign goals set with you', 'Monthly report from our team', 'White-label for agencies'])
              Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(children: [Icon(Icons.check_rounded, size: 18, color: C.green), const SizedBox(width: 10), Expanded(child: Text(f, style: const TextStyle(fontSize: 14)))]),
              ),
            const SizedBox(height: 8),
            AppButton('Talk to us', style: BtnStyle.ghost, onTap: () => showMsg(context, 'We will get in touch')),
          ]),
        ),
      ]);

  // ---------- closing call ----------
  Widget _closing() => ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: C.gradBlueDeep, stops: [0, 0.55, 1]),
            boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.32), blurRadius: 30, offset: const Offset(0, 14))],
          ),
          child: Stack(children: [
            const Positioned.fill(child: PlayPattern()),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _h('Your best customers have already said it. Let us get it on camera.', size: 26, color: Colors.white),
              const SizedBox(height: 20),
              Pressable(
                onTap: widget.onStart,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFD65A), Color(0xFFF2A100)]),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: const Color(0xFFF2A100).withValues(alpha: 0.5), blurRadius: 18, offset: const Offset(0, 7))],
                  ),
                  child: const Text('Start for \$1', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _navy)),
                ),
              ),
            ]),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 34);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _publishes(),
      gap,
      _whyVideo(),
      gap,
      _coach(),
      gap,
      _whoDoesWhat(),
      gap,
      _steps(),
      gap,
      _four(),
      gap,
      _human(),
      gap,
      _agencies(),
      gap,
      _pricing(),
      gap,
      _closing(),
      const SizedBox(height: 16),
      Center(child: Text('Built by Systematic IT Solutions. Customers and opt-outs are respected permanently.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: C.muted))),
      const SizedBox(height: 4),
      Center(child: Text('© 2026 ViewRec', style: TextStyle(fontSize: 12, color: C.muted))),
    ]);
  }
}
