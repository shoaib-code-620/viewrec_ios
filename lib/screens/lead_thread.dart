import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';
import '../async_view.dart';
import '../calls.dart';
import '../models.dart';
import '../motion.dart';
import '../repo.dart';
import '../theme.dart';
import '../widgets.dart';

/// Where a conversation's messages come from and go to. The Inbox and Support use the same screen with different sources.
abstract class ConversationSource {
  Future<List<ThreadMessage>> load();
  Future<ThreadMessage> sendText(String text);
  Future<ThreadMessage> sendAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress});
  Future<ThreadMessage> edit(String messageId, String text);
  Future<void> delete(String messageId);
  Future<ThreadMessage> logCall() => throw UnsupportedError('Calls are not available in this conversation');
}

/// A conversation with a customer who sent a request.
class LeadConversation extends ConversationSource {
  final Lead lead;
  LeadConversation(this.lead);
  @override
  Future<List<ThreadMessage>> load() => repo.leadMessages(lead.id);
  @override
  Future<ThreadMessage> sendText(String text) => repo.sendLeadMessage(lead.id, text);
  @override
  Future<ThreadMessage> sendAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress}) =>
      repo.sendLeadAttachment(lead.id, kind: kind, path: path, name: name, size: size, durationMs: durationMs, onProgress: onProgress);
  @override
  Future<ThreadMessage> edit(String messageId, String text) => repo.editLeadMessage(lead.id, messageId, text);
  @override
  Future<void> delete(String messageId) => repo.deleteLeadMessage(lead.id, messageId);
  @override
  Future<ThreadMessage> logCall() => repo.logLeadCall(lead.id);
}

/// Conversation with a person who sent a request: text, photos, files and voice notes.
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
                builder: (context, msgs, refresh) => ConversationBody(
                  source: LeadConversation(lead),
                  initial: msgs,
                  subtitle: '${lead.service} · via ${lead.source}',
                  quick: const ['Thanks - when suits you?', 'Can you send a photo?', 'I can come Thursday morning'],
                  callName: lead.name,
                  callPhone: lead.phone,
                ),
              ),
            ),
          ]),
        ),
      );
}

String _size(int b) {
  if (b <= 0) return '';
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}

String _clock(int ms) {
  final s = (ms / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

IconData _fileIcon(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.pdf')) return Icons.picture_as_pdf_rounded;
  if (n.endsWith('.doc') || n.endsWith('.docx') || n.endsWith('.txt')) return Icons.description_rounded;
  if (n.endsWith('.xls') || n.endsWith('.xlsx') || n.endsWith('.csv')) return Icons.table_chart_rounded;
  if (n.endsWith('.zip') || n.endsWith('.rar')) return Icons.folder_zip_rounded;
  if (n.endsWith('.mp4') || n.endsWith('.mov')) return Icons.movie_rounded;
  if (n.endsWith('.mp3') || n.endsWith('.m4a') || n.endsWith('.wav')) return Icons.audiotrack_rounded;
  return Icons.insert_drive_file_rounded;
}

/// The conversation itself: messages, ticks, photos, files, voice notes, edit, delete, copy and (optionally) a call button.
class ConversationBody extends StatefulWidget {
  final ConversationSource source;
  final List<ThreadMessage> initial;
  final String subtitle;
  final List<String> quick;
  /// With a phone number, a call button shows beside the subtitle.
  final String? callName, callPhone;
  /// Leave room under the box for the floating tab bar (when this sits inside the main tab screen).
  final bool avoidTabBar;
  const ConversationBody({super.key, required this.source, required this.initial, this.subtitle = '', this.quick = const [], this.callName, this.callPhone, this.avoidTabBar = false});
  @override
  State<ConversationBody> createState() => _ConversationBodyState();
}

class _ConversationBodyState extends State<ConversationBody> with WidgetsBindingObserver {
  bool keyboard = false;

  late final List<ThreadMessage> msgs = List.of(widget.initial);
  final input = TextEditingController();
  final scroll = ScrollController();
  bool sending = false;
  double sendProgress = 0;
  bool hasText = false;
  ThreadMessage? editing; // the message being edited, if any
  Timer? _poll;

  // voice recording
  final _rec = AudioRecorder();
  bool recording = false;
  int recMs = 0;
  final _levels = <double>[];
  Timer? _recTimer;
  StreamSubscription<Amplitude>? _ampSub;

  @override
  void didChangeMetrics() {
    final k = View.of(context).viewInsets.bottom > 0;
    if (k != keyboard && mounted) setState(() => keyboard = k);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    input.addListener(() {
      final has = input.text.trim().isNotEmpty;
      if (has != hasText) setState(() => hasText = has);
    });
    // Check for new replies and for ticks changing (sent, delivered, read) every couple of seconds.
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _sync());
  }

  Future<void> _sync() async {
    if (!mounted || recording) return;
    try {
      final fresh = await widget.source.load();
      if (!mounted) return;
      final pending = msgs.where((m) => m.id.startsWith('tmp-')).toList(); // not on the server yet
      setState(() {
        msgs
          ..clear()
          ..addAll(fresh)
          ..addAll(pending);
      });
    } catch (_) {
      // Offline for a moment: keep what is on screen.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _recTimer?.cancel();
    _ampSub?.cancel();
    _rec.dispose();
    input.dispose();
    scroll.dispose();
    super.dispose();
  }

  void _toBottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scroll.hasClients) scroll.animateTo(scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
      });

  /// Sends a text message, or saves the edit when a message is being edited.
  Future<void> _send([String? text]) async {
    final t = (text ?? input.text).trim();
    if (t.isEmpty) return;
    final target = editing;
    if (target != null) {
      await _saveEdit(target, t);
      return;
    }
    final tmp = ThreadMessage(id: 'tmp-${DateTime.now().microsecondsSinceEpoch}', from: 'business', text: t, when: 'just now', status: 'sending');
    setState(() {
      msgs.add(tmp);
      input.clear();
    });
    _toBottom();
    await _deliver(tmp);
  }

  /// Sends a message that is on screen but not on the server yet. Used for the first send and for "tap to retry".
  Future<void> _deliver(ThreadMessage tmp) async {
    setState(() => tmp.status = 'sending');
    try {
      final ThreadMessage m;
      if (tmp.kind == 'text') {
        m = await widget.source.sendText(tmp.text);
      } else {
        m = await widget.source.sendAttachment(kind: tmp.kind, path: tmp.path, name: tmp.fileName, size: tmp.sizeBytes, durationMs: tmp.durationMs, onProgress: (p) {
          if (mounted) setState(() => sendProgress = p);
        });
      }
      if (!mounted) return;
      setState(() {
        final i = msgs.indexOf(tmp);
        if (i >= 0) msgs[i] = m;
        sendProgress = 0;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        tmp.status = 'failed';
        sendProgress = 0;
      });
      showMsg(context, "Couldn't send. Tap the red mark to try again.");
    }
  }

  Future<void> _sendAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0}) async {
    final tmp = ThreadMessage(id: 'tmp-${DateTime.now().microsecondsSinceEpoch}', from: 'business', text: '', when: 'just now', kind: kind, fileName: name, path: path, sizeBytes: size, durationMs: durationMs, status: 'sending');
    setState(() => msgs.add(tmp));
    _toBottom();
    await _deliver(tmp);
  }

  // ------------------------------------------------------------ edit, copy, delete

  void _startEdit(ThreadMessage m) {
    setState(() {
      editing = m;
      input.text = m.text;
      input.selection = TextSelection.collapsed(offset: input.text.length);
    });
  }

  void _cancelEdit() {
    setState(() {
      editing = null;
      input.clear();
    });
  }

  Future<void> _saveEdit(ThreadMessage m, String text) async {
    if (text == m.text) {
      _cancelEdit();
      return;
    }
    final oldText = m.text;
    setState(() {
      m.text = text;
      m.edited = true;
      editing = null;
      input.clear();
    });
    try {
      await widget.source.edit(m.id, text);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        m.text = oldText;
        m.edited = false;
      });
      showMsg(context, "Couldn't save the change. Try again.");
    }
  }

  Future<void> _delete(ThreadMessage m) async {
    final neverSent = m.id.startsWith('tmp-');
    final ok = neverSent ||
        await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: C.surface,
                title: const Text('Delete this message?'),
                content: const Text('It will be removed for everyone in this conversation.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Delete', style: TextStyle(color: C.rec, fontWeight: FontWeight.w800))),
                ],
              ),
            ) ==
            true;
    if (!ok || !mounted) return;
    HapticFeedback.mediumImpact();
    final index = msgs.indexOf(m);
    setState(() {
      msgs.remove(m);
      if (editing == m) {
        editing = null;
        input.clear();
      }
    });
    if (neverSent) return;
    try {
      await widget.source.delete(m.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => msgs.insert(index.clamp(0, msgs.length), m));
      showMsg(context, "Couldn't delete it. Try again.");
    }
  }

  /// Long-press a message: copy, edit (your own text) or delete (your own).
  void _actions(ThreadMessage m) {
    if (m.kind == 'call') return;
    HapticFeedback.mediumImpact();
    final mine = m.from == 'business';
    final canEdit = mine && m.kind == 'text' && m.status != 'sending' && m.status != 'failed';
    Widget item(IconData icon, String label, VoidCallback onTap, {Color? color}) => Pressable(
          onTap: () {
            Navigator.pop(context);
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13),
            child: Row(children: [
              Icon(icon, size: 22, color: color ?? C.text),
              const SizedBox(width: 16),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: color ?? C.text)),
            ]),
          ),
        );
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.kind == 'text')
          item(Icons.copy_rounded, 'Copy', () async {
            await Clipboard.setData(ClipboardData(text: m.text));
            if (mounted) showMsg(context, 'Copied');
          }),
        if (canEdit) item(Icons.edit_rounded, 'Edit', () => _startEdit(m)),
        if (mine) item(Icons.delete_outline_rounded, m.status == 'failed' ? 'Remove' : 'Delete', () => _delete(m), color: C.rec),
        if (!mine && m.kind != 'text') Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Muted('Only the person who sent it can delete this.', size: 13)),
      ]),
    );
  }

  /// Opens the dialer for this person and notes the call in the conversation.
  void _call() {
    callPhone(context, name: widget.callName ?? '', phone: widget.callPhone ?? '', onCalled: () async {
      try {
        final m = await widget.source.logCall();
        if (mounted) {
          setState(() => msgs.add(m));
          _toBottom();
        }
      } catch (_) {}
    });
  }

  // ------------------------------------------------------------ attach

  void _attach() {
    HapticFeedback.selectionClick();
    Widget option(IconData icon, String label, Color color, VoidCallback onTap) => Expanded(
          child: Pressable(
            onTap: () {
              Navigator.pop(context);
              onTap();
            },
            child: Column(children: [
              GlossIcon(icon, color, size: 58),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Attach'),
        const SizedBox(height: 4),
        const Muted('Send a photo, a document or a video.', size: 13),
        const SizedBox(height: 18),
        Row(children: [
          option(Icons.photo_library_rounded, 'Photo or video', const Color(0xFF3E94F5), _pickMedia),
          option(Icons.photo_camera_rounded, 'Camera', const Color(0xFFFF6B5E), _pickCamera),
          option(Icons.insert_drive_file_rounded, 'File', const Color(0xFFFFC21A), _pickFile),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }

  bool _isVideo(String n) {
    final l = n.toLowerCase();
    return l.endsWith('.mp4') || l.endsWith('.mov') || l.endsWith('.m4v') || l.endsWith('.webm');
  }

  Future<void> _pickMedia() async {
    try {
      final f = await ImagePicker().pickMedia();
      if (f == null) return;
      final size = await f.length();
      await _sendAttachment(kind: _isVideo(f.name) ? 'file' : 'image', path: f.path, name: f.name, size: size);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open your photos: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _pickCamera() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
      if (f == null) return;
      await _sendAttachment(kind: 'image', path: f.path, name: f.name, size: await f.length());
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open the camera: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<void> _pickFile() async {
    try {
      final f = await FilePicker.pickFile();
      if (f == null || f.path == null) return;
      final n = f.name.toLowerCase();
      final isImg = n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') || n.endsWith('.webp') || n.endsWith('.gif');
      await _sendAttachment(kind: isImg ? 'image' : 'file', path: f.path!, name: f.name, size: (await f.length()) ?? 0);
    } catch (e) {
      if (mounted) showMsg(context, 'Could not open that file: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  // ------------------------------------------------------------ voice notes

  Future<void> _startRecording() async {
    if (sending || recording) return;
    try {
      if (!await _rec.hasPermission()) {
        if (mounted) showMsg(context, 'Allow the microphone to record a voice note.');
        return;
      }
      final path = '${Directory.systemTemp.path}/viewrec_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _rec.start(const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100), path: path);
      HapticFeedback.mediumImpact();
      setState(() {
        recording = true;
        recMs = 0;
        _levels.clear();
      });
      final started = DateTime.now();
      _recTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (mounted) setState(() => recMs = DateTime.now().difference(started).inMilliseconds);
      });
      _ampSub = _rec.onAmplitudeChanged(const Duration(milliseconds: 110)).listen((a) {
        // -45 dB (quiet) .. 0 dB (loud) -> 0..1
        final v = ((a.current + 45) / 45).clamp(0.0, 1.0);
        if (mounted) setState(() => _levels.add(v));
      });
    } catch (e) {
      if (mounted) showMsg(context, 'Could not start recording: ${e.toString().replaceFirst('Exception: ', '')}');
    }
  }

  Future<String?> _endRecording({required bool keep}) async {
    _recTimer?.cancel();
    await _ampSub?.cancel();
    String? path;
    try {
      if (keep) {
        path = await _rec.stop();
      } else {
        await _rec.cancel();
      }
    } catch (_) {}
    if (mounted) setState(() => recording = false);
    return path;
  }

  Future<void> _sendVoice() async {
    final ms = recMs;
    final path = await _endRecording(keep: true);
    if (path == null || ms < 600) {
      if (mounted && path != null) showMsg(context, 'Hold on a little longer to record a voice note.');
      return;
    }
    final size = await File(path).length();
    await _sendAttachment(kind: 'voice', path: path, name: 'Voice note.m4a', size: size, durationMs: ms);
  }

  Future<void> _cancelVoice() async {
    HapticFeedback.selectionClick();
    await _endRecording(keep: false);
  }

  // ------------------------------------------------------------ bubbles

  /// The small status mark beside the time on messages you sent: clock, one tick, two ticks, two blue ticks.
  Widget _ticks(ThreadMessage m) {
    const blue = Color(0xFF7FDBFF);
    switch (m.status) {
      case 'sending':
        return const Icon(Icons.schedule_rounded, size: 13, color: Colors.white70);
      case 'delivered':
        return const Icon(Icons.done_all_rounded, size: 15, color: Colors.white70);
      case 'read':
        return const Icon(Icons.done_all_rounded, size: 15, color: blue);
      case 'failed':
        return GestureDetector(
          onTap: () => _deliver(m),
          child: const Icon(Icons.error_rounded, size: 16, color: Color(0xFFFF9D92)),
        );
      default: // sent
        return const Icon(Icons.done_rounded, size: 15, color: Colors.white70);
    }
  }

  Widget _callLine(ThreadMessage m) => Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: C.surface2, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.call_made_rounded, size: 13, color: C.green),
            const SizedBox(width: 6),
            Text('${m.text} · ${m.when}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.muted)),
          ]),
        ),
      ).animate().fadeIn(duration: 240.ms);

  Widget _bubble(ThreadMessage m) {
    if (m.kind == 'call') return _callLine(m);
    final mine = m.from == 'business';
    final fg = mine ? Colors.white : C.text;
    final sub = mine ? Colors.white70 : C.muted;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(mine ? 18 : 4),
      bottomRight: Radius.circular(mine ? 4 : 18),
    );
    Widget content;
    switch (m.kind) {
      case 'voice':
        content = _VoiceBubble(path: m.path, durationMs: m.durationMs, mine: mine, key: ValueKey(m.id));
      case 'image':
        content = GestureDetector(
          onTap: () => _viewImage(m),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: (kIsWeb || m.path.startsWith('http')) ? Image.network(m.path, fit: BoxFit.cover) : Image.file(File(m.path), fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: 120, color: C.surface2, child: Icon(Icons.broken_image_rounded, color: C.muted))),
            ),
          ),
        );
      case 'file':
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          GlossIcon(_fileIcon(m.fileName), (mine ? const Color(0xFF6FB0FF) : C.primary), size: 42),
          const SizedBox(width: 10),
          Flexible(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.fileName, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: fg)),
              if (m.sizeBytes > 0) Text(_size(m.sizeBytes), style: TextStyle(fontSize: 11.5, color: sub)),
            ]),
          ),
        ]);
      default:
        content = Text(m.text, style: TextStyle(height: 1.4, fontSize: 14.5, color: fg));
    }
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _actions(m),
        child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        margin: const EdgeInsets.only(bottom: 10),
        padding: EdgeInsets.symmetric(horizontal: m.kind == 'image' ? 6 : 14, vertical: m.kind == 'image' ? 6 : 10),
        decoration: BoxDecoration(
          gradient: mine ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: C.gradBlue) : null,
          color: mine ? null : C.surface,
          border: Border.all(color: mine ? Colors.white.withValues(alpha: 0.3) : (C.dark ? C.border : Colors.white)),
          borderRadius: radius,
          boxShadow: [BoxShadow(color: (mine ? C.primary : const Color(0xFF0B1B3A)).withValues(alpha: mine ? 0.22 : 0.07), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          content,
          const SizedBox(height: 4),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: m.kind == 'image' ? 6 : 0),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (m.edited) Text('edited  ', style: TextStyle(fontSize: 10.5, fontStyle: FontStyle.italic, color: sub)),
              Text(m.status == 'failed' ? 'Not sent' : m.when, style: TextStyle(fontSize: 10.5, color: m.status == 'failed' ? const Color(0xFFFF9D92) : sub)),
              if (mine) ...[const SizedBox(width: 5), AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: KeyedSubtree(key: ValueKey(m.status), child: _ticks(m)))],
            ]),
          ),
        ]),
      ),
      ),
    ).animate(key: ValueKey('b-${m.id}')).fadeIn(duration: 260.ms).slideY(begin: 0.15, end: 0, duration: 300.ms, curve: Curves.easeOut);
  }

  void _viewImage(ThreadMessage m) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, _, __) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Stack(children: [
              Center(
                child: InteractiveViewer(
                  child: (kIsWeb || m.path.startsWith('http')) ? Image.network(m.path) : Image.file(File(m.path)),
                ),
              ),
              Positioned(top: 8, right: 8, child: IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: Colors.white))),
            ]),
          ),
        ),
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  // ------------------------------------------------------------ composer

  Widget _roundButton({required IconData icon, required VoidCallback? onTap, Color? color, Color? iconColor, bool busy = false}) => Material(
        color: color ?? C.primary,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 46,
            height: 46,
            child: busy
                ? const Padding(padding: EdgeInsets.all(13), child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: RotationTransition(turns: Tween(begin: 0.85, end: 1.0).animate(a), child: c)),
                    child: Icon(icon, key: ValueKey(icon), size: 21, color: iconColor ?? Colors.white),
                  ),
          ),
        ),
      );

  Widget _recordingBar() {
    final shown = _levels.length > 30 ? _levels.sublist(_levels.length - 30) : _levels;
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: C.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFE4513F), shape: BoxShape.circle))
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fade(begin: 0.35, end: 1, duration: 700.ms),
        const SizedBox(width: 10),
        Text(_clock(recMs), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, fontFeatures: [FontFeature.tabularFigures()])),
        const SizedBox(width: 12),
        Expanded(
          child: Row(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.center, children: [
            for (final v in shown)
              Container(
                width: 3,
                height: 5 + v * 22,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.4 + v * 0.6), borderRadius: BorderRadius.circular(2)),
              ),
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(children: [
            Expanded(child: Muted(widget.subtitle, size: 12.5)),
            if (widget.callPhone != null) CallButton(onTap: _call),
          ]),
        ),
        Expanded(
          child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 8, 16, 8), children: [
            for (final m in msgs) _bubble(m),
          ]),
        ),
        if (sendProgress > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: sendProgress, minHeight: 3, color: C.primary, backgroundColor: C.border)),
          ),
        if (widget.quick.isNotEmpty)
        AnimatedSize(
          duration: kMed,
          curve: kCurve,
          child: recording
              ? const SizedBox(width: double.infinity)
              : SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
                    for (final q in widget.quick)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(q, style: const TextStyle(fontSize: 12.5)),
                          backgroundColor: C.surface,
                          side: BorderSide(color: C.border),
                          onPressed: editing != null ? null : () => _send(q),
                        ),
                      ),
                  ]),
                ),
        ),
        AnimatedSize(
          duration: kMed,
          curve: kCurve,
          child: editing == null
              ? const SizedBox(width: double.infinity)
              : Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
                  child: Row(children: [
                    Icon(Icons.edit_rounded, size: 16, color: C.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Editing message', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: C.primary))),
                    IconButton(onPressed: _cancelEdit, icon: Icon(Icons.close_rounded, size: 20, color: C.muted), visualDensity: VisualDensity.compact),
                  ]),
                ),
        ),
        Container(
          padding: EdgeInsets.fromLTRB(10, 8, 12, widget.avoidTabBar && !keyboard ? 112 : 12),
          decoration: BoxDecoration(color: C.surface, border: Border(top: BorderSide(color: C.border))),
          child: Row(children: [
            if (recording)
              _roundButton(icon: Icons.delete_outline_rounded, onTap: _cancelVoice, color: C.surface2, iconColor: const Color(0xFFE4513F))
            else
              _roundButton(icon: Icons.attach_file_rounded, onTap: editing != null ? null : _attach, color: C.surface2, iconColor: C.text),
            const SizedBox(width: 8),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: recording
                    ? KeyedSubtree(key: const ValueKey('rec'), child: _recordingBar())
                    : TextField(
                        key: const ValueKey('field'),
                        controller: input,
                        onSubmitted: (_) => _send(),
                        textCapitalization: TextCapitalization.sentences,
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
            ),
            const SizedBox(width: 8),
            if (recording)
              _roundButton(icon: Icons.arrow_upward_rounded, onTap: _sendVoice)
            else if (editing != null)
              _roundButton(icon: Icons.check_rounded, onTap: hasText ? _send : null)
            else if (hasText)
              _roundButton(icon: Icons.arrow_upward_rounded, onTap: _send)
            else
              _roundButton(icon: Icons.mic_rounded, onTap: _startRecording),
          ]),
        ),
      ]);
}

/// A voice note: play or pause, a waveform that fills as it plays, and its length.
class _VoiceBubble extends StatefulWidget {
  final String path;
  final int durationMs;
  final bool mine;
  const _VoiceBubble({super.key, required this.path, required this.durationMs, required this.mine});
  @override
  State<_VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<_VoiceBubble> {
  VideoPlayerController? _c;
  bool playing = false;
  double progress = 0;
  late final List<double> _bars = _makeBars();

  List<double> _makeBars() {
    final r = math.Random(widget.path.hashCode);
    return [for (var i = 0; i < 30; i++) 0.25 + r.nextDouble() * 0.75];
  }

  @override
  void dispose() {
    _c?.removeListener(_tick);
    _c?.dispose();
    super.dispose();
  }

  void _tick() {
    final c = _c;
    if (c == null || !mounted) return;
    final total = c.value.duration.inMilliseconds;
    final p = total == 0 ? 0.0 : (c.value.position.inMilliseconds / total).clamp(0.0, 1.0);
    final done = c.value.isCompleted || (total > 0 && c.value.position.inMilliseconds >= total - 50);
    if (done) {
      c.pause();
      c.seekTo(Duration.zero);
      setState(() {
        playing = false;
        progress = 0;
      });
    } else {
      setState(() {
        playing = c.value.isPlaying;
        progress = p;
      });
    }
  }

  Future<void> _toggle() async {
    HapticFeedback.selectionClick();
    try {
      var c = _c;
      if (c == null) {
        c = (kIsWeb || widget.path.startsWith('http')) ? VideoPlayerController.networkUrl(Uri.parse(widget.path)) : VideoPlayerController.file(File(widget.path));
        await c.initialize();
        c.addListener(_tick);
        _c = c;
      }
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
      if (mounted) setState(() => playing = c!.value.isPlaying);
    } catch (_) {
      if (mounted) showMsg(context, 'Could not play this voice note');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.mine ? Colors.white : C.primary;
    final rest = widget.mine ? Colors.white38 : C.border;
    final left = playing && _c != null ? Duration(milliseconds: (widget.durationMs * (1 - progress)).round()) : Duration(milliseconds: widget.durationMs);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: _toggle,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: (widget.mine ? Colors.white : C.primary).withValues(alpha: 0.2), shape: BoxShape.circle),
          child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, key: ValueKey(playing), color: fg, size: 24)),
        ),
      ),
      const SizedBox(width: 10),
      SizedBox(
        width: 120,
        height: 30,
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          for (var i = 0; i < _bars.length; i++)
            Expanded(
              child: Center(
                child: Container(
                  width: 2.4,
                  height: 6 + _bars[i] * 20,
                  decoration: BoxDecoration(color: i / _bars.length <= progress && playing ? fg : (progress > 0 && i / _bars.length <= progress ? fg : rest), borderRadius: BorderRadius.circular(2)),
                ),
              ),
            ),
        ]),
      ),
      const SizedBox(width: 8),
      Text(_clock(left.inMilliseconds), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: widget.mine ? Colors.white70 : C.muted)),
    ]);
  }
}
