import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../liquid_widgets.dart';
import '../repo.dart';
import '../data.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// A testimonial opened: the video, the facts about it, how it was captured, what was said (you can correct it),
/// and where to post it. Nothing is posted until you press the button.
class VideoDetailScreen extends StatefulWidget {
  final Video video;
  const VideoDetailScreen({super.key, required this.video});
  @override
  State<VideoDetailScreen> createState() => _VideoDetailScreenState();
}

class _VideoDetailScreenState extends State<VideoDetailScreen> {
  late bool approved = widget.video.status != 'pending';
  late final transcript = TextEditingController(text: widget.video.transcript);
  late final caption = TextEditingController(text: '"${widget.video.quote}"\n\n- ${widget.video.name}, customer of Hartley Roofing');
  late String savedTranscript = widget.video.transcript;
  Map<String, String> accounts = {};
  List<PublishDestination> destinations = [];
  final chosen = <String>{};
  bool posting = false, savingTranscript = false;

  Video get v => widget.video;
  String get link => 'https://viewrec.com/t/${v.id}';
  int get words => transcript.text.trim().isEmpty ? 0 : transcript.text.trim().split(RegExp(r'\s+')).length;

  @override
  void initState() {
    super.initState();
    repo.accounts().then((a) {
      if (mounted) setState(() => accounts = a);
    }).catchError((_) {});
    webRepo.destinations().then((d) {
      if (mounted) setState(() => destinations = d);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    transcript.dispose();
    caption.dispose();
    super.dispose();
  }

  Future<void> _saveTranscript() async {
    setState(() => savingTranscript = true);
    try {
      await repo.updateVideo(v.id, transcript: transcript.text.trim());
      if (mounted) {
        setState(() => savedTranscript = transcript.text.trim());
        showMsg(context, 'Transcript saved');
      }
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't save the transcript. Try again.");
    } finally {
      if (mounted) setState(() => savingTranscript = false);
    }
  }

  Future<void> _post(List<String> where) async {
    setState(() => posting = true);
    try {
      await repo.updateVideo(v.id, status: 'published', platforms: where);
      if (!mounted) return;
      setState(() => v.status = 'published');
      showSuccess(context, 'Posted to ${where.join(', ')}');
    } catch (_) {
      if (mounted) showMsg(context, "Couldn't post it. Try again.");
    } finally {
      if (mounted) setState(() => posting = false);
    }
  }

  Widget _row(String label, Widget value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 108, child: Text(label, style: TextStyle(color: C.muted, fontSize: 13.5, fontWeight: FontWeight.w600))),
          Expanded(child: value),
        ]),
      );

  Widget _bullets(List<String> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final s in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 7, right: 8), child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: C.muted))),
              Expanded(child: Text(s, style: const TextStyle(fontSize: 13.5, height: 1.4))),
            ]),
          ),
      ]);

  Widget _capture() {
    if (v.captureVerified) {
      return AppCard(
        child: Row(children: [
          Icon(Icons.verified_user_rounded, size: 26, color: C.green),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Verified capture', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              SizedBox(height: 2),
              Muted('Recorded in one session, with permission given on the page.', size: 13),
            ]),
          ),
        ]),
      );
    }
    return AppCard(
      borderColor: C.amber.withValues(alpha: 0.5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.info_outline_rounded, size: 24, color: C.amber),
          const SizedBox(width: 10),
          const Expanded(child: Text('Capture not verified', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        ]),
        const SizedBox(height: 6),
        const Muted('Something about the capture did not line up. Nothing was rejected. This is here to be looked at.', size: 13),
        if (v.captureSignals.isNotEmpty) ...[const SizedBox(height: 10), _bullets(v.captureSignals)],
        const SizedBox(height: 6),
        const Muted('Most of this is reported by the browser and could be wrong. The session timing is measured on our side.', size: 12.5),
        if (v.captureNotes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Worth a look', style: TextStyle(fontWeight: FontWeight.w800, color: C.amber)),
          const SizedBox(height: 6),
          _bullets(v.captureNotes),
          const SizedBox(height: 6),
          const Muted('A shared network is often a household, an office or a phone carrier. It is not the same person. Nothing was hidden or rejected because of this.', size: 12.5),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fb = accounts.containsKey('fb');
    final changed = transcript.text.trim() != savedTranscript;
    return Scaffold(
      body: AppPage(reveal: false, children: [
        const BackHeader('Testimonial', trailing: Icon(Icons.ios_share_rounded, size: 22)),
        Hero(tag: 'video_${v.id}', child: VideoThumb(hue: v.hue, duration: v.duration, height: 240)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
              const SizedBox(height: 2),
              Muted(v.job, size: 13),
            ]),
          ),
          StatusBadge(approved && v.status == 'pending' ? 'approved' : v.status),
        ]),
        const SizedBox(height: 16),
        AppCard(
          child: Column(children: [
            _row('Type', Text(v.written ? 'Written' : 'Video', style: const TextStyle(fontWeight: FontWeight.w600))),
            _row('Template', Text(v.template, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (v.submitted.isNotEmpty) _row('Submitted', Text(v.submitted, style: const TextStyle(fontWeight: FontWeight.w600))),
            if (v.duration.isNotEmpty) _row('Duration', Text(v.duration, style: const TextStyle(fontWeight: FontWeight.w600))),
            _row('Consent given', Wrap(spacing: 6, runSpacing: 6, children: [
              for (final c in v.consent)
                Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: C.green.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)), child: Text(c, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.green))),
            ])),
          ]),
        ),
        const SizedBox(height: 14),
        _capture(),
        const SectionHeader('What the AI found'),
        AppCard(child: Muted(v.aiSummary.isNotEmpty ? v.aiSummary : (v.transcript.trim().isEmpty ? 'Nothing to analyse. No speech was detected, or AI is switched off.' : 'Not analysed yet.'), size: 14)),
        const SectionHeader('Transcript'),
        AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$words words', style: TextStyle(fontWeight: FontWeight.w700, color: C.muted)),
            const SizedBox(height: 2),
            const Muted('What was actually said. Correct it before approving if the model misheard.', size: 13),
            const SizedBox(height: 10),
            Field('Transcript', controller: transcript, lines: 4, onChanged: (_) => setState(() {})),
            if (changed) AppButton(savingTranscript ? 'Saving…' : 'Save transcript', small: true, loading: savingTranscript, onTap: savingTranscript ? null : _saveTranscript),
          ]),
        ),
        if (!approved) ...[
          const SizedBox(height: 16),
          AppButton('Approve video', icon: Icons.check_rounded, onTap: () {
            setState(() => approved = true);
            repo.updateVideo(v.id, status: 'approved').catchError((_) {});
          }),
          const SizedBox(height: 8),
          AppButton('Request a re-record', style: BtnStyle.ghost, onTap: () => showMsg(context, 'Re-record request sent')),
        ] else ...[
          const SectionHeader('Post it'),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (fb) ...[
                Row(children: [
                  Icon(Icons.check_circle_rounded, size: 20, color: C.green),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Your Facebook Page is connected', style: TextStyle(fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 4),
                const Muted('This posts the video and its caption straight to your Page. Nothing else happens until you press it.', size: 13),
                const SizedBox(height: 12),
                Field('The caption', controller: caption, lines: 4),
                Row(children: [
                  Expanded(child: Muted(link, size: 12.5, maxLines: 1)),
                  IconButton(
                    tooltip: 'Copy the link',
                    icon: Icon(Icons.copy_rounded, size: 18, color: C.muted),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: link));
                      if (mounted) showMsg(context, 'Link copied');
                    },
                  ),
                ]),
                const Muted('What is posted is this testimonial\'s own page, so the preview shows the video and it plays from there.', size: 12.5),
                const SizedBox(height: 12),
                AppButton(posting ? 'Posting…' : 'Post to Facebook Page', icon: Icons.rocket_launch_rounded, loading: posting, onTap: posting ? null : () => _post(['Facebook'])),
              ] else
                const Muted('No account connected yet. Connect Facebook or Instagram under Connected accounts and you can post from here.', size: 13),
            ]),
          ),
          const SectionHeader('Publish'),
          AppCard(
            child: destinations.isEmpty
                ? const Muted('No destinations yet. Add one under Publishing, then Where they go, and you can send this there.', size: 13)
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Muted('You choose each one. Nothing goes out on its own.', size: 13),
                    const SizedBox(height: 8),
                    for (final d in destinations)
                      Row(children: [
                        Icon(d.isWebsite ? Icons.language_rounded : Icons.edit_note_rounded, size: 20, color: C.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(d.name, style: const TextStyle(fontSize: 15)))),
                        LiquidSwitch(value: chosen.contains(d.id), onChanged: (x) => setState(() => x ? chosen.add(d.id) : chosen.remove(d.id))),
                      ]),
                    const SizedBox(height: 10),
                    AppButton('Publish to ${chosen.length} ${chosen.length == 1 ? 'destination' : 'destinations'}', icon: Icons.send_rounded, small: true, onTap: chosen.isEmpty || posting ? null : () => _post([for (final d in destinations) if (chosen.contains(d.id)) d.name])),
                  ]),
          ),
        ],
        const SizedBox(height: 120),
      ]),
    );
  }
}
