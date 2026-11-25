import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:video_player/video_player.dart';
import '../media_data.dart' show TextOverlay;
import '../motion.dart' show MusicBars;
import '../theme.dart';
import '../widgets.dart' show showMsg;
import 'edit_filters.dart';

/// Opens the video editor. Returns the finished video as a new file, or null if the user backed out.
Future<XFile?> editVideo(BuildContext context, XFile src) => Navigator.of(context).push<XFile>(MaterialPageRoute(fullscreenDialog: true, builder: (_) => VideoEditorScreen(source: src)));

const _bg = Color(0xFF0B0B12);
const _panel = Color(0xFF0E1B33);

/// One piece of video on the timeline.
class _Clip {
  final String path;
  final int durMs;
  int start, end; // trimmed part, in source milliseconds
  double speed, volume;
  bool reverse;
  List<Uint8List> thumbs;
  _Clip({required this.path, required this.durMs, int? start, int? end, this.speed = 1, this.volume = 1, this.reverse = false, this.thumbs = const []})
      : start = start ?? 0,
        end = end ?? durMs;
  int get outMs => ((end - start) / speed).round();
  _Clip copy() => _Clip(path: path, durMs: durMs, start: start, end: end, speed: speed, volume: volume, reverse: reverse, thumbs: thumbs);
}

/// A song or sound added under the video.
class _Music {
  final String path, name;
  final int durMs;
  double volume = 1;
  int startMs = 0, endMs;
  bool fadeIn = false, fadeOut = false, loop = true;
  _Music({required this.path, required this.name, required this.durMs}) : endMs = durMs;
}

String _t(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

const _aspects = <(String, double?)>[('Original', null), ('9:16', 9 / 16), ('1:1', 1), ('4:5', 4 / 5), ('16:9', 16 / 9)];
const _tools = <(String, IconData, String)>[
  ('trim', Icons.content_cut_rounded, 'Trim'),
  ('split', Icons.call_split_rounded, 'Split'),
  ('speed', Icons.speed_rounded, 'Speed'),
  ('volume', Icons.volume_up_rounded, 'Volume'),
  ('music', Icons.music_note_rounded, 'Music'),
  ('filter', Icons.auto_awesome_rounded, 'Filters'),
  ('adjust', Icons.tune_rounded, 'Adjust'),
  ('text', Icons.text_fields_rounded, 'Text'),
  ('crop', Icons.crop_rounded, 'Crop'),
  ('rotate', Icons.rotate_90_degrees_cw_rounded, 'Rotate'),
  ('flip', Icons.flip_rounded, 'Flip'),
  ('reverse', Icons.fast_rewind_rounded, 'Reverse'),
  ('delete', Icons.delete_outline_rounded, 'Delete'),
];

class VideoEditorScreen extends StatefulWidget {
  final XFile source;
  const VideoEditorScreen({super.key, required this.source});
  @override
  State<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends State<VideoEditorScreen> {
  final clips = <_Clip>[];
  int sel = 0;
  VideoPlayerController? ctrl;
  bool ready = false, playing = true, advancing = false;
  // Playhead in the selected clip, in source time. A notifier so only the time label rebuilds as it moves,
  // not the whole editor (rebuilding everything many times a second made the screen flicker).
  final pos = ValueNotifier<int>(0);
  int get posMs => pos.value;
  Timer? _poll;
  _Music? music;
  VideoPlayerController? mc; // plays the music in the preview
  String? _ctrlPath;
  int _token = 0;
  String? tool = 'trim';

  int filter = 0;
  final adjust = Adjust();
  int turns = 0;
  bool flipX = false;
  int aspect = 0;
  final texts = <TextOverlay>[];
  int selText = -1;
  Size resolution = const Size(1080, 1920);

  bool exporting = false;
  double progress = 0;
  String? taskId;

  _Clip get clip => clips[sel];
  double? get cropAspect => _aspects[aspect].$2;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      await _addClip(widget.source.path, first: true);
      if (!mounted) return;
      await _select(0);
    } catch (e) {
      if (!mounted) return;
      showMsg(context, 'Could not open this video: ${e.toString().replaceFirst('Exception: ', '')}');
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    ctrl?.dispose();
    mc?.dispose();
    pos.dispose();
    super.dispose();
  }

  Future<void> _addClip(String path, {bool first = false}) async {
    final video = pve.EditorVideo.file(File(path));
    final meta = await pve.ProVideoEditor.instance.getMetadata(video);
    final dur = meta.duration.inMilliseconds;
    if (dur <= 0) throw Exception('The video has no length');
    if (first) resolution = meta.resolution;
    var thumbs = <Uint8List>[];
    try {
      const n = 8;
      thumbs = await pve.ProVideoEditor.instance.getThumbnails(pve.ThumbnailConfigs(
        video: video,
        outputSize: const Size(110, 150),
        timestamps: [for (var i = 0; i < n; i++) Duration(milliseconds: (dur * (i + 0.5) / n).round())],
      ));
    } catch (_) {
      // No thumbnails: the clip is shown as a plain block.
    }
    clips.add(_Clip(path: path, durMs: dur, thumbs: thumbs));
  }

  /// Shows clip [i] in the preview without ever blanking the screen: the old picture stays up until the
  /// new player is ready, and clips cut from the same file (after a split) reuse the player and just jump.
  Future<void> _select(int i) async {
    final my = ++_token;
    final target = clips[i];
    final c0 = ctrl;
    if (c0 != null && c0.value.isInitialized && _ctrlPath == target.path) {
      sel = i;
      await _applyClipAudioSpeed();
      await c0.seekTo(Duration(milliseconds: target.start));
      if (!mounted || my != _token) return;
      pos.value = target.start;
      setState(() {});
      if (playing) c0.play();
      return;
    }
    final c = VideoPlayerController.file(File(target.path));
    try {
      await c.initialize();
    } catch (_) {
      await c.dispose();
      if (mounted) showMsg(context, 'Could not play this clip');
      return;
    }
    if (!mounted || my != _token) {
      await c.dispose();
      return;
    }
    await c.setLooping(false);
    final old = ctrl;
    ctrl = c;
    _ctrlPath = target.path;
    sel = i;
    await _applyClipAudioSpeed();
    await c.seekTo(Duration(milliseconds: target.start));
    if (!mounted) return;
    pos.value = target.start;
    setState(() => ready = true);
    if (playing) c.play();
    _poll ??= Timer.periodic(const Duration(milliseconds: 40), (_) => _pollTick());
    // Let the new frame reach the screen before the old player goes away.
    WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
  }

  Future<void> _applyClipAudioSpeed() async {
    final c = ctrl;
    if (c == null || !c.value.isInitialized) return;
    try {
      await c.setVolume(clip.volume.clamp(0.0, 1.0));
      await c.setPlaybackSpeed(clip.speed.clamp(0.25, 4.0));
    } catch (_) {}
  }

  /// Runs 25 times a second: moves the playhead and loops or advances at the end of the trimmed part.
  Future<void> _pollTick() async {
    final c = ctrl;
    if (c == null || !c.value.isInitialized || exporting || advancing || !ready || !mounted) return;
    final d = await c.position;
    if (d == null || !mounted || ctrl != c) return;
    final p = d.inMilliseconds;
    if ((p - pos.value).abs() >= 40) pos.value = p;
    _musicTick();
    if (playing && (p >= clip.end - 30 || c.value.isCompleted)) {
      advancing = true;
      try {
        final next = clips.length > 1 ? (sel + 1) % clips.length : sel;
        if (next == 0) _restartMusic(); // the video starts over, so does the music
        if (next == sel) {
          await c.seekTo(Duration(milliseconds: clip.start));
          if (playing) await c.play();
        } else {
          await _select(next);
        }
      } finally {
        advancing = false;
      }
    }
  }

  void _togglePlay() {
    final c = ctrl;
    if (c == null || !ready) return;
    HapticFeedback.selectionClick();
    setState(() => playing = !playing);
    playing ? c.play() : c.pause();
    final m = mc;
    if (m != null && m.value.isInitialized) playing ? m.play() : m.pause();
  }

  // ---------------------------------------------------------------- music

  Future<void> _pickMusic() async {
    try {
      final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav', 'ogg', 'flac']);
      if (f == null) return;
      final path = f.path;
      if (path == null) {
        if (mounted) showMsg(context, 'Could not read that file');
        return;
      }
      final c = VideoPlayerController.file(File(path));
      try {
        await c.initialize();
      } catch (_) {
        await c.dispose();
        if (mounted) showMsg(context, 'This audio file cannot be played. Try an mp3 or m4a.');
        return;
      }
      final dur = c.value.duration.inMilliseconds;
      if (!mounted || dur <= 0) {
        await c.dispose();
        return;
      }
      final old = mc;
      await c.setLooping(false);
      await c.setVolume(1);
      setState(() {
        mc = c;
        music = _Music(path: path, name: f.name, durMs: dur);
      });
      if (playing) c.play();
      await old?.dispose();
    } catch (e) {
      if (mounted) showMsg(context, 'Could not add music: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  void _removeMusic() {
    final old = mc;
    setState(() {
      mc = null;
      music = null;
    });
    old?.dispose();
  }

  void _musicVolume() {
    final m = music, c = mc;
    if (m == null || c == null) return;
    c.setVolume(m.volume.clamp(0.0, 1.0));
  }

  void _restartMusic() {
    final m = music, c = mc;
    if (m == null || c == null || !c.value.isInitialized) return;
    c.seekTo(Duration(milliseconds: m.startMs));
    if (playing) c.play();
  }

  /// Keeps the preview music inside the chosen part of the song, looping it if asked.
  void _musicTick() {
    final m = music, c = mc;
    if (m == null || c == null || !c.value.isInitialized || !playing) return;
    final p = c.value.position.inMilliseconds;
    if (p >= m.endMs - 60 || c.value.isCompleted) {
      if (m.loop) {
        c.seekTo(Duration(milliseconds: m.startMs));
        c.play();
      } else {
        c.pause();
      }
    }
  }

  Future<void> _addMore() async {
    try {
      final f = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (f == null) return;
      await _addClip(f.path);
      if (mounted) await _select(clips.length - 1);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not add that video');
    }
  }

  void _split() {
    final c = clip;
    if (posMs < c.start + 400 || posMs > c.end - 400) {
      showMsg(context, 'Move the playhead inside the clip, away from its ends');
      return;
    }
    final right = c.copy()..start = posMs;
    c.end = posMs;
    clips.insert(sel + 1, right);
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void _onTool(String id) {
    HapticFeedback.selectionClick();
    switch (id) {
      case 'rotate':
        setState(() => turns = (turns + 1) % 4);
      case 'flip':
        setState(() => flipX = !flipX);
      case 'reverse':
        setState(() => clip.reverse = !clip.reverse);
        showMsg(context, clip.reverse ? 'This clip will play backwards in the finished video' : 'Reverse off');
      case 'delete':
        if (clips.length == 1) {
          showMsg(context, 'A video needs at least one clip');
          return;
        }
        clips.removeAt(sel);
        _select(sel.clamp(0, clips.length - 1));
      case 'split':
        setState(() => tool = id);
        _split();
      default:
        setState(() => tool = tool == id ? null : id);
    }
  }

  Future<void> _addText() async {
    final ctl = TextEditingController();
    var color = 0xFFFFFFFF;
    final added = await showDialog<TextOverlay>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _panel,
          title: const Text('Add text', style: TextStyle(color: Colors.white)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctl, autofocus: true, maxLength: 60, style: const TextStyle(color: Colors.white), textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Type something', hintStyle: TextStyle(color: Colors.white38))),
            const SizedBox(height: 6),
            _colorRow(color, (c) => setD(() => color = c)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim().isEmpty ? null : TextOverlay(text: ctl.text.trim(), color: color)), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (added != null && mounted) {
      setState(() {
        texts.add(added);
        selText = texts.length - 1;
      });
    }
  }

  static const _palette = [0xFFFFFFFF, 0xFF111111, 0xFFFFC21A, 0xFFFF6B5E, 0xFF5BC0FF, 0xFF6EE7A8];

  Widget _colorRow(int current, ValueChanged<int> onPick) => Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (final c in _palette)
          GestureDetector(
            onTap: () => onPick(c),
            child: AnimatedContainer(
              duration: kFast,
              width: 30,
              height: 30,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: current == c ? C.primary : Colors.white24, width: current == c ? 3 : 1)),
            ),
          ),
      ]);

  // ---------------------------------------------------------------- export

  Future<ui.Image> _overlayImage(int w, int h) async {
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    for (final t in texts) {
      final tp = TextPainter(
        text: TextSpan(text: t.text, style: TextStyle(fontSize: h * 0.045, fontWeight: FontWeight.w800, color: Color(t.color), shadows: const [Shadow(blurRadius: 8, color: Colors.black54)])),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 3,
      )..layout(maxWidth: w * 0.8);
      tp.paint(canvas, Offset(t.dx * w - tp.width / 2, t.dy * h - tp.height / 2));
    }
    return rec.endRecording().toImage(w, h);
  }

  Future<void> _export() async {
    if (exporting) return;
    ctrl?.pause();
    mc?.pause();
    setState(() {
      exporting = true;
      progress = 0;
    });
    StreamSubscription? sub;
    try {
      final ca = cropAspect;
      final res = resolution;
      int? cw, ch, cx, cy;
      if (ca != null) {
        final srcCrop = turns.isOdd ? 1 / ca : ca;
        var w = res.width, h = res.height;
        if (w / h > srcCrop) {
          w = h * srcCrop;
        } else {
          h = w / srcCrop;
        }
        cw = (w.floor() ~/ 2) * 2;
        ch = (h.floor() ~/ 2) * 2;
        cx = ((res.width - cw) / 2).floor();
        cy = ((res.height - ch) / 2).floor();
      }
      final srcW = cw ?? res.width.round(), srcH = ch ?? res.height.round();
      final outW = turns.isOdd ? srcH : srcW, outH = turns.isOdd ? srcW : srcH;

      final layers = <pve.ImageLayer>[];
      if (texts.isNotEmpty) {
        final img = await _overlayImage(outW, outH);
        final bytes = (await img.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        layers.add(pve.ImageLayer(image: pve.EditorLayerImage.memory(bytes)));
      }
      final m = combinedMatrix(filter, adjust);
      final needsTransform = turns != 0 || flipX || ca != null;

      final data = pve.VideoRenderData(
        videoSegments: [
          for (final c in clips)
            pve.VideoSegment(
              video: pve.EditorVideo.file(File(c.path)),
              startTime: Duration(milliseconds: c.start),
              endTime: Duration(milliseconds: c.end),
              volume: c.volume,
              playbackSpeed: c.speed == 1 ? null : c.speed,
              reverseVideo: c.reverse,
            ),
        ],
        imageLayers: layers.isEmpty ? null : layers,
        colorFilters: m == null ? const [] : [pve.ColorFilter(matrix: m)],
        transform: needsTransform ? pve.ExportTransform(rotateTurns: turns, flipX: flipX, width: cw, height: ch, x: cx, y: cy) : null,
        enableAudio: true,
        audioTracks: [
          if (music != null)
            pve.VideoAudioTrack(
              path: music!.path,
              volume: music!.volume,
              loop: music!.loop,
              audioStartTime: Duration(milliseconds: music!.startMs),
              audioEndTime: Duration(milliseconds: music!.endMs),
              startTime: Duration.zero,
              endTime: Duration(milliseconds: clips.fold<int>(0, (a, c) => a + c.outMs).clamp(1, 1 << 30)),
              fadeInDuration: music!.fadeIn ? const Duration(seconds: 2) : Duration.zero,
              fadeOutDuration: music!.fadeOut ? const Duration(seconds: 2) : Duration.zero,
            ),
        ],
      );
      taskId = data.id;
      sub = pve.ProVideoEditor.instance.progressStreamById(data.id).listen((p) {
        if (mounted) setState(() => progress = p.progress.toDouble().clamp(0.0, 1.0));
      });
      final out = '${Directory.systemTemp.path}/viewrec_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final path = await pve.ProVideoEditor.instance.renderVideoToFile(out, data);
      if (!mounted) return;
      Navigator.of(context).pop(XFile(path));
    } catch (e) {
      if (!mounted) return;
      setState(() => exporting = false);
      if (e is! pve.RenderCanceledException) showMsg(context, 'Could not save the video: ${e.toString().replaceFirst('Exception: ', '')}');
      if (playing) ctrl?.play();
    } finally {
      await sub?.cancel();
    }
  }

  void _cancelExport() {
    final id = taskId;
    if (id != null) pve.ProVideoEditor.instance.cancel(id);
  }

  // ---------------------------------------------------------------- preview

  Widget _preview() {
    final c = ctrl;
    if (!ready || c == null || !c.value.isInitialized) return const Center(child: CircularProgressIndicator(strokeWidth: 2.4));
    final vs = c.value.size;
    final srcAspect = vs.width / vs.height;
    final ca = cropAspect;
    final srcCrop = ca == null ? null : (turns.isOdd ? 1 / ca : ca);
    final aspect = srcCrop ?? srcAspect;
    Widget video = AspectRatio(
      aspectRatio: aspect,
      child: ClipRect(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: vs.width, height: vs.height, child: VideoPlayer(c)))),
    );
    final m = combinedMatrix(filter, adjust);
    if (m != null) video = ColorFiltered(colorFilter: ColorFilter.matrix(m), child: video);
    if (flipX) video = Transform.flip(flipX: true, child: video);
    video = RotatedBox(quarterTurns: turns, child: video);
    final finalAspect = turns.isOdd ? 1 / aspect : aspect;

    return Center(
      child: AspectRatio(
        aspectRatio: finalAspect,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: LayoutBuilder(
            builder: (context, box) => Stack(fit: StackFit.expand, children: [
              GestureDetector(behavior: HitTestBehavior.opaque, onTap: _togglePlay, child: video),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: kMed,
                  opacity: playing ? 0 : 1,
                  child: Center(
                    child: Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle, border: Border.all(color: Colors.white30)), child: const Icon(Icons.play_arrow_rounded, size: 38, color: Colors.white)),
                  ),
                ),
              ),
              for (var i = 0; i < texts.length; i++)
                Align(
                  alignment: Alignment(texts[i].dx * 2 - 1, texts[i].dy * 2 - 1),
                  child: GestureDetector(
                    onTap: () => setState(() => selText = i),
                    onPanStart: (_) => setState(() => selText = i),
                    onPanUpdate: (d) {
                      final t = texts[i];
                      setState(() {
                        t.dx = (t.dx + d.delta.dx / box.maxWidth).clamp(0.08, 0.92);
                        t.dy = (t.dy + d.delta.dy / box.maxHeight).clamp(0.05, 0.95);
                      });
                    },
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      setState(() {
                        texts.removeAt(i);
                        selText = -1;
                      });
                    },
                    child: Container(
                      constraints: BoxConstraints(maxWidth: box.maxWidth * 0.8),
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(border: Border.all(color: selText == i ? Colors.white70 : Colors.transparent), borderRadius: BorderRadius.circular(6)),
                      child: Text(texts[i].text, textAlign: TextAlign.center, style: TextStyle(fontSize: box.maxHeight * 0.045, fontWeight: FontWeight.w800, color: Color(texts[i].color), shadows: const [Shadow(blurRadius: 8, color: Colors.black54)])),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- timeline

  Widget _filmstrip(_Clip c, {double height = 56}) {
    if (c.thumbs.isEmpty) return Container(height: height, color: Colors.white10);
    return SizedBox(
      height: height,
      child: Row(children: [for (final t in c.thumbs) Expanded(child: Image.memory(t, fit: BoxFit.cover, height: height, gaplessPlayback: true))]),
    );
  }

  Widget _clipTile(int i) {
    final c = clips[i];
    return GestureDetector(
      key: ObjectKey(c),
      onTap: () {
        if (i != sel) {
          HapticFeedback.selectionClick();
          _select(i);
        }
      },
      child: AnimatedContainer(
        duration: kMed,
        curve: kCurve,
        width: (c.outMs / 1000 * 26).clamp(88.0, 240.0),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: i == sel ? C.primary : Colors.transparent, width: 2)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(fit: StackFit.expand, children: [
            _filmstrip(c),
            Positioned(
              left: 5,
              bottom: 3,
              child: Text('${_t(c.outMs)}${c.speed != 1 ? '  ${c.speed}x' : ''}${c.reverse ? '  <<' : ''}', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800, shadows: [Shadow(blurRadius: 4, color: Colors.black87)])),
            ),
          ]),
        ),
      ),
    );
  }

  /// Drag a clip to move it earlier or later in the video.
  void _reorderClips(int from, int to) {
    if (to > from) to -= 1;
    if (from == to) return;
    final selected = clips[sel];
    final moved = clips.removeAt(from);
    clips.insert(to, moved);
    HapticFeedback.mediumImpact();
    setState(() => sel = clips.indexOf(selected));
  }

  Widget _timeline() {
    final total = clips.fold<int>(0, (a, c) => a + c.outMs);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: Row(children: [
          ValueListenableBuilder<int>(
            valueListenable: pos,
            builder: (_, p, __) => Text('${_t((p - clip.start).clamp(0, clip.durMs))} / ${_t(clip.end - clip.start)}', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          Text(clips.length > 1 ? 'Hold and drag a clip to reorder   Total ${_t(total)}' : 'Total ${_t(total)}', style: const TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
      SizedBox(
        height: 64,
        child: ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: clips.length,
          onReorder: _reorderClips,
          proxyDecorator: (child, index, anim) => AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Transform.scale(scale: 1 + 0.06 * Curves.easeOut.transform(anim.value), child: Material(color: Colors.transparent, elevation: 8 * anim.value, borderRadius: BorderRadius.circular(12), child: child)),
          ),
          itemBuilder: (_, i) => ReorderableDelayedDragStartListener(key: ObjectKey(clips[i]), index: i, child: _clipTile(i)),
          footer: GestureDetector(
            onTap: _addMore,
            child: Container(
              width: 58,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
      // the music runs under the whole video
      AnimatedSize(
        duration: kMed,
        curve: kCurve,
        child: music == null
            ? const SizedBox(width: double.infinity)
            : GestureDetector(
                onTap: () => setState(() => tool = 'music'),
                child: Container(
                  height: 28,
                  margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3E94F5), Color(0xFF1FC9A4)]), borderRadius: BorderRadius.circular(9)),
                  child: Row(children: [
                    MusicBars(active: playing, height: 13),
                    const SizedBox(width: 8),
                    Expanded(child: Text(music!.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700))),
                  ]),
                ),
              ),
      ),
    ]);
  }

  // ---------------------------------------------------------------- tool panels

  Widget _panelFor(String id) {
    switch (id) {
      case 'trim':
        return _trimPanel();
      case 'split':
        return _hint('Move the playhead by playing or by dragging the trim handles, then tap Split to cut the clip in two.');
      case 'speed':
        return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (final v in const [0.25, 0.5, 1.0, 1.5, 2.0, 3.0, 4.0])
            _chip(v == 1 ? 'Normal' : '${v}x', clip.speed == v, () {
              setState(() => clip.speed = v);
              _applyClipAudioSpeed();
            }),
        ]);
      case 'volume':
        return Row(children: [
          Icon(clip.volume == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded, color: Colors.white70),
          Expanded(
            child: Slider(
              value: clip.volume,
              min: 0,
              max: 2,
              divisions: 20,
              activeColor: C.primary,
              onChanged: (v) {
                setState(() => clip.volume = v);
                _applyClipAudioSpeed();
              },
            ),
          ),
          SizedBox(width: 48, child: Text('${(clip.volume * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))),
        ]);
      case 'filter':
        return SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: kFilterNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final f = filterFor(i);
              final thumb = clip.thumbs.isEmpty ? Container(color: Colors.white12) : Image.memory(clip.thumbs[clip.thumbs.length ~/ 2], fit: BoxFit.cover, gaplessPlayback: true);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => filter = i);
                },
                child: Column(children: [
                  AnimatedContainer(
                    duration: kMed,
                    width: 58,
                    height: 68,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: filter == i ? C.primary : Colors.transparent, width: 2)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(9), child: f == null ? thumb : ColorFiltered(colorFilter: f, child: thumb)),
                  ),
                  const SizedBox(height: 4),
                  Text(kFilterNames[i], style: TextStyle(color: filter == i ? Colors.white : Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                ]),
              );
            },
          ),
        );
      case 'adjust':
        Widget row(String label, double v, ValueChanged<double> on) => Row(children: [
              SizedBox(width: 84, child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700))),
              Expanded(child: Slider(value: v, min: -1, max: 1, activeColor: C.primary, onChanged: (x) => setState(() => on(x)))),
              SizedBox(width: 36, child: Text('${(v * 100).round()}', textAlign: TextAlign.end, style: const TextStyle(color: Colors.white54, fontSize: 12))),
            ]);
        return Column(mainAxisSize: MainAxisSize.min, children: [
          row('Brightness', adjust.brightness, (x) => adjust.brightness = x),
          row('Contrast', adjust.contrast, (x) => adjust.contrast = x),
          row('Saturation', adjust.saturation, (x) => adjust.saturation = x),
          row('Warmth', adjust.warmth, (x) => adjust.warmth = x),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(adjust.reset), child: const Text('Reset'))),
        ]);
      case 'text':
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_chip('+ Add text', false, _addText)]),
          const SizedBox(height: 10),
          if (selText >= 0 && selText < texts.length) _colorRow(texts[selText].color, (c) => setState(() => texts[selText].color = c)),
          const SizedBox(height: 6),
          const Text('Drag text to move it. Long-press to remove it.', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ]);
      case 'music':
        return _musicPanel();
      case 'crop':
        return Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          for (var i = 0; i < _aspects.length; i++) _chip(_aspects[i].$1, aspect == i, () => setState(() => aspect = i)),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _musicPanel() {
    final m = music;
    if (m == null) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        _chip('+ Add music', false, _pickMusic),
        const SizedBox(height: 10),
        _hint('Pick a song or sound from your phone (mp3, m4a, wav). It plays under your video.'),
      ]);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        const Icon(Icons.music_note_rounded, color: Color(0xFF1FC9A4), size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5))),
        TextButton(onPressed: _pickMusic, child: const Text('Change')),
        IconButton(onPressed: _removeMusic, icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70, size: 20), visualDensity: VisualDensity.compact),
      ]),
      Row(children: [
        const SizedBox(width: 56, child: Text('Volume', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700))),
        Expanded(
          child: Slider(
            value: m.volume,
            min: 0,
            max: 2,
            divisions: 20,
            activeColor: C.primary,
            onChanged: (v) {
              setState(() => m.volume = v);
              _musicVolume();
            },
          ),
        ),
        SizedBox(width: 44, child: Text('${(m.volume * 100).round()}%', textAlign: TextAlign.end, style: const TextStyle(color: Colors.white54, fontSize: 12))),
      ]),
      const Align(alignment: Alignment.centerLeft, child: Text('Part of the song to use', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w700))),
      RangeSlider(
        values: RangeValues(m.startMs.toDouble(), m.endMs.toDouble()),
        min: 0,
        max: m.durMs.toDouble(),
        activeColor: const Color(0xFF1FC9A4),
        onChanged: (v) {
          if (v.end - v.start < 1000) return;
          setState(() {
            m.startMs = v.start.round();
            m.endMs = v.end.round();
          });
        },
        onChangeEnd: (_) => _restartMusic(),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('From ${_t(m.startMs)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text('Length ${_t(m.endMs - m.startMs)}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        Text('To ${_t(m.endMs)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ]),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
        _chip('Fade in', m.fadeIn, () => setState(() => m.fadeIn = !m.fadeIn)),
        _chip('Fade out', m.fadeOut, () => setState(() => m.fadeOut = !m.fadeOut)),
        _chip('Repeat', m.loop, () => setState(() => m.loop = !m.loop)),
      ]),
    ]);
  }

  Widget _hint(String s) => Text(s, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12.5, height: 1.4));

  Widget _chip(String label, bool on, VoidCallback onTap) => GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: kMed,
          curve: kCurve,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(color: on ? C.primary : Colors.white10, borderRadius: BorderRadius.circular(999)),
          child: Text(label, style: TextStyle(color: on ? Colors.white : Colors.white70, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      );

  Widget _trimPanel() {
    final c = clip;
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth - 28; // room for the handles
      double x(int ms) => ms / c.durMs * w;
      const gap = 500;
      Widget handle(bool isStart) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => ctrl?.pause(),
            onHorizontalDragUpdate: (d) {
              final dms = (d.delta.dx / w * c.durMs).round();
              setState(() {
                if (isStart) {
                  c.start = (c.start + dms).clamp(0, c.end - gap);
                } else {
                  c.end = (c.end + dms).clamp(c.start + gap, c.durMs);
                }
              });
              ctrl?.seekTo(Duration(milliseconds: isStart ? c.start : c.end - 100));
            },
            onHorizontalDragEnd: (_) {
              ctrl?.seekTo(Duration(milliseconds: c.start));
              if (playing) ctrl?.play();
            },
            child: Container(
              width: 14,
              height: 64,
              decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.horizontal(left: Radius.circular(isStart ? 8 : 0), right: Radius.circular(isStart ? 0 : 8))),
              child: const Center(child: Icon(Icons.drag_indicator_rounded, size: 12, color: Colors.white)),
            ),
          );
      return Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 64,
          child: Stack(children: [
            Positioned(left: 14, right: 14, top: 4, bottom: 4, child: ClipRRect(borderRadius: BorderRadius.circular(4), child: _filmstrip(c, height: 56))),
            Positioned(left: 14, top: 4, bottom: 4, width: x(c.start), child: Container(color: Colors.black.withValues(alpha: 0.65))),
            Positioned(left: 14 + x(c.end), right: 14, top: 4, bottom: 4, child: Container(color: Colors.black.withValues(alpha: 0.65))),
            Positioned(left: x(c.start), top: 0, child: handle(true)),
            Positioned(left: 14 + x(c.end), top: 0, child: handle(false)),
          ]),
        ),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Start ${_t(c.start)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text('Length ${_t(c.end - c.start)}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
          Text('End ${_t(c.end)}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ]),
      ]);
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(useMaterial3: true).copyWith(scaffoldBackgroundColor: _bg),
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Stack(children: [
            Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
                child: Row(children: [
                  IconButton(onPressed: exporting ? null : () => Navigator.of(context).pop(), icon: const Icon(Icons.close_rounded, color: Colors.white)),
                  const Expanded(child: Text('Edit video', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                  GestureDetector(
                    onTap: ready && !exporting ? _export : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF3E94F5), Color(0xFF0B5FC4)]), borderRadius: BorderRadius.circular(999), boxShadow: C.glow),
                      child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
              ),
              Expanded(child: Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 8), child: _preview())),
              if (ready) _timeline(),
              const SizedBox(height: 8),
              AnimatedSize(
                duration: kMed,
                curve: kCurve,
                alignment: Alignment.topCenter,
                child: tool == null || !ready
                    ? const SizedBox(width: double.infinity)
                    : Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(20)),
                        child: AnimatedSwitcher(duration: kFast, child: KeyedSubtree(key: ValueKey(tool), child: _panelFor(tool!))),
                      ),
              ),
              SizedBox(
                height: 76,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: _tools.length,
                  itemBuilder: (_, i) {
                    final t = _tools[i];
                    final on = tool == t.$1 || (t.$1 == 'flip' && flipX) || (t.$1 == 'reverse' && ready && clip.reverse) || (t.$1 == 'rotate' && turns != 0);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: ready ? () => _onTool(t.$1) : null,
                      child: SizedBox(
                        width: 68,
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          AnimatedContainer(
                            duration: kMed,
                            curve: kCurve,
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(color: on ? C.primary.withValues(alpha: 0.22) : Colors.transparent, shape: BoxShape.circle),
                            child: Icon(t.$2, size: 22, color: on ? C.primary : Colors.white70),
                          ),
                          Text(t.$3, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: on ? C.primary : Colors.white54)),
                          AnimatedContainer(
                            duration: kMed,
                            curve: kCurve,
                            margin: const EdgeInsets.only(top: 3),
                            width: on ? 16 : 0,
                            height: 3,
                            decoration: BoxDecoration(color: C.primary, borderRadius: BorderRadius.circular(2)),
                          ),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ]),
            if (exporting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.78),
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                        width: 92,
                        height: 92,
                        child: Stack(alignment: Alignment.center, children: [
                          SizedBox.expand(child: CircularProgressIndicator(value: progress <= 0 ? null : progress, strokeWidth: 5, color: C.primary, backgroundColor: Colors.white12)),
                          Text('${(progress * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      const Text('Saving your video…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 14),
                      TextButton(onPressed: _cancelExport, child: const Text('Cancel')),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
