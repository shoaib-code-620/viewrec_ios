import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../async_view.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

/// Business verification: documents are checked by ViewRec and a blue tick opens posting your own media.
class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<Verification>(
        load: webRepo.verification,
        builder: (context, v, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _VerificationBody(v: v)),
      );
}

class _VerificationBody extends StatefulWidget {
  final Verification v;
  const _VerificationBody({required this.v});
  @override
  State<_VerificationBody> createState() => _VerificationBodyState();
}

class _VerificationBodyState extends State<_VerificationBody> {
  late Verification v = widget.v;
  bool busy = false;

  Future<void> _send(String name, String path) async {
    setState(() => busy = true);
    try {
      final next = await webRepo.uploadVerificationDoc(name: name, path: path);
      if (mounted) {
        setState(() => v = next);
        showSuccess(context, 'Document sent');
      }
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _add() {
    Widget opt(IconData icon, String label, Color c, Future<void> Function() go) => Expanded(
          child: Pressable(
            onTap: () {
              Navigator.pop(context);
              go();
            },
            child: Column(children: [
              GlossIcon(icon, c, size: 58),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Add a document'),
        const SizedBox(height: 18),
        Row(children: [
          opt(Icons.photo_camera_rounded, 'Take a photo', const Color(0xFFFF6B5E), () async {
            final f = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 88);
            if (f != null) await _send(f.name, f.path);
          }),
          opt(Icons.insert_drive_file_rounded, 'Choose a file', const Color(0xFFFFC21A), () async {
            final f = await FilePicker.pickFile();
            if (f != null && f.path != null) await _send(f.name, f.path!);
          }),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String title, String body) = switch (v.status) {
      'verified' => (Icons.verified_rounded, C.blue, 'Verified business', 'Your blue tick is on. You can post your own photos and videos to social accounts.'),
      'in_review' => (Icons.hourglass_top_rounded, C.amber, 'In review', v.note.isEmpty ? 'A ViewRec reviewer is checking your documents.' : v.note),
      'rejected' => (Icons.error_rounded, C.rec, 'Not approved yet', v.note.isEmpty ? 'We could not confirm your business from those documents. Send clearer ones.' : v.note),
      _ => (Icons.shield_outlined, C.muted, 'Not verified', 'Send a document that shows your business name, and ViewRec will check it. Posting your own media needs a verified business.'),
    };
    return AppPage(reveal: false, children: [
      AppCard(
        child: Column(children: [
          Container(width: 76, height: 76, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.14)), child: Icon(icon, size: 40, color: color))
              .animate(key: ValueKey(v.status))
              .scale(begin: const Offset(0.6, 0.6), end: const Offset(1, 1), duration: 520.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19)),
          const SizedBox(height: 6),
          Muted(body, size: 13.5, align: TextAlign.center),
        ]),
      ).reveal(context, 0),
      if (v.status != 'verified') ...[
        const SizedBox(height: 14),
        AppButton('Add a document', icon: Icons.upload_file_rounded, loading: busy, onTap: _add).reveal(context, 1),
        const SectionHeader('What we accept'),
        AppCard(
          child: Column(children: const [
            Tile(icon: Icons.business_center_rounded, title: 'Business registration', subtitle: 'Certificate of incorporation or company number'),
            Tile(icon: Icons.receipt_long_rounded, title: 'Tax or VAT letter', subtitle: 'Shows your trading name and address'),
            Tile(icon: Icons.shield_rounded, title: 'Insurance certificate', subtitle: 'Public liability or similar', divider: false),
          ]),
        ).reveal(context, 2),
      ],
      if (v.docs.isNotEmpty) ...[
        const SectionHeader('Your documents'),
        for (var i = 0; i < v.docs.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(Icons.description_rounded, color: C.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(v.docs[i].name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Muted(v.docs[i].when, size: 12),
                  ]),
                ),
                StatusBadge(v.docs[i].status == 'approved' ? 'approved' : v.docs[i].status == 'rejected' ? 'skipped' : 'pending'),
              ]),
            ),
          ).reveal(context, 3 + i, 0.08),
      ],
      const SizedBox(height: 80),
    ]);
  }
}
