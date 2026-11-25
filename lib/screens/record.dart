import 'dart:async';
import 'dart:io' show File;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../liquid_widgets.dart';
import 'package:video_player/video_player.dart';
import '../data.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

/// The customer's side of the invitation: agree, rate, then share their
/// experience as a video, in writing, or with an avatar (camera-shy mode).
enum Stage { intro, rate, choose, write, avatar, camera, review, done }

const _maxSeconds = 120;
String _fmt(int s) => '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

class _Avatar {
  final String id, name;
  final IconData icon;
  final Color color;
  const _Avatar(this.id, this.name, this.icon, this.color);
}

const _avatars = [
  _Avatar('fox', 'Fox', Icons.pets_rounded, Color(0xFFFF8A3D)),
  _Avatar('owl', 'Owl', Icons.nightlight_round_rounded, Color(0xFF0B5FC4)),
  _Avatar('bear', 'Bear', Icons.emoji_nature_rounded, Color(0xFF8D6E63)),
  _Avatar('robot', 'Robot', Icons.smart_toy_rounded, Color(0xFF3E94F5)),
  _Avatar('star', 'Star', Icons.auto_awesome_rounded, Color(0xFFF2A100)),
  _Avatar('leaf', 'Leaf', Icons.eco_rounded, Color(0xFF0F9F78)),
];

class RecordScreen extends StatefulWidget {
  final Stage initialStage;
  const RecordScreen({super.key, this.initialStage = Stage.intro});
  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late Stage stage = widget.initialStage;
  Stage? cameFrom; // where "Back" goes from camera
  List<CameraDescription> cams = [];
  CameraController? cam;
  VideoPlayerController? player;
  bool recording = false;
  bool busy = false;
  int seconds = 0;
  Timer? timer;
  XFile? file;
  String? agreedAt;
  String? camError;
  int lensIndex = 0;

  int rating = 0;
  final tags = <String>{};
  String? avatarId;
  final written = TextEditingController();

  bool uploading = false;
  double progress = 0;
  String? uploadError;

  @override
  void dispose() {
    timer?.cancel();
    cam?.dispose();
    player?.dispose();
    written.dispose();
    super.dispose();
  }

  // ---------- camera ----------
  Future<void> _openCamera({CameraLensDirection prefer = CameraLensDirection.front}) async {
    setState(() {
      stage = Stage.camera;
      camError = null;
      busy = true;
    });
    try {
      if (cams.isEmpty) cams = await availableCameras();
      if (cams.isEmpty) throw CameraException('none', 'No camera found on this device.');
      final cd = cams.firstWhere((c) => c.lensDirection == prefer, orElse: () => cams.first);
      lensIndex = cams.indexOf(cd);
      await cam?.dispose();
      final c = CameraController(cd, ResolutionPreset.medium, enableAudio: true);
      cam = c;
      await c.initialize();
      if (!mounted) return;
      setState(() => busy = false);
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(() {
        busy = false;
        camError = switch (e.code) {
          'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' =>
            'Camera access was denied. Allow camera and microphone in your phone settings, then try again.',
          'AudioAccessDenied' || 'AudioAccessDeniedWithoutPrompt' || 'AudioAccessRestricted' =>
            'Microphone access was denied. Allow it in your phone settings, then try again.',
          _ => e.description ?? 'The camera could not be opened.',
        };
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          busy = false;
          camError = 'The camera could not be opened.';
        });
      }
    }
  }

  Future<void> _flip() async {
    if (cams.length < 2 || recording) return;
    final cur = cams[lensIndex].lensDirection;
    await _openCamera(prefer: cur == CameraLensDirection.front ? CameraLensDirection.back : CameraLensDirection.front);
  }

  Future<void> _start() async {
    final c = cam;
    if (c == null || !c.value.isInitialized || recording || busy) return;
    try {
      await c.startVideoRecording();
      seconds = 0;
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => seconds++);
        if (seconds >= _maxSeconds) _stop();
      });
      setState(() => recording = true);
    } on CameraException catch (e) {
      if (mounted) showMsg(context, e.description ?? 'Could not start recording.');
    }
  }

  int _lastLength = 0;

  Future<void> _stop() async {
    final c = cam;
    if (c == null || !recording) return;
    timer?.cancel();
    _lastLength = seconds;
    setState(() {
      recording = false;
      busy = true;
    });
    try {
      final f = await c.stopVideoRecording();
      file = f;
      final p = kIsWeb ? VideoPlayerController.networkUrl(Uri.parse(f.path)) : VideoPlayerController.file(File(f.path));
      await p.initialize();
      await p.setLooping(true);
      await p.play();
      await cam?.dispose();
      cam = null;
      if (!mounted) {
        p.dispose();
        return;
      }
      setState(() {
        player = p;
        stage = Stage.review;
        busy = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => busy = false);
        showMsg(context, 'Something went wrong while saving your video. Please record again.');
      }
    }
  }

  void _again() {
    player?.dispose();
    player = null;
    file = null;
    uploadError = null;
    seconds = 0;
    _openCamera();
  }

  Future<void> _sendVideo() async {
    final f = file;
    if (f == null || uploading) return;
    setState(() {
      uploading = true;
      uploadError = null;
      progress = 0;
    });
    try {
      await repo.uploadVideo(
        f,
        inviteToken: demoInviteToken,
        duration: _fmt(_lastLength),
        agreedAt: agreedAt ?? DateTime.now().toIso8601String(),
        rating: rating == 0 ? 5 : rating,
        avatar: avatarId,
        onProgress: (p) {
          if (mounted) setState(() => progress = p);
        },
      );
      player?.pause();
      if (mounted) setState(() => stage = Stage.done);
    } catch (e) {
      if (mounted) setState(() => uploadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _sendWritten() async {
    if (uploading) return;
    setState(() {
      uploading = true;
      uploadError = null;
    });
    try {
      await repo.submitWrittenTestimonial(
        inviteToken: demoInviteToken,
        rating: rating,
        text: written.text.trim(),
        agreedAt: agreedAt ?? DateTime.now().toIso8601String(),
      );
      if (mounted) setState(() => stage = Stage.done);
    } catch (e) {
      if (mounted) setState(() => uploadError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  void _close() {
    if (recording) _stop();
    Navigator.of(context).pop();
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) => switch (stage) {
        Stage.intro => _intro(),
        Stage.rate => _rate(),
        Stage.choose => _choose(),
        Stage.write => _write(),
        Stage.avatar => _avatarPick(),
        Stage.done => _done(),
        _ => _cameraOrReview(),
      };

  Widget _pageShell({required Widget body, Widget? bottom, Stage? back}) => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (back != null)
                  Material(
                    color: C.surface,
                    shape: CircleBorder(side: BorderSide(color: C.border)),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => stage = back),
                      child: const SizedBox(width: 40, height: 40, child: Icon(Icons.chevron_left_rounded, size: 22)),
                    ),
                  )
                else
                  const SizedBox(width: 40),
                Material(
                  color: C.surface,
                  shape: CircleBorder(side: BorderSide(color: C.border)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _close,
                    child: const SizedBox(width: 40, height: 40, child: Icon(Icons.close_rounded, size: 22)),
                  ),
                ),
              ]),
              Expanded(child: SingleChildScrollView(child: body)),
              if (bottom != null) bottom,
            ]),
          ),
        ),
      );

  // 1. consent
  Widget _intro() => _pageShell(
        body: Column(children: [
          const SizedBox(height: 24),
          const CircleAvatar(radius: 38, backgroundColor: C.rec, child: Icon(Icons.videocam_rounded, size: 34, color: Colors.white)),
          const SizedBox(height: 24),
          const Text('Hartley Roofing would love to hear how it went',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 12),
          const Muted("It takes two minutes. The words are on screen, so you don't have to think of what to say. No app, no account.", align: TextAlign.center),
          const SizedBox(height: 24),
          for (final p in const [
            'Share it as a video, in writing, or with an avatar',
            'The business approves it before anyone sees it',
            'You can stop and say never contact me again',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, size: 18, color: C.green),
                const SizedBox(width: 10),
                Expanded(child: Text(p, style: const TextStyle(fontSize: 14))),
              ]),
            ),
        ]),
        bottom: AppButton('I agree, continue', icon: Icons.arrow_forward_rounded, onTap: () {
          agreedAt = DateTime.now().toIso8601String();
          setState(() => stage = Stage.rate);
        }),
      );

  // 2. star rating
  Widget _rate() {
    const options = ['On time', 'Tidy', 'Fair price', 'Friendly', 'Great quality', 'Fast'];
    const labels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
    return _pageShell(
      back: Stage.intro,
      body: Column(children: [
        const SizedBox(height: 16),
        const Text('How was your experience?', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Muted('Tap a star to rate Hartley Roofing.', align: TextAlign.center),
        const SizedBox(height: 28),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var i = 1; i <= 5; i++)
            GestureDetector(
              onTap: () => setState(() => rating = i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: AnimatedScale(
                  scale: i == rating ? 1.22 : 1.0,
                  duration: kMed,
                  curve: Curves.easeOutBack,
                  child: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 52, color: i <= rating ? C.amber : C.muted),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        Text(labels[rating], style: TextStyle(color: C.primary, fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 28),
        const Align(alignment: Alignment.centerLeft, child: Text('What stood out?', style: TextStyle(fontWeight: FontWeight.w700))),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(runSpacing: 8, children: [
            for (final t in options)
              AppChip(t, active: tags.contains(t), onTap: () => setState(() => tags.contains(t) ? tags.remove(t) : tags.add(t))),
          ]),
        ),
      ]),
      bottom: AppButton('Continue', icon: Icons.arrow_forward_rounded, onTap: rating == 0 ? null : () => setState(() => stage = Stage.choose)),
    );
  }

  // 3. choose how to share
  Widget _choose() {
    Widget option(IconData icon, Color color, String title, String sub, VoidCallback onTap, {String? badge}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            onTap: onTap,
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                    if (badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: C.primarySoft, borderRadius: BorderRadius.circular(999)),
                        child: Text(badge, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: C.accentText)),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Muted(sub, size: 13),
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: C.muted),
            ]),
          ),
        );

    return _pageShell(
      back: Stage.rate,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        const Text('How would you like to share it?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Muted('Pick whatever feels easiest. All three reach the business the same way.'),
        const SizedBox(height: 22),
        option(Icons.videocam_rounded, C.rec, 'Record a video', 'About two minutes, with the words on screen', () {
          cameFrom = Stage.choose;
          avatarId = null;
          _openCamera();
        }, badge: 'Best'),
        option(Icons.edit_note_rounded, C.blue, 'Write it instead', 'Type a few lines, no camera needed', () => setState(() => stage = Stage.write)),
        option(Icons.face_retouching_natural_rounded, C.green, 'Use an avatar', 'Camera-shy? Pick an avatar to show instead of your face', () => setState(() => stage = Stage.avatar)),
      ]),
    );
  }

  // 4a. written testimonial
  Widget _write() {
    final len = written.text.trim().length;
    return _pageShell(
      back: Stage.choose,
      body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 16),
        const Text('Write a few lines', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
        const SizedBox(height: 8),
        const Muted('What was it like to work with Hartley Roofing?'),
        const SizedBox(height: 18),
        Field('Your testimonial', controller: written, lines: 6, hint: 'They turned up when they said they would…', onChanged: (_) => setState(() {})),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(len < 20 ? 'A little more, please (${20 - len} to go)' : 'Looks good', style: TextStyle(fontSize: 12.5, color: len < 20 ? C.muted : C.green)),
          Text('$len', style: TextStyle(fontSize: 12.5, color: C.muted)),
        ]),
        const SizedBox(height: 14),
        Text('Need a starting point?', style: TextStyle(color: C.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final line in script)
            ActionChip(
              label: Text(line, style: const TextStyle(fontSize: 12.5)),
              backgroundColor: C.surface,
              side: BorderSide(color: C.border),
              onPressed: () => setState(() => written.text = written.text.isEmpty ? line : '${written.text} $line'),
            ),
        ]),
        if (uploadError != null)
          Padding(padding: const EdgeInsets.only(top: 12), child: Text(uploadError!, style: TextStyle(color: C.rec, fontSize: 13))),
      ]),
      bottom: AppButton(uploading ? 'Sending…' : (uploadError != null ? 'Try again' : 'Send my testimonial'),
          icon: uploading ? null : Icons.send_rounded, onTap: (len < 20 || uploading) ? null : _sendWritten),
    );
  }

  // 4b. avatar picker
  Widget _avatarPick() => _pageShell(
        back: Stage.choose,
        body: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 16),
          const Text('Choose your avatar', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          const Muted('You still speak to the camera, but your video shows this avatar instead of your face. Your voice is kept.'),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              for (final a in _avatars)
                GestureDetector(
                  onTap: () => setState(() => avatarId = a.id),
                  child: Container(
                    decoration: BoxDecoration(
                      color: C.surface,
                      borderRadius: BorderRadius.circular(rLg),
                      border: Border.all(color: avatarId == a.id ? C.primary : C.border, width: avatarId == a.id ? 2.5 : 1),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CircleAvatar(radius: 28, backgroundColor: a.color.withValues(alpha: 0.18), child: Icon(a.icon, size: 28, color: a.color)),
                      const SizedBox(height: 8),
                      Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ]),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const InfoBanner('The avatar is added after you send. The business sees the same video, with your face replaced.', icon: Icons.info_outline_rounded),
        ]),
        bottom: AppButton('Continue to recording', icon: Icons.videocam_rounded, onTap: avatarId == null
            ? null
            : () {
                cameFrom = Stage.avatar;
                _openCamera();
              }),
      );

  Widget _done() => Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              CircleAvatar(radius: 38, backgroundColor: C.green, child: Icon(Icons.check_rounded, size: 38, color: Colors.white)),
              const SizedBox(height: 24),
              const Text('Thank you!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Stars(rating == 0 ? 5 : rating)]),
              const SizedBox(height: 12),
              const Muted('Your testimonial has been sent to Hartley Roofing. They will review it before it goes anywhere.', align: TextAlign.center),
              const SizedBox(height: 24),
              AppButton('Done', onTap: () => Navigator.of(context).pop()),
            ]),
          ),
        ),
      );

  // ---------- camera / review ----------
  Widget _preview() {
    if (stage == Stage.review) {
      final p = player;
      if (p == null || !p.value.isInitialized) return const ColoredBox(color: Colors.black);
      return SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(width: p.value.size.width, height: p.value.size.height, child: VideoPlayer(p)),
        ),
      );
    }
    final c = cam;
    if (camError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.no_photography_rounded, size: 40, color: C.muted),
            const SizedBox(height: 12),
            Muted(camError!, align: TextAlign.center),
            const SizedBox(height: 16),
            AppButton('Try again', style: BtnStyle.ghost, small: true, onTap: _openCamera),
            const SizedBox(height: 8),
            TextButton(onPressed: () => setState(() => stage = Stage.write), child: const Text('Write it instead')),
          ]),
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return Center(child: CircularProgressIndicator(color: C.primary));
    }
    final size = c.value.previewSize;
    if (size == null) return Center(child: CameraPreview(c));
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(width: size.height, height: size.width, child: CameraPreview(c)),
      ),
    );
  }

  Widget _cameraOrReview() => IconTheme(
        data: const IconThemeData(color: Colors.white),
        child: DefaultTextStyle.merge(style: const TextStyle(color: Colors.white), child: _cameraOrReviewBody()),
      );

  Widget _circleBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.black45,
        shape: const CircleBorder(),
        child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: SizedBox(width: 40, height: 40, child: Icon(icon, size: 22, color: Colors.white))),
      );

  Widget _cameraOrReviewBody() {
    final reviewing = stage == Stage.review;
    final line = (seconds ~/ 4).clamp(0, script.length - 1);
    final av = _avatars.where((a) => a.id == avatarId).firstOrNull;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: _preview()),
        Positioned.fill(child: IgnorePointer(child: Container(color: const Color(0x26000000)))),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  if (!recording && !reviewing) ...[_circleBtn(Icons.chevron_left_rounded, () {
                    cam?.dispose();
                    cam = null;
                    setState(() => stage = cameFrom ?? Stage.choose);
                  }), const SizedBox(width: 10)],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (recording) ...[const CircleAvatar(radius: 4.5, backgroundColor: C.rec), const SizedBox(width: 7)],
                      Text(reviewing ? 'PREVIEW' : recording ? 'REC  ${_fmt(seconds)}' : 'READY', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                  if (av != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        CircleAvatar(radius: 10, backgroundColor: av.color, child: Icon(av.icon, size: 12, color: Colors.white)),
                        const SizedBox(width: 6),
                        Text(av.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ]),
                Row(children: [
                  if (!reviewing && !recording && cams.length > 1) ...[_circleBtn(Icons.cameraswitch_rounded, _flip), const SizedBox(width: 10)],
                  _circleBtn(Icons.close_rounded, _close),
                ]),
              ]),
              const Spacer(),
              if (!reviewing)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(color: const Color(0xB80A0A12), borderRadius: BorderRadius.circular(rLg)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('JUST READ THIS', style: TextStyle(color: Color(0xFF8A9BB8), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (var i = 0; i < script.length; i++)
                      Text(script[i],
                          style: TextStyle(fontSize: 20, height: 1.5, fontWeight: FontWeight.w600, color: (i == line && recording) ? Colors.white : const Color(0x73FFFFFF))),
                  ]),
                ),
              if (reviewing) ...[
                if (uploadError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(uploadError!, textAlign: TextAlign.center, style: const TextStyle(color: C.rec, fontSize: 13)),
                  ),
                AppButton(uploading ? 'Sending… ${(progress * 100).round()}%' : (uploadError != null ? 'Try again' : 'Send my video'),
                    icon: uploading ? null : Icons.send_rounded, onTap: uploading ? null : _sendVideo),
                const SizedBox(height: 8),
                if (uploading)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LiquidProgress(value: progress, minHeight: 4, backgroundColor: Colors.white24, color: C.primary),
                  )
                else
                  AppButton('Record again', style: BtnStyle.ghost, onTap: _again),
              ] else
                GestureDetector(
                  onTap: (busy || camError != null) ? null : (recording ? _stop : _start),
                  child: Opacity(
                    opacity: (busy || camError != null) ? 0.4 : 1,
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 5)),
                      child: Center(
                        child: recording
                            ? Container(width: 30, height: 30, decoration: BoxDecoration(color: C.rec, borderRadius: BorderRadius.circular(8)))
                            : const CircleAvatar(radius: 28, backgroundColor: C.rec),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
