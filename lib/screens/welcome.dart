import 'dart:async';
import 'package:flutter/material.dart';
import '../icons.dart';
import '../liquid_widgets.dart';
import '../motion.dart';
import '../theme.dart';
import '../widgets.dart';
import '../guide.dart';
import '../shell.dart';
import 'sign_in.dart';

void _enter(BuildContext context) {
  GuideStore.pendingTour = true; // the welcome tour shows once, on the first visit
  Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const Shell()), (r) => false);
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const points = [
      'Nothing for your customer to install',
      'You approve every video before anyone sees it',
      'Opt-outs respected everywhere, for good',
    ];
    const words = ['Your', 'happiest', 'customer', 'is', 'your', 'best', 'salesperson.'];
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: LiquidBackdrop()),
        SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(24, 12, 24, 40), children: [
            Row(children: [
              const Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      BrandMark(size: 44),
                      SizedBox(width: 8),
                      Text('ViewRec', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
                child: Text('Sign in', style: TextStyle(fontWeight: FontWeight.w800, color: C.primary)),
              ),
              IntrinsicWidth(child: AppButton('Get started', small: true, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StartTrialScreen())))),
            ]).reveal(context, 0),
            const SizedBox(height: 30),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: C.primary.withValues(alpha: 0.25))),
                child: Text('Video testimonials you can stand behind', style: TextStyle(color: C.accentText, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ).reveal(context, 1),
            const SizedBox(height: 18),
            Wrap(spacing: 9, runSpacing: 0, children: [
              for (var i = 0; i < words.length; i++)
                Text(words[i], style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.6, height: 1.12, color: i >= 4 ? C.primary : C.text))
                    .reveal(context, 2 + i, 0.25),
            ]),
            const SizedBox(height: 16),
            const Muted('They already told their friends. ViewRec gets them saying it on camera - two minutes, from their own phone, with the words on screen.', size: 15.5)
                .reveal(context, 9),
            const SizedBox(height: 28),
            const _PhoneMock().reveal(context, 10, 0.12),
            const SizedBox(height: 28),
            for (var i = 0; i < points.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(color: C.green.withValues(alpha: 0.16), shape: BoxShape.circle),
                    child: Icon(PIconsBold.check, size: 14, color: C.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(points[i], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
                ]).reveal(context, 11 + i, 0.15),
              ),
            const SizedBox(height: 18),
            AppButton('Get started for \$1', icon: PIconsBold.arrowRight, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StartTrialScreen()))).reveal(context, 14),
            const SizedBox(height: 12),
            AppButton('Sign in', style: BtnStyle.ghost, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen()))).reveal(context, 15),
          ]),
        ),
      ]),
    );
  }
}

class StartTrialScreen extends StatefulWidget {
  final int initialStep;
  const StartTrialScreen({super.key, this.initialStep = 0});
  @override
  State<StartTrialScreen> createState() => _StartTrialScreenState();
}

class _StartTrialScreenState extends State<StartTrialScreen> {
  late int step = widget.initialStep;
  int category = 0;
  static const cats = [
    'Home & Trades', 'Health & Medical', 'Beauty & Wellness', 'Food & Restaurants', 'Education & Training',
    'IT & Software', 'Marketing & Design', 'Finance & Legal', 'Property & Real Estate', 'Automotive',
    'Travel & Events', 'Retail & E-commerce', 'Construction', 'Logistics & Transport', 'Professional Services',
  ];

  @override
  Widget build(BuildContext context) => SubPage('Start for \$1', children: [
        Row(children: [
          for (var i = 0; i < 3; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                decoration: BoxDecoration(color: i <= step ? C.primary : C.surface2, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ]),
        const SizedBox(height: 24),
        if (step == 0) ...[
          const H1('Tell us about your business', size: 26),
          const SizedBox(height: 16),
          const Field('Business name', hint: 'Hartley Roofing'),
          const Field('Your name', hint: 'Jordan Hartley'),
          const Field('Email', keyboard: TextInputType.emailAddress),
          Text('Industry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: C.muted)),
          const SizedBox(height: 8),
          Wrap(runSpacing: 8, children: [
            for (var i = 0; i < cats.length; i++) AppChip(cats[i], active: category == i, onTap: () => setState(() => category = i)),
          ]),
          const SizedBox(height: 20),
          AppButton('Continue', onTap: () => setState(() => step = 1)),
        ],
        if (step == 1) ...[
          const H1('Where should we call you?', size: 26),
          const SizedBox(height: 8),
          const Muted('An activation agent calls to switch your account on. No card is needed today.'),
          const SizedBox(height: 16),
          const Field('Mobile number', hint: '+44 7700 900123', keyboard: TextInputType.phone),
          const Field('Best time to call', hint: 'Weekday mornings'),
          const InfoBanner('\$1 starts your first 15 days of full Pro. After that it is \$49 / month on Standard.'),
          const SizedBox(height: 20),
          AppButton('Continue', onTap: () => setState(() => step = 2)),
        ],
        if (step == 2) ...[
          const SizedBox(height: 24),
          Center(child: CircleAvatar(radius: 38, backgroundColor: C.green, child: Icon(Icons.check_rounded, size: 38, color: Colors.white))),
          const SizedBox(height: 20),
          const Center(child: H1('You are all set', size: 26)),
          const SizedBox(height: 10),
          const Muted('Someone from our team will call and switch your account on. Meanwhile, take a look around.', align: TextAlign.center),
          const SizedBox(height: 24),
          AppButton('Open my dashboard', icon: Icons.arrow_forward_rounded, onTap: () => _enter(context)),
        ],
      ]);
}

/// A phone mock that floats gently while its teleprompter highlights each line in turn,
/// the REC timer ticks and the record button pulses.
class _PhoneMock extends StatefulWidget {
  const _PhoneMock();
  @override
  State<_PhoneMock> createState() => _PhoneMockState();
}

class _PhoneMockState extends State<_PhoneMock> with TickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..repeat(reverse: true);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  Timer? _timer;
  int _line = 0;
  int _secs = 14;

  static const _lines = ['They turned up when they said they would,', 'cleaned up after themselves,', 'and the roof has been perfect since.'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (!mounted) return;
      setState(() {
        _line = (_line + 1) % _lines.length;
        _secs += 2;
        if (_secs > 119) _secs = 14;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _float.dispose();
    _pulse.dispose();
    super.dispose();
  }

  String get _clock => '00:${_secs.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5).toDouble();
    return AnimatedBuilder(
      animation: _float,
      builder: (context, child) => Transform.translate(offset: Offset(0, -6 + 12 * Curves.easeInOut.transform(_float.value)), child: child),
      child: DefaultTextStyle.merge(
        style: const TextStyle(color: Colors.white),
        child: Container(
          height: 392 * scale,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF211A3D), Color(0xFF0E0B1C)]),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: const Color(0xFF2B2548), width: 6),
            boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.35), blurRadius: 50, offset: const Offset(0, 24))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) => Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: C.rec, shape: BoxShape.circle, boxShadow: [BoxShadow(color: C.rec.withValues(alpha: 0.7 * (1 - _pulse.value)), blurRadius: 10, spreadRadius: 6 * _pulse.value)]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('REC  $_clock', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.3)),
                ]),
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('JUST READ THIS', style: TextStyle(fontSize: 11, letterSpacing: 1.6, fontWeight: FontWeight.w800, color: Color(0xFF8A9BB8))),
                const SizedBox(height: 10),
                for (var i = 0; i < _lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      style: TextStyle(fontFamily: 'PlusJakartaSans', fontSize: i == _line ? 17 : 15, height: 1.35, fontWeight: i == _line ? FontWeight.w800 : FontWeight.w500, color: i == _line ? Colors.white : Colors.white.withValues(alpha: 0.38)),
                      child: Text(_lines[i]),
                    ),
                  ),
              ]),
            ),
            AnimatedBuilder(
              animation: _pulse,
              builder: (context, _) => SizedBox(
                width: 76,
                height: 76,
                child: Stack(alignment: Alignment.center, children: [
                  Container(
                    width: 66 + 14 * _pulse.value,
                    height: 66 + 14 * _pulse.value,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.5 * (1 - _pulse.value)), width: 2)),
                  ),
                  Container(width: 64, height: 64, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)), child: const Center(child: CircleAvatar(radius: 23, backgroundColor: C.rec))),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
