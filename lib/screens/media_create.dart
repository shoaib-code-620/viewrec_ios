import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../media_data.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';
import 'edit_filters.dart';
import 'photo_editor.dart';
import 'video_editor.dart';

bool _isHttp(String p) => p.startsWith('http://') || p.startsWith('https://') || p.startsWith('blob:');

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

  /// A photo fades in once it has loaded, instead of popping.
  Widget _fadeIn(BuildContext context, Widget child, int? frame, bool sync) =>
      sync ? child : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 420), curve: Curves.easeOut, child: child);

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
        ? Image.network(p, fit: BoxFit.cover, width: double.infinity, height: double.infinity, frameBuilder: _fadeIn, errorBuilder: (_, __, ___) => _fallback)
        : Image.file(File(p), fit: BoxFit.cover, width: double.infinity, height: double.infinity, frameBuilder: _fadeIn, errorBuilder: (_, __, ___) => _fallback);
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

Future<int> _videoLengthMs(String path) async {
  final c = (kIsWeb || _isHttp(path)) ? VideoPlayerController.networkUrl(Uri.parse(path)) : VideoPlayerController.file(File(path));
  try {
    await c.initialize();
    return c.value.duration.inMilliseconds;
  } catch (_) {
    return 0;
  } finally {
    await c.dispose();
  }
}

/// Create a post, reel or story: choose a photo or video, edit it, add a caption, publish.
class ComposeScreen extends StatefulWidget {
  final String kind; // 'post' | 'reel' | 'story'
  /// A video that is already finished (for example from the caption studio). Skips the picker.
  final XFile? initialVideo;
  const ComposeScreen({super.key, required this.kind, this.initialVideo});
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

  @override
  void initState() {
    super.initState();
    final v = widget.initialVideo;
    if (v != null) {
      file = v;
      isVideo = true;
      _videoLengthMs(v.path).then((ms) {
        if (mounted) setState(() => durMs = ms);
      });
    }
  }

  bool get _isReel => widget.kind == 'reel';
  bool get _isStory => widget.kind == 'story';
  String get _title => _isReel ? 'New reel' : _isStory ? 'New story' : 'New post';

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  /// Opens the photo or video editor. Returns the edited file, or null if the user closed it.
  Future<XFile?> _openEditor(XFile f, bool video) async {
    try {
      return video ? await editVideo(context, f) : await editPhoto(context, f);
    } catch (e) {
      if (mounted) showMsg(context, 'The editor could not open: ${e.toString().replaceFirst('Exception: ', '')}');
      return null;
    }
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
      if (!mounted) return;
      // Straight into the editor, like other social apps. Closing it keeps the original.
      final edited = await _openEditor(f, video);
      final chosen = edited ?? f;
      final ms = video ? await _videoLengthMs(chosen.path) : 0;
      if (!mounted) return;
      setState(() {
        file = chosen;
        isVideo = video;
        durMs = ms;
      });
    } catch (e) {
      // Show the real reason, so a permission problem and a bad file can be told apart.
      if (mounted) showMsg(context, 'Could not open that: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _editAgain() async {
    final f = file;
    if (f == null) return;
    final edited = await _openEditor(f, isVideo);
    if (edited == null || !mounted) return;
    final ms = isVideo ? await _videoLengthMs(edited.path) : 0;
    if (!mounted) return;
    setState(() {
      file = edited;
      durMs = ms;
    });
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
        duration: isVideo ? _fmtMs(durMs) : '0:00',
        onProgress: (p) {
          if (mounted) setState(() => progress = p);
        },
      );
      mediaRevision.value++;
      if (!mounted) return;
      final label = _isReel ? 'Reel' : _isStory ? 'Story' : 'Post';
      showSuccess(context, '$label shared');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => busy = false);
      showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    }
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
              decoration: BoxDecoration(color: C.surface, borderRadius: BorderRadius.circular(24), border: Border.all(color: C.border)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(_isReel ? Icons.movie_creation_rounded : _isStory ? Icons.auto_stories_rounded : Icons.grid_on_rounded, size: 44, color: C.muted),
                const SizedBox(height: 10),
                Text(_isReel ? 'Choose a video' : 'Choose a photo or video', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Muted(_isStory ? 'Stories disappear after 24 hours' : "It will appear in your followers' feed", size: 12.5),
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
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: AspectRatio(
                  aspectRatio: tall ? 9 / 16 : 4 / 5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(fit: StackFit.expand, children: [
                      MediaView(key: ValueKey(f.path), path: f.path, isVideo: isVideo, hue: const Color(0xFF0A2E66), play: true, sound: true),
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
                      if (isVideo && durMs > 0)
                        Positioned(
                          left: 10,
                          bottom: 10,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(8)),
                              child: Text(_fmtMs(durMs), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppButton(isVideo ? 'Edit video' : 'Edit photo', icon: Icons.tune_rounded, style: BtnStyle.ghost, small: true, onTap: busy ? null : _editAgain),
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
