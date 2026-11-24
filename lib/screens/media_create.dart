import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../media_data.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

bool _isHttp(String p) => p.startsWith('http://') || p.startsWith('https://') || p.startsWith('blob:');

/// Colour filters offered in the editor. [EditSpec.filter] is an index into this list.
const kFilterNames = ['Original', 'Vivid', 'Warm', 'Cool', 'Mono', 'Fade', 'Vintage'];

ColorFilter? filterFor(int i) {
  switch (i) {
    case 1: // more colour and contrast
      return const ColorFilter.matrix([1.25, -0.1, -0.1, 0, -8, -0.1, 1.25, -0.1, 0, -8, -0.1, -0.1, 1.25, 0, -8, 0, 0, 0, 1, 0]);
    case 2: // warm
      return const ColorFilter.matrix([1.12, 0, 0, 0, 8, 0, 1.0, 0, 0, 0, 0, 0, 0.84, 0, 0, 0, 0, 0, 1, 0]);
    case 3: // cool
      return const ColorFilter.matrix([0.86, 0, 0, 0, 0, 0, 1.0, 0, 0, 0, 0, 0, 1.15, 0, 8, 0, 0, 0, 1, 0]);
    case 4: // black and white
      return const ColorFilter.matrix([0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0.33, 0.59, 0.11, 0, 0, 0, 0, 0, 1, 0]);
    case 5: // faded
      return const ColorFilter.matrix([0.82, 0, 0, 0, 34, 0, 0.82, 0, 0, 34, 0, 0, 0.82, 0, 34, 0, 0, 0, 1, 0]);
    case 6: // sepia
      return const ColorFilter.matrix([0.39, 0.77, 0.19, 0, 0, 0.35, 0.69, 0.17, 0, 0, 0.27, 0.53, 0.13, 0, 0, 0, 0, 0, 1, 0]);
    default:
      return null;
  }
}

/// Shows an uploaded photo or video, filling its box, with its edits applied (filter, text, trim, speed, mute).
/// A video shows its first frame until [play] is true, then plays looping. Sound is off unless [sound] is true.
/// With [onEdited] set, text can be dragged to move it and long-pressed to remove it.
class MediaView extends StatefulWidget {
  final String? path;
  final bool isVideo, play, sound;
  final Color hue;
  final EditSpec? edits;
  final VoidCallback? onEdited;
  const MediaView({super.key, required this.path, required this.isVideo, required this.hue, this.play = false, this.sound = false, this.edits, this.onEdited});
  @override
  State<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends State<MediaView> {
  VideoPlayerController? _vc;
  double _lastStart = -1;

  double get _start => widget.edits?.trimStart ?? 0;
  double get _end => widget.edits?.trimEnd ?? 1;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final p = widget.path;
    if (p == null || !widget.isVideo) return;
    final c = (kIsWeb || _isHttp(p)) ? VideoPlayerController.networkUrl(Uri.parse(p)) : VideoPlayerController.file(File(p));
    _vc = c;
    try {
      await c.initialize();
      await c.setLooping(false);
      c.addListener(_tick);
      if (!mounted) return;
      await _apply(force: true);
      setState(() {});
      if (widget.play) c.play();
    } catch (_) {
      // Unplayable file: the coloured background stays.
    }
  }

  /// Keeps playback inside the trimmed part and loops it.
  void _tick() {
    final c = _vc;
    if (c == null || !c.value.isInitialized || !c.value.isPlaying) return;
    final total = c.value.duration.inMilliseconds;
    if (total == 0) return;
    if (c.value.position.inMilliseconds >= _end * total - 40) {
      c.seekTo(Duration(milliseconds: (_start * total).round()));
    }
  }

  Future<void> _apply({bool force = false}) async {
    final c = _vc;
    if (c == null || !c.value.isInitialized) return;
    await c.setPlaybackSpeed(widget.edits?.speed ?? 1);
    await c.setVolume(widget.sound && !(widget.edits?.muted ?? false) ? 1 : 0);
    if (force || _lastStart != _start) {
      _lastStart = _start;
      await c.seekTo(Duration(milliseconds: (_start * c.value.duration.inMilliseconds).round()));
    }
  }

  @override
  void didUpdateWidget(MediaView old) {
    super.didUpdateWidget(old);
    final c = _vc;
    if (c == null || !c.value.isInitialized) return;
    _apply();
    if (widget.play && !c.value.isPlaying) c.play();
    if (!widget.play && c.value.isPlaying) c.pause();
  }

  @override
  void dispose() {
    _vc?.removeListener(_tick);
    _vc?.dispose();
    super.dispose();
  }

  Widget get _fallback => DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [widget.hue, Color.lerp(widget.hue, Colors.black, 0.7)!])));

  Widget _content() {
    final p = widget.path;
    if (p == null) return _fallback;
    if (widget.isVideo) {
      final c = _vc;
      if (c == null || !c.value.isInitialized) return _fallback;
      return ClipRect(
        child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: c.value.size.width, height: c.value.size.height, child: VideoPlayer(c))),
      );
    }
    return (kIsWeb || _isHttp(p))
        ? Image.network(p, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => _fallback)
        : Image.file(File(p), fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => _fallback);
  }

  @override
  Widget build(BuildContext context) {
    var content = _content();
    final f = filterFor(widget.edits?.filter ?? 0);
    if (f != null && widget.path != null) content = ColorFiltered(colorFilter: f, child: content);
    final texts = widget.edits?.texts ?? const <TextOverlay>[];
    if (texts.isEmpty) return content;
    return Stack(fit: StackFit.expand, children: [
      content,
      LayoutBuilder(
        builder: (context, box) => Stack(children: [
          for (final t in texts)
            Positioned.fill(
              child: Align(
                alignment: Alignment(t.dx * 2 - 1, t.dy * 2 - 1),
                child: GestureDetector(
                  onPanUpdate: widget.onEdited == null
                      ? null
                      : (d) {
                          t.dx = (t.dx + d.delta.dx / box.maxWidth).clamp(0.08, 0.92);
                          t.dy = (t.dy + d.delta.dy / box.maxHeight).clamp(0.05, 0.95);
                          widget.onEdited!();
                        },
                  onLongPress: widget.onEdited == null
                      ? null
                      : () {
                          texts.remove(t);
                          widget.onEdited!();
                        },
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: box.maxWidth * 0.8),
                    child: Text(t.text, textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(t.color), shadows: const [Shadow(blurRadius: 8, color: Colors.black54)])),
                  ),
                ),
              ),
            ),
        ]),
      ),
    ]);
  }
}

const _videoExts = {'mp4', 'mov', 'm4v', 'webm', '3gp', 'mkv', 'avi'};

bool _looksLikeVideo(XFile f) {
  if (f.mimeType != null) return f.mimeType!.startsWith('video');
  final n = f.name.toLowerCase();
  final dot = n.lastIndexOf('.');
  return dot >= 0 && _videoExts.contains(n.substring(dot + 1));
}

String _fmtMs(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Create a post, reel or story: choose a photo or video, edit it, add a caption, publish.
class ComposeScreen extends StatefulWidget {
  final String kind; // 'post' | 'reel' | 'story'
  const ComposeScreen({super.key, required this.kind});
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _picker = ImagePicker();
  final _caption = TextEditingController();
  XFile? file;
  bool isVideo = false, busy = false;
  int durMs = 0;
  double progress = 0;
  EditSpec edits = EditSpec();
  String tool = 'filter'; // trim | filter | text | speed | sound

  bool get _isReel => widget.kind == 'reel';
  bool get _isStory => widget.kind == 'story';
  String get _title => _isReel ? 'New reel' : _isStory ? 'New story' : 'New post';

  /// Length of the edited video, after trimming and speed.
  int get _editedMs => (durMs * (edits.trimEnd - edits.trimStart) / edits.speed).round();

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<XFile?> Function() pick) async {
    try {
      final f = await pick();
      if (f == null) return;
      final video = _looksLikeVideo(f);
      if (_isReel && !video) {
        if (mounted) showMsg(context, 'Reels need a video. Pick or record one.');
        return;
      }
      var ms = 0;
      if (video) {
        final c = (kIsWeb || _isHttp(f.path)) ? VideoPlayerController.networkUrl(Uri.parse(f.path)) : VideoPlayerController.file(File(f.path));
        try {
          await c.initialize();
          ms = c.value.duration.inMilliseconds;
        } catch (_) {}
        await c.dispose();
      }
      if (!mounted) return;
      setState(() {
        file = f;
        isVideo = video;
        durMs = ms;
        edits = EditSpec();
        tool = video ? 'trim' : 'filter';
      });
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open that. Check the app has permission for the camera or photos.');
    }
  }

  Future<void> _publish() async {
    final f = file;
    if (f == null || busy) return;
    setState(() {
      busy = true;
      progress = 0;
    });
    try {
      await repo.createContent(
        kind: widget.kind,
        file: f,
        isVideo: isVideo,
        caption: _caption.text.trim(),
        duration: isVideo ? _fmtMs(_editedMs) : '0:00',
        edits: edits.isEmpty ? null : edits,
        onProgress: (p) {
          if (mounted) setState(() => progress = p);
        },
      );
      mediaRevision.value++;
      if (!mounted) return;
      final label = _isReel ? 'Reel' : _isStory ? 'Story' : 'Post';
      Navigator.of(context).pop(true);
      showMsg(context, '$label shared');
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addText() async {
    final ctl = TextEditingController();
    var color = 0xFFFFFFFF;
    final added = await showDialog<TextOverlay>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: C.surface,
          title: const Text('Add text'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: ctl, autofocus: true, maxLength: 60, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Type something')),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (final c in const [0xFFFFFFFF, 0xFF111111, 0xFFFFD25E, 0xFFFF4F9A, 0xFF5BC0FF, 0xFF6EE7A8])
                GestureDetector(
                  onTap: () => setD(() => color = c),
                  child: Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(color: Color(c), shape: BoxShape.circle, border: Border.all(color: color == c ? C.primary : C.border, width: color == c ? 3 : 1)),
                  ),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim().isEmpty ? null : TextOverlay(text: ctl.text.trim(), color: color)), child: const Text('Add')),
          ],
        ),
      ),
    );
    ctl.dispose();
    if (added != null && mounted) setState(() => edits.texts.add(added));
  }

  Widget _source(IconData icon, String label, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: C.border)),
            child: Column(children: [
              Icon(icon, size: 28, color: C.primary),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      );

  Widget _toolTab(String id, IconData icon, String label) {
    final on = tool == id;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => tool = id),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: on ? C.primary.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: Column(children: [
            Icon(icon, size: 22, color: on ? C.primary : C.muted),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? C.primary : C.muted)),
          ]),
        ),
      ),
    );
  }

  Widget _toolPanel() {
    switch (tool) {
      case 'trim':
        final s = edits.trimStart, e = edits.trimEnd;
        return Column(children: [
          RangeSlider(
            values: RangeValues(s, e),
            min: 0,
            max: 1,
            activeColor: C.primary,
            onChanged: (v) {
              // keep at least about a second between the handles
              final gap = durMs == 0 ? 0.05 : (1000 / durMs).clamp(0.02, 0.5);
              if (v.end - v.start < gap) return;
              setState(() {
                edits.trimStart = v.start;
                edits.trimEnd = v.end;
              });
            },
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Muted('Start ${_fmtMs((s * durMs).round())}', size: 12),
            Text('Length ${_fmtMs(((e - s) * durMs).round())}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            Muted('End ${_fmtMs((e * durMs).round())}', size: 12),
          ]),
        ]);
      case 'filter':
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: kFilterNames.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              label: Text(kFilterNames[i]),
              selected: edits.filter == i,
              onSelected: (_) => setState(() => edits.filter = i),
            ),
          ),
        );
      case 'text':
        return Column(children: [
          AppButton('Add text', icon: Icons.text_fields_rounded, style: BtnStyle.ghost, small: true, onTap: _addText),
          const SizedBox(height: 6),
          Muted(edits.texts.isEmpty ? 'Add words to your ${isVideo ? 'video' : 'photo'}.' : 'Drag text to move it. Long-press to remove it.', size: 12),
        ]);
      case 'speed':
        return Wrap(spacing: 8, children: [
          for (final v in const [0.5, 1.0, 1.5, 2.0])
            ChoiceChip(label: Text(v == 1 ? 'Normal' : '${v}x'), selected: edits.speed == v, onSelected: (_) => setState(() => edits.speed = v)),
        ]);
      default:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Mute original sound', style: TextStyle(fontWeight: FontWeight.w700)),
          value: edits.muted,
          activeColor: C.primary,
          onChanged: (v) => setState(() => edits.muted = v),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = file;
    final tall = _isReel || _isStory;
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: C.text),
        title: Text(_title, style: TextStyle(color: C.text, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 24), children: [
          if (f == null) ...[
            Container(
              height: tall ? 300 : 240,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: C.border)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isReel ? Icons.movie_creation_rounded : _isStory ? Icons.auto_stories_rounded : Icons.grid_on_rounded, size: 44, color: C.muted),
                const SizedBox(height: 10),
                Text(_isReel ? 'Choose a video' : 'Choose a photo or video', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Muted(_isStory ? 'Stories disappear after 24 hours' : 'It will appear in your followers\' feed', size: 12.5),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _source(Icons.photo_library_rounded, 'Gallery', () => _pick(() => _isReel ? _picker.pickVideo(source: ImageSource.gallery) : _picker.pickMedia())),
              if (!_isReel) ...[
                const SizedBox(width: 10),
                _source(Icons.photo_camera_rounded, 'Take photo', () => _pick(() => _picker.pickImage(source: ImageSource.camera, imageQuality: 88))),
              ],
              const SizedBox(width: 10),
              _source(Icons.videocam_rounded, 'Record video', () => _pick(() => _picker.pickVideo(source: ImageSource.camera, maxDuration: Duration(seconds: _isReel ? 90 : 30)))),
            ]),
          ] else ...[
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.46),
                child: AspectRatio(
                  aspectRatio: tall ? 9 / 16 : 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(fit: StackFit.expand, children: [
                      MediaView(path: f.path, isVideo: isVideo, hue: const Color(0xFF3B2A6B), play: true, sound: true, edits: edits, onEdited: () => setState(() {})),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: busy ? null : () => setState(() => file = null),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), shape: BoxShape.circle),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white),
                          ),
                        ),
                      ),
                      if (isVideo)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(9)),
                              child: Text(_fmtMs(_editedMs), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // editing tools
            Row(children: [
              if (isVideo) _toolTab('trim', Icons.content_cut_rounded, 'Trim'),
              _toolTab('filter', Icons.auto_awesome_rounded, 'Filters'),
              _toolTab('text', Icons.text_fields_rounded, 'Text'),
              if (isVideo) _toolTab('speed', Icons.speed_rounded, 'Speed'),
              if (isVideo) _toolTab('sound', edits.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, 'Sound'),
            ]),
            const SizedBox(height: 8),
            _toolPanel(),
            const SizedBox(height: 12),
            TextField(
              controller: _caption,
              enabled: !busy,
              maxLines: 3,
              minLines: 1,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: _isStory ? 'Add a caption (optional)' : 'Write a caption…',
                filled: true,
                fillColor: C.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: C.border)),
              ),
            ),
            const SizedBox(height: 8),
            if (busy)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: progress == 0 ? null : progress, minHeight: 6, color: C.primary, backgroundColor: C.border)),
              ),
            AppButton(_isStory ? 'Share to story' : 'Share', icon: Icons.send_rounded, loading: busy, onTap: _publish),
          ],
        ]),
      ),
    );
  }
}
