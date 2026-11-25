import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:video_player/video_player.dart';
import '../liquid_widgets.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';
import 'media_create.dart';

enum CaptionPos { top, middle, bottom }

class _Logo {
  final String path;
  double x, y, size; // centre as a fraction of the picture, width as a fraction of the picture width
  _Logo(this.path, {this.x = 0.85, this.y = 0.08, this.size = 0.2});
}

const _captionColors = [Color(0xFFFFFFFF), Color(0xFFFFD65A), Color(0xFF3DE0BC), Color(0xFF0B1B3A)];

String _clock(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Record or pick a video, write a script with AI, make captions from the speech, edit them,
/// place the captions and logos, then carry on to post it.
class CaptionStudioScreen extends StatefulWidget {
  const CaptionStudioScreen({super.key});
  @override
  State<CaptionStudioScreen> createState() => _CaptionStudioScreenState();
}

class _CaptionStudioScreenState extends State<CaptionStudioScreen> {
  final _picker = ImagePicker();
  final _topic = TextEditingController();
  final _script = TextEditingController();
  String tone = 'friendly';
  bool writing = false, transcribing = false, exporting = false;
  double progress = 0;

  XFile? video;
  VideoPlayerController? ctrl;
  int durMs = 0;

  List<CaptionLine> lines = [];
  int? activeLine;
  CaptionPos pos = CaptionPos.bottom;
  double sizeF = 0.045;
  int colorIdx = 0;
  bool pill = true;

  final logos = <_Logo>[];
  int? selLogo;
  String business = '';

  @override
  void initState() {
    super.initState();
    repo.profile().then((p) {
      if (mounted) business = p.name;
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _topic.dispose();
    _script.dispose();
    ctrl?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- video
  Future<void> _load(XFile f) async {
    final old = ctrl;
    final c = kIsWeb ? VideoPlayerController.networkUrl(Uri.parse(f.path)) : VideoPlayerController.file(File(f.path));
    try {
      await c.initialize();
    } catch (e) {
      await c.dispose();
      if (mounted) showMsg(context, 'That video could not be opened.');
      return;
    }
    await c.setLooping(true);
    if (!mounted) {
      await c.dispose();
      return;
    }
    setState(() {
      video = f;
      ctrl = c;
      durMs = c.value.duration.inMilliseconds;
      lines = [];
      activeLine = null;
      tab = 2;
    });
    await old?.dispose();
  }

  Future<void> _record() async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.camera, maxDuration: const Duration(minutes: 3));
      if (f != null) await _load(f);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open the camera: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _choose() async {
    try {
      final f = await _picker.pickVideo(source: ImageSource.gallery);
      if (f != null) await _load(f);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open that: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _togglePlay() {
    final c = ctrl;
    if (c == null) return;
    setState(() {
      activeLine = null;
      c.value.isPlaying ? c.pause() : c.play();
    });
  }

  // ---------------------------------------------------------------- script
  Future<void> _writeScript() async {
    if (_topic.text.trim().isEmpty) {
      showMsg(context, 'Say what the video is about first');
      return;
    }
    setState(() => writing = true);
    try {
      final s = await webRepo.writeScript(topic: _topic.text.trim(), tone: tone, business: business);
      if (mounted) setState(() => _script.text = s);
    } catch (e) {
      if (mounted) showMsg(context, "Couldn't write the script. Try again.");
    } finally {
      if (mounted) setState(() => writing = false);
    }
  }

  void _readThrough() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        backgroundColor: const Color(0xFF05070D),
        child: SafeArea(
          child: Column(children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 40, 26, 20),
                child: Text(_script.text, style: const TextStyle(color: Colors.white, fontSize: 28, height: 1.5, fontWeight: FontWeight.w700)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                Expanded(child: AppButton('Close', style: BtnStyle.ghost, onTap: () => Navigator.pop(ctx))),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton('Open camera', icon: Icons.videocam_rounded, onTap: () {
                    Navigator.pop(ctx);
                    _record();
                  }),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- captions
  Future<void> _makeCaptions() async {
    final v = video;
    if (v == null) {
      showMsg(context, 'Record or choose a video first');
      return;
    }
    setState(() => transcribing = true);
    try {
      final l = await webRepo.transcribeVideo(v.path, durationMs: durMs, script: _script.text);
      if (mounted) {
        setState(() {
          lines = l;
          activeLine = null;
        });
        showSuccess(context, 'Captions ready. Read them and fix anything that is wrong.');
      }
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => transcribing = false);
    }
  }

  void _addLine() {
    final last = lines.isEmpty ? 0 : lines.last.endMs;
    final end = (last + 3000).clamp(0, durMs <= 0 ? last + 3000 : durMs);
    setState(() {
      lines.add(CaptionLine(startMs: last, endMs: end <= last ? last + 1500 : end, text: ''));
      activeLine = lines.length - 1;
    });
  }

  void _editTimes(CaptionLine l) {
    final max = (durMs <= 0 ? 60000 : durMs).toDouble();
    showSheet(
      context,
      StatefulBuilder(
        builder: (ctx, set) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const H2('When it shows'),
          const SizedBox(height: 10),
          Text('Starts at ${_clock(l.startMs)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: l.startMs.toDouble().clamp(0, max),
            max: max,
            activeColor: C.primary,
            onChanged: (v) {
              set(() => l.startMs = v.round());
              if (l.endMs <= l.startMs) l.endMs = (l.startMs + 500).clamp(0, max.round());
              setState(() {});
            },
          ),
          Text('Ends at ${_clock(l.endMs)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Slider(
            value: l.endMs.toDouble().clamp(0, max),
            max: max,
            activeColor: C.primary,
            onChanged: (v) {
              set(() => l.endMs = v.round().clamp(l.startMs + 300, max.round()));
              setState(() {});
            },
          ),
          AppButton('Done', onTap: () => Navigator.pop(ctx)),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------- logos
  Future<void> _addLogos() async {
    try {
      final files = await _picker.pickMultiImage(imageQuality: 95);
      if (files.isEmpty) return;
      setState(() {
        for (final f in files) {
          // Each new logo starts in a free corner so they do not sit on top of each other.
          final n = logos.length;
          final spots = [const Offset(0.85, 0.08), const Offset(0.15, 0.08), const Offset(0.85, 0.92), const Offset(0.15, 0.92), const Offset(0.5, 0.08)];
          final s = spots[n % spots.length];
          logos.add(_Logo(f.path, x: s.dx, y: s.dy));
        }
        selLogo = logos.length - 1;
      });
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open that: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // ---------------------------------------------------------------- picture (preview and export share the maths)
  double get _capY => switch (pos) { CaptionPos.top => 0.14, CaptionPos.middle => 0.5, CaptionPos.bottom => 0.82 };

  Future<ui.Image> _decode(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    return (await codec.getNextFrame()).image;
  }

  void _paintCaption(Canvas canvas, int w, int h, String text) {
    final color = _captionColors[colorIdx];
    final onDark = colorIdx != 3;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: h * sizeF,
          fontWeight: FontWeight.w800,
          height: 1.2,
          color: color,
          shadows: pill ? null : [Shadow(blurRadius: h * 0.006, color: onDark ? Colors.black87 : Colors.white70)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: w * 0.84);
    final cx = w / 2, cy = h * _capY;
    if (pill) {
      final padX = h * 0.016, padY = h * 0.008;
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: tp.width + padX * 2, height: tp.height + padY * 2), Radius.circular(h * 0.014));
      canvas.drawRRect(r, Paint()..color = (onDark ? Colors.black : Colors.white).withValues(alpha: 0.55));
    }
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  Future<ui.Image> _frame(int w, int h, {String? caption, List<(ui.Image, _Logo)> logoImages = const []}) {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final (img, l) in logoImages) {
      final lw = w * l.size;
      final lh = lw * img.height / img.width;
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()), Rect.fromCenter(center: Offset(l.x * w, l.y * h), width: lw, height: lh), Paint()..filterQuality = FilterQuality.high);
    }
    if (caption != null && caption.trim().isNotEmpty) _paintCaption(canvas, w, h, caption.trim());
    return rec.endRecording().toImage(w, h);
  }

  Future<Uint8List> _png(ui.Image i) async => (await i.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();

  /// Burns the captions and logos into a new video file. Returns the original if there is nothing to add.
  Future<XFile?> _render() async {
    final v = video;
    final c = ctrl;
    if (v == null || c == null) return null;
    final spoken = lines.where((l) => l.text.trim().isNotEmpty).toList();
    if (spoken.isEmpty && logos.isEmpty) return v;
    final file = pve.EditorVideo.file(File(v.path));
    final meta = await pve.ProVideoEditor.instance.getMetadata(file);
    var w = meta.resolution.width.round(), h = meta.resolution.height.round();
    final portrait = c.value.size.height > c.value.size.width;
    if ((h > w) != portrait) {
      final t = w;
      w = h;
      h = t;
    }
    final dur = meta.duration;
    final layers = <pve.ImageLayer>[];
    final logoImages = <(ui.Image, _Logo)>[for (final l in logos) (await _decode(l.path), l)];
    if (logoImages.isNotEmpty) {
      layers.add(pve.ImageLayer(image: pve.EditorLayerImage.memory(await _png(await _frame(w, h, logoImages: logoImages)))));
    }
    for (final l in spoken) {
      final img = await _frame(w, h, caption: l.text);
      layers.add(pve.ImageLayer(
        image: pve.EditorLayerImage.memory(await _png(img)),
        startTime: Duration(milliseconds: l.startMs),
        endTime: Duration(milliseconds: l.endMs.clamp(l.startMs + 100, dur.inMilliseconds)),
      ));
    }
    final data = pve.VideoRenderData(
      videoSegments: [pve.VideoSegment(video: file, startTime: Duration.zero, endTime: dur)],
      imageLayers: layers,
      enableAudio: true,
    );
    final sub = pve.ProVideoEditor.instance.progressStreamById(data.id).listen((p) {
      if (mounted) setState(() => progress = p.progress.toDouble().clamp(0.0, 1.0));
    });
    try {
      final out = '${Directory.systemTemp.path}/viewrec_captioned_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = await pve.ProVideoEditor.instance.renderVideoToFile(out, data);
      return XFile(path);
    } finally {
      await sub.cancel();
    }
  }

  Future<void> _continue() async {
    if (video == null) {
      showMsg(context, 'Record or choose a video first');
      return;
    }
    ctrl?.pause();
    setState(() {
      exporting = true;
      progress = 0;
    });
    try {
      final out = await _render();
      if (!mounted || out == null) return;
      setState(() => exporting = false);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComposeScreen(kind: 'post', initialVideo: out)));
    } catch (e) {
      if (!mounted) return;
      setState(() => exporting = false);
      showMsg(context, 'Could not add the captions: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // ---------------------------------------------------------------- preview widget
  Widget _preview() {
    final c = ctrl;
    if (c == null || !c.value.isInitialized) {
      return AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF243B6B), Color(0xFF0B1B3A)]),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.videocam_rounded, size: 46, color: Colors.white54),
            const SizedBox(height: 10),
            const Text('Your video shows here', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ]),
        ),
      );
    }
    final vs = c.value.size;
    return AspectRatio(
      aspectRatio: vs.width / vs.height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: GestureDetector(
          onTap: _togglePlay,
          child: LayoutBuilder(
            builder: (_, box) {
              final w = box.maxWidth, h = box.maxHeight;
              return Stack(fit: StackFit.expand, children: [
                VideoPlayer(c),
                for (var i = 0; i < logos.length; i++)
                  Positioned(
                    left: logos[i].x * w - w * logos[i].size / 2,
                    top: logos[i].y * h - w * logos[i].size / 2,
                    width: w * logos[i].size,
                    height: w * logos[i].size,
                    child: GestureDetector(
                      onTap: () => setState(() => selLogo = i),
                      onPanUpdate: (d) => setState(() {
                        selLogo = i;
                        logos[i].x = (logos[i].x + d.delta.dx / w).clamp(0.05, 0.95);
                        logos[i].y = (logos[i].y + d.delta.dy / h).clamp(0.04, 0.96);
                      }),
                      child: DecoratedBox(
                        decoration: BoxDecoration(border: selLogo == i ? Border.all(color: Colors.white70, width: 1.5) : null),
                        child: Image.file(File(logos[i].path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                      ),
                    ),
                  ),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, val, __) {
                    final now = val.position.inMilliseconds;
                    CaptionLine? line;
                    if (activeLine != null && activeLine! < lines.length && !val.isPlaying) {
                      line = lines[activeLine!];
                    } else {
                      for (final l in lines) {
                        if (now >= l.startMs && now < l.endMs) line = l;
                      }
                      line ??= lines.isEmpty || val.isPlaying ? null : lines.first;
                    }
                    final text = (line?.text ?? '').trim();
                    if (text.isEmpty) return const SizedBox();
                    final color = _captionColors[colorIdx];
                    return Align(
                      alignment: Alignment(0, _capY * 2 - 1),
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: w * 0.08),
                        padding: pill ? EdgeInsets.symmetric(horizontal: h * 0.016, vertical: h * 0.008) : EdgeInsets.zero,
                        decoration: pill ? BoxDecoration(color: (colorIdx == 3 ? Colors.white : Colors.black).withValues(alpha: 0.55), borderRadius: BorderRadius.circular(h * 0.014)) : null,
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: h * sizeF, height: 1.2, fontWeight: FontWeight.w800, color: color, shadows: pill ? null : [Shadow(blurRadius: h * 0.006, color: colorIdx == 3 ? Colors.white70 : Colors.black87)]),
                        ),
                      ),
                    );
                  },
                ),
                ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, val, __) => val.isPlaying ? const SizedBox() : const Center(child: Icon(Icons.play_circle_fill_rounded, size: 62, color: Colors.white70)),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- sections
  Widget _step(int n, String title, Widget child, {String? hint}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.5)),
        if (hint != null) ...[const SizedBox(height: 4), Muted(hint, size: 12.5)],
        const SizedBox(height: 14),
        child,
        const SizedBox(height: 24),
      ]);

  Widget _seg<T>(List<(T, String)> items, T value, ValueChanged<T> onChanged) => Wrap(children: [
        for (final (v, label) in items) AppChip(label, active: v == value, onTap: () => onChanged(v)),
      ]);

  Widget _scriptStep() => _step(
        1,
        'Script (optional)',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Field('What is the video about?', controller: _topic, hint: 'Free roof inspections this month'),
          _seg<String>(const [('friendly', 'Friendly'), ('professional', 'Professional'), ('punchy', 'Short and punchy')], tone, (v) => setState(() => tone = v)),
          const SizedBox(height: 10),
          AppButton(writing ? 'Writing…' : 'Write script with AI', icon: Icons.auto_awesome_rounded, small: true, loading: writing, onTap: writing ? null : _writeScript),
          const SizedBox(height: 14),
          Field('Your script', controller: _script, lines: 6, hint: 'Write your own, or let AI write it and change it here.', onChanged: (_) => setState(() {})),
          if (_script.text.trim().isNotEmpty) AppButton('Read it while recording', icon: Icons.menu_book_rounded, small: true, style: BtnStyle.ghost, onTap: _readThrough),
        ]),
      );

  Widget _videoStep() => _step(
        2,
        'Your video',
        Row(children: [
          Expanded(child: AppButton('Record', icon: Icons.videocam_rounded, small: true, onTap: _record)),
          const SizedBox(width: 8),
          Expanded(child: AppButton('Choose video', icon: Icons.video_library_rounded, small: true, style: BtnStyle.ghost, onTap: _choose)),
        ]),
        hint: video == null ? 'Record a new one or pick one from your phone.' : 'Video ready, ${_clock(durMs)} long. Tap the picture above to play it.',
      );

  Widget _captionsStep() => _step(
        3,
        'Captions',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppButton(
            transcribing ? 'Listening to your video…' : (lines.isEmpty ? 'Make captions from my speech' : 'Make them again'),
            icon: Icons.closed_caption_rounded,
            small: true,
            loading: transcribing,
            style: lines.isEmpty ? BtnStyle.primary : BtnStyle.ghost,
            onTap: transcribing ? null : _makeCaptions,
          ),
          if (lines.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Muted('Check each line. Tap a line to edit the words, or the time to change when it shows.', size: 12.5),
            const SizedBox(height: 10),
            for (var i = 0; i < lines.length; i++) _LineEditor(
              key: ObjectKey(lines[i]),
              line: lines[i],
              active: activeLine == i,
              onFocus: () => setState(() => activeLine = i),
              onChanged: () => setState(() {}),
              onTime: () => _editTimes(lines[i]),
              onDelete: () => setState(() {
                lines.removeAt(i);
                activeLine = null;
              }),
            ),
            AppButton('Add a line', icon: Icons.add_rounded, small: true, style: BtnStyle.ghost, onTap: _addLine),
          ],
        ]),
        hint: 'ViewRec listens to the video and writes what was said.',
      );

  Widget _layoutStep() => _step(
        4,
        'Where the captions go',
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _seg<CaptionPos>(const [(CaptionPos.top, 'Top'), (CaptionPos.middle, 'Middle'), (CaptionPos.bottom, 'Bottom')], pos, (v) => setState(() => pos = v)),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Size', style: TextStyle(fontWeight: FontWeight.w700)),
            Expanded(child: Slider(value: sizeF, min: 0.028, max: 0.07, activeColor: C.primary, onChanged: (v) => setState(() => sizeF = v))),
          ]),
          Row(children: [
            const Text('Colour', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 14),
            for (var i = 0; i < _captionColors.length; i++)
              GestureDetector(
                onTap: () => setState(() => colorIdx = i),
                child: Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: _captionColors[i], shape: BoxShape.circle, border: Border.all(color: colorIdx == i ? C.primary : C.border, width: colorIdx == i ? 3 : 1)),
                ),
              ),
          ]),
          SwitchTile('Dark box behind the words', pill, (v) => setState(() => pill = v)),
        ]),
      );

  Widget _logoStep() {
    final sel = selLogo != null && selLogo! < logos.length ? logos[selLogo!] : null;
    return _step(
      5,
      'Logos',
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AppButton('Import logo', icon: Icons.add_photo_alternate_rounded, small: true, style: BtnStyle.ghost, onTap: _addLogos),
        if (logos.isNotEmpty) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: logos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => Pressable(
                onTap: () => setState(() => selLogo = i),
                child: Container(
                  width: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: selLogo == i ? C.primary : C.border, width: selLogo == i ? 2 : 1)),
                  child: Image.file(File(logos[i].path), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.image_rounded)),
                ),
              ),
            ),
          ),
        ],
        if (sel != null) ...[
          const SizedBox(height: 14),
          const Text('Position', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            SizedBox(
              width: 120,
              child: Column(children: [
                for (final y in const [0.08, 0.5, 0.92])
                  Row(children: [
                    for (final x in const [0.15, 0.5, 0.85])
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            sel.x = x;
                            sel.y = y;
                          }),
                          child: Container(
                            height: 30,
                            margin: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: (sel.x - x).abs() < 0.08 && (sel.y - y).abs() < 0.08 ? C.primary : C.surface2,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(color: C.border),
                            ),
                          ),
                        ),
                      ),
                  ]),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(child: Muted('Or drag the logo on the picture above to put it exactly where you want.', size: 12.5)),
          ]),
          Row(children: [
            const Text('Size', style: TextStyle(fontWeight: FontWeight.w700)),
            Expanded(child: Slider(value: sel.size, min: 0.08, max: 0.5, activeColor: C.primary, onChanged: (v) => setState(() => sel.size = v))),
          ]),
          AppButton('Remove this logo', icon: Icons.delete_outline_rounded, small: true, style: BtnStyle.danger, onTap: () => setState(() {
                logos.remove(sel);
                selLogo = null;
              })),
        ],
      ]),
      hint: 'Add as many logos as you like. Each one can sit in its own place.',
    );
  }

  int tab = 0;
  static const _tabs = [
    (Icons.edit_note_rounded, 'Script'),
    (Icons.videocam_rounded, 'Video'),
    (Icons.closed_caption_rounded, 'Captions'),
    (Icons.text_fields_rounded, 'Style'),
    (Icons.image_rounded, 'Logos'),
  ];

  Widget _tabBar() => Row(children: [
        for (var i = 0; i < _tabs.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => setState(() => tab = i),
              child: AnimatedContainer(
                duration: kMed,
                curve: kCurve,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: tab == i ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(children: [
                  Icon(_tabs[i].$1, size: 21, color: tab == i ? Colors.white : C.muted),
                  const SizedBox(height: 2),
                  Text(_tabs[i].$2, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: tab == i ? Colors.white : C.muted)),
                ]),
              ),
            ),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final panels = [_scriptStep(), _videoStep(), _captionsStep(), _layoutStep(), _logoStep()];
    return Scaffold(
      body: Stack(children: [
        const Positioned.fill(child: LiquidBackdrop()),
        SafeArea(
          child: Column(children: [
            const Padding(padding: EdgeInsets.fromLTRB(16, 4, 16, 0), child: BackHeader('Record a video')),
            const SizedBox(height: 4),
            SizedBox(height: h * 0.34, child: Center(child: _preview())),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: C.dark ? C.surface : Colors.white.withValues(alpha: 0.88),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
                  border: Border.all(color: C.dark ? C.border : Colors.white),
                  boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.14), blurRadius: 30, offset: const Offset(0, -8))],
                ),
                child: Column(children: [
                  Padding(padding: const EdgeInsets.fromLTRB(12, 14, 12, 6), child: _tabBar()),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: kFast,
                      child: SingleChildScrollView(
                        key: ValueKey(tab),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                        child: panels[tab],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                    child: Row(children: [
                      if (tab > 0) ...[
                        Expanded(child: AppButton('Back', style: BtnStyle.ghost, small: true, onTap: () => setState(() => tab--))),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: tab < _tabs.length - 1
                            ? AppButton('Next', icon: Icons.arrow_forward_rounded, small: true, onTap: () => setState(() => tab++))
                            : AppButton('Continue to post', icon: Icons.check_rounded, small: true, onTap: video == null ? null : _continue),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
        if (exporting)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: AppCard(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Adding captions and logos…', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 14),
                  SizedBox(width: 220, child: LinearProgressIndicator(value: progress <= 0 ? null : progress, color: C.primary, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 10),
                  Muted(progress <= 0 ? 'Getting ready' : '${(progress * 100).round()}%', size: 12.5),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

class _LineEditor extends StatefulWidget {
  final CaptionLine line;
  final bool active;
  final VoidCallback onFocus, onChanged, onTime, onDelete;
  const _LineEditor({super.key, required this.line, required this.active, required this.onFocus, required this.onChanged, required this.onTime, required this.onDelete});
  @override
  State<_LineEditor> createState() => _LineEditorState();
}

class _LineEditorState extends State<_LineEditor> {
  late final c = TextEditingController(text: widget.line.text);
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: C.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: widget.active ? C.primary : C.border, width: widget.active ? 1.6 : 1),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Pressable(
              onTap: widget.onTime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.schedule_rounded, size: 13, color: C.primary),
                  const SizedBox(width: 5),
                  Text('${_clock(widget.line.startMs)} - ${_clock(widget.line.endMs)}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: C.primary)),
                ]),
              ),
            ),
            const Spacer(),
            IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.delete_outline_rounded, size: 20, color: C.muted), onPressed: widget.onDelete),
          ]),
          TextField(
            controller: c,
            maxLines: null,
            onTap: widget.onFocus,
            onChanged: (v) {
              widget.line.text = v;
              widget.onChanged();
            },
            style: const TextStyle(fontSize: 14.5, height: 1.35),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, hintText: 'What is said here', contentPadding: EdgeInsets.fromLTRB(0, 6, 8, 6)),
          ),
        ]),
      );
}
