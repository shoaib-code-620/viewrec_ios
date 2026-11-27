import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../media_data.dart';
import '../models.dart';
import '../motion.dart';
import '../repo.dart';
import '../shell.dart';
import '../theme.dart';
import 'media_profile.dart' show kMyBusinessId;
import 'media_viewers.dart';

/// The top of Home: three cards you swipe between.
/// 1. The camera, already open, with a welcome that types itself. 2. Your own reels. 3. The blue results card.
class HomeHero extends StatefulWidget {
  final ShellState shell;
  /// The blue results card.
  final Widget analytics;
  const HomeHero({super.key, required this.shell, required this.analytics});
  @override
  State<HomeHero> createState() => _HomeHeroState();
}

class _HomeHeroState extends State<HomeHero> with WidgetsBindingObserver, TickerProviderStateMixin {
  final controller = PageController();
  int page = 0;
  BusinessProfile? profile;
  List<Reel> reels = [];
  bool reelsLoaded = false;

  // camera
  List<CameraDescription> cams = [];
  CameraController? cam;
  bool camBusy = false, camFailed = false, resumed = true, covered = false;
  int camGeneration = 0;
  AnimationStatusListener? _coverListener;
  Animation<double>? _coverAnim;

  // the welcome that types itself
  late final AnimationController typing = AnimationController(vsync: this);
  // which reel is on show, and when to move to the next
  late final AnimationController reelClock = AnimationController(vsync: this, duration: const Duration(seconds: 4));
  int reelIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    repo.profile().then((p) {
      if (mounted) setState(() => profile = p);
    }).catchError((_) {});
    repo.publicProfile(kMyBusinessId).then((p) {
      if (mounted) {
        setState(() {
          reels = p.posts;
          reelsLoaded = true;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => reelsLoaded = true);
    });
    reelClock.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && reels.length > 1) {
        setState(() => reelIndex = (reelIndex + 1) % reels.length);
        reelClock.forward(from: 0);
      }
    });
    // Starts the typing once the first frame is on screen, when the text settings can be read.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncPage();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When another screen opens on top of Home, the camera is switched off until it closes.
    final route = ModalRoute.of(context);
    final anim = route?.secondaryAnimation;
    if (anim != _coverAnim) {
      if (_coverAnim != null && _coverListener != null) _coverAnim!.removeStatusListener(_coverListener!);
      _coverAnim = anim;
      _coverListener = (s) {
        final now = s != AnimationStatus.dismissed;
        if (now != covered) {
          covered = now;
          _syncCamera();
        }
      };
      anim?.addStatusListener(_coverListener!);
    }
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    resumed = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_coverAnim != null && _coverListener != null) _coverAnim!.removeStatusListener(_coverListener!);
    camGeneration++;
    for (final t in _guards) {
      t.cancel();
    }
    cam?.dispose();
    typing.dispose();
    reelClock.dispose();
    controller.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------- pages
  void _syncPage() {
    if (page == 0) {
      _startTyping();
    } else {
      typing.stop();
    }
    if (page == 1 && reels.length > 1) {
      if (!reelClock.isAnimating) reelClock.forward(from: 0);
    } else {
      reelClock.stop();
    }
    _syncCamera();
  }

  void _onPage(int i) {
    setState(() => page = i);
    _syncPage();
  }

  // ------------------------------------------------------------- camera
  Future<void> _syncCamera() async {
    final want = page == 0 && resumed && !covered && mounted;
    if (want && cam == null && !camBusy && !camFailed) {
      await _openCamera();
    } else if (!want && cam != null) {
      final old = cam;
      camGeneration++;
      setState(() => cam = null);
      await old?.dispose();
    }
  }

  final _guards = <Timer>[];

  /// Gives up on [work] after [limit]. The timer is cancelled with the card, so nothing is left running behind it.
  Future<T> _within<T>(Future<T> work, Duration limit) {
    final done = Completer<T>();
    final timer = Timer(limit, () {
      if (!done.isCompleted) done.completeError(TimeoutException('The camera did not answer'));
    });
    _guards.add(timer);
    work.then((v) {
      if (!done.isCompleted) done.complete(v);
    }, onError: (Object e, StackTrace st) {
      if (!done.isCompleted) done.completeError(e, st);
    });
    return done.future.whenComplete(timer.cancel);
  }

  Future<void> _openCamera() async {
    final gen = ++camGeneration;
    setState(() {
      camBusy = true;
      camFailed = false;
    });
    CameraController? c;
    try {
      // A camera that never answers must not leave the card saying "Opening camera" for ever.
      if (cams.isEmpty) cams = await _within(availableCameras(), const Duration(seconds: 5));
      if (cams.isEmpty) throw CameraException('none', 'No camera');
      final cd = cams.firstWhere((x) => x.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
      c = CameraController(cd, ResolutionPreset.medium, enableAudio: false);
      await _within(c.initialize(), const Duration(seconds: 8));
      if (!mounted || gen != camGeneration) {
        await c.dispose();
        return;
      }
      setState(() {
        cam = c;
        camBusy = false;
      });
    } catch (_) {
      await c?.dispose();
      if (mounted && gen == camGeneration) {
        setState(() {
          camBusy = false;
          camFailed = true;
        });
      }
    }
  }

  void _retryCamera() {
    setState(() => camFailed = false);
    _syncCamera();
  }

  // ------------------------------------------------------------- the typed welcome
  /// The lines of the welcome. Each has its own font and size, so it reads like someone writing it by hand.
  List<(String, TextStyle)> _lines() {
    final p = profile;
    final owner = (p?.owner ?? '').trim();
    final first = owner.isEmpty ? '' : owner.split(' ').first;
    final biz = (p == null || p.name.isEmpty) ? 'your business' : p.name;
    const white = Colors.white;
    return [
      (first.isEmpty ? 'Hey there,' : 'Hey $first,', const TextStyle(fontFamily: 'Manrope', fontSize: 20, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500, color: Color(0xCCFFFFFF), height: 1.2)),
      ('\nwelcome to ', const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 27, fontWeight: FontWeight.w700, color: white, letterSpacing: -0.8, height: 1.15)),
      ('ViewRec', const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 31, fontWeight: FontWeight.w800, color: Color(0xFFFFC21A), letterSpacing: -1, height: 1.15)),
      ('\n$biz', const TextStyle(fontFamily: 'serif', fontSize: 21, fontStyle: FontStyle.italic, fontWeight: FontWeight.w600, color: Color(0xFF5BE8C6), height: 1.3)),
      ('\nThis is built to get you engagement:', const TextStyle(fontFamily: 'Manrope', fontSize: 13.5, fontWeight: FontWeight.w700, color: white, letterSpacing: 0.2, height: 1.4)),
      ('\nmore reviews, more reach, more customers.', const TextStyle(fontFamily: 'PlusJakartaSans', fontSize: 14.5, fontWeight: FontWeight.w500, color: Color(0xE6FFFFFF), height: 1.4)),
    ];
  }

  int get _total => _lines().fold(0, (a, l) => a + l.$1.length);

  void _startTyping() {
    final still = reduceMotion(context);
    typing.duration = Duration(milliseconds: still ? 1 : _total * 42);
    typing.forward(from: 0);
  }

  Widget _typed() => AnimatedBuilder(
        animation: typing,
        builder: (context, _) {
          final lines = _lines();
          final total = lines.fold(0, (a, l) => a + l.$1.length);
          var left = (typing.value * total).ceil();
          final spans = <InlineSpan>[];
          for (final l in lines) {
            if (left <= 0) break;
            final n = left < l.$1.length ? left : l.$1.length;
            spans.add(TextSpan(text: l.$1.substring(0, n), style: l.$2));
            left -= n;
          }
          final typingNow = typing.value < 1;
          // The cursor blinks while it types and then fades out.
          if (typingNow || (typing.lastElapsedDuration ?? Duration.zero).inMilliseconds % 1000 < 600) {
            spans.add(TextSpan(text: typingNow ? '▍' : '', style: const TextStyle(fontSize: 22, color: Color(0xFFFFC21A))));
          }
          return Text.rich(TextSpan(children: spans), key: const ValueKey('hero_typed'));
        },
      );

  // ------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.3);
    final height = 352 + 130 * (scale - 1);
    return Column(children: [
      SizedBox(
        height: height,
        child: PageView(
          key: const ValueKey('hero_pager'),
          controller: controller,
          onPageChanged: _onPage,
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _cameraCard()),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: _reelsCard()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: widget.analytics),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < 3; i++)
          Semantics(
            label: const ['Camera', 'Your reels', 'Results'][i],
            button: true,
            selected: page == i,
            child: GestureDetector(
              key: ValueKey('hero_dot_$i'),
              behavior: HitTestBehavior.opaque,
              onTap: () => controller.animateToPage(i, duration: kMed, curve: kCurve),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: AnimatedContainer(
                  duration: kMed,
                  curve: kCurve,
                  width: page == i ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(color: page == i ? C.primary : C.border, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            ),
          ),
      ]),
    ]);
  }

  Widget _cameraCard() {
    final c = cam;
    Widget preview;
    if (c != null && c.value.isInitialized && c.value.previewSize != null) {
      final s = c.value.previewSize!;
      preview = SizedBox.expand(
        child: FittedBox(fit: BoxFit.cover, clipBehavior: Clip.hardEdge, child: SizedBox(width: s.height, height: s.width, child: CameraPreview(c))),
      );
    } else {
      preview = const DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B1B3A), Color(0xFF0847A0)])),
        child: SizedBox.expand(),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: Stack(fit: StackFit.expand, children: [
        preview,
        // A soft dark layer so the writing can be read over any picture.
        const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x66000000), Color(0x99000000)]))),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(c != null ? Icons.videocam_rounded : Icons.videocam_off_rounded, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(c != null ? 'Camera is on' : (camBusy ? 'Opening camera…' : 'Camera is off'), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ]),
              ),
              const Spacer(),
              if (camFailed)
                GestureDetector(
                  key: const ValueKey('hero_camera_retry'),
                  onTap: _retryCamera,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                    child: const Text('Turn camera on', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0847A0))),
                  ),
                ),
            ]),
            const SizedBox(height: 14),
            Expanded(child: Align(alignment: Alignment.centerLeft, child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: _typed()))),
            Row(children: [
              Expanded(
                child: GestureDetector(
                  key: const ValueKey('hero_record'),
                  onTap: () => widget.shell.goTo(2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.fiber_manual_record_rounded, size: 16, color: Color(0xFFE4513F)),
                      SizedBox(width: 8),
                      Text('Make a video', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0B1B3A))),
                    ]),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _reelsCard() {
    final has = reels.isNotEmpty;
    final r = has ? reels[reelIndex % reels.length] : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: GestureDetector(
        key: const ValueKey('hero_reels'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!has) {
            widget.shell.goTo(kMediaIndex);
            return;
          }
          Navigator.of(context).push(PageRouteBuilder(opaque: false, pageBuilder: (_, __, ___) => ReelsViewer(reels: reels, startIndex: reelIndex % reels.length, onChanged: () {})));
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 600),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [r?.hue ?? const Color(0xFF0B5FC4), Color.lerp(r?.hue ?? const Color(0xFF0847A0), Colors.black, 0.6)!]),
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text('Your reels', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              const Spacer(),
              if (has) Text('${reels.length} ${reels.length == 1 ? 'post' : 'posts'}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 12.5)),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: !has
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(reelsLoaded ? Icons.movie_creation_outlined : Icons.hourglass_empty_rounded, size: 40, color: Colors.white70),
                        const SizedBox(height: 10),
                        Text(reelsLoaded ? 'Your reels show here' : 'Loading your reels…', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        const Text('Post a reel from Media and it plays here.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ]),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        key: ValueKey(r!.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          if (r.duration.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(8)),
                              child: Text(r.duration, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                          const SizedBox(height: 10),
                          Text(r.caption.split('#').first.trim(), maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.3)),
                          const SizedBox(height: 12),
                          Row(children: [
                            const Icon(Icons.favorite_rounded, size: 15, color: Colors.white),
                            const SizedBox(width: 5),
                            Text('${r.likes}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            const SizedBox(width: 14),
                            const Icon(Icons.chat_bubble_rounded, size: 14, color: Colors.white70),
                            const SizedBox(width: 5),
                            Text('${r.comments}', style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 13)),
                            const Spacer(),
                            const Text('Tap to watch', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, fontSize: 12)),
                            const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                          ]),
                        ],
                      ),
                    ),
            ),
            if (reels.length > 1) ...[
              const SizedBox(height: 12),
              Row(children: [
                for (var i = 0; i < reels.length && i < 8; i++)
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(color: i == reelIndex % reels.length ? Colors.white : Colors.white24, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}
