import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../async_view.dart';
import '../liquid_widgets.dart';
import '../motion.dart';
import '../theme.dart';
import '../web_data.dart';
import '../widgets.dart';

String fmtBytes(int b) {
  if (b < 1024) return '$b B';
  if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(0)} KB';
  if (b < 1024 * 1024 * 1024) return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  return '${(b / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

/// Gallery: the business's own videos, pictures and documents, in folders. 100 MB a file, 2 GB in all.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});
  @override
  Widget build(BuildContext context) => AsyncView<(List<GalleryFolder>, List<GalleryItem>)>(
        load: () async => (await webRepo.galleryFolders(), await webRepo.galleryItems()),
        builder: (context, data, refresh) => RefreshIndicator(color: C.primary, onRefresh: refresh, child: _GalleryBody(folders: data.$1, items: data.$2)),
      );
}

class _GalleryBody extends StatefulWidget {
  final List<GalleryFolder> folders;
  final List<GalleryItem> items;
  const _GalleryBody({required this.folders, required this.items});
  @override
  State<_GalleryBody> createState() => _GalleryBodyState();
}

class _GalleryBodyState extends State<_GalleryBody> {
  late final folders = List.of(widget.folders);
  late final items = List.of(widget.items);
  String? folder; // null = everything
  bool busy = false;

  int get used => items.fold(0, (a, i) => a + i.bytes);

  Future<void> _add(String name, String path, int bytes) async {
    if (bytes > kGalleryFileLimit) {
      showMsg(context, '$name is ${fmtBytes(bytes)}. Files can be up to 100 MB.');
      return;
    }
    if (used + bytes > kGalleryTotalLimit) {
      showMsg(context, 'Your gallery is full (2 GB). Delete something first.');
      return;
    }
    final lower = name.toLowerCase();
    final kind = ['.mp4', '.mov', '.m4v', '.webm'].any(lower.endsWith) ? 'video' : ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.heic'].any(lower.endsWith) ? 'image' : 'document';
    setState(() => busy = true);
    try {
      final it = await webRepo.addGalleryItem(name: name, kind: kind, bytes: bytes, path: path, folderId: folder);
      if (mounted) setState(() => items.insert(0, it));
    } catch (e) {
      if (mounted) showMsg(context, e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _upload() {
    Widget opt(IconData icon, String label, Color c, Future<void> Function() go) => Expanded(
          child: Pressable(
            onTap: () {
              Navigator.pop(context);
              go();
            },
            child: Column(children: [
              GlossIcon(icon, c, size: 58),
              const SizedBox(height: 8),
              Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          ),
        );
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('Add to gallery'),
        const SizedBox(height: 4),
        const Muted('Up to 100 MB a file, 2 GB in all.', size: 13),
        const SizedBox(height: 18),
        Row(children: [
          opt(Icons.photo_library_rounded, 'Photo or video', const Color(0xFF3E94F5), () async {
            final f = await ImagePicker().pickMedia();
            if (f != null) await _add(f.name, f.path, await f.length());
          }),
          opt(Icons.insert_drive_file_rounded, 'Document', const Color(0xFFFFC21A), () async {
            final f = await FilePicker.pickFile();
            if (f != null && f.path != null) await _add(f.name, f.path!, (await f.length()) ?? 0);
          }),
        ]),
        const SizedBox(height: 8),
      ]),
    );
  }

  Future<void> _newFolder() async {
    final c = TextEditingController();
    await showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const H2('New folder'),
        const SizedBox(height: 14),
        Field('Folder name', controller: c, hint: 'Summer jobs'),
        AppButton('Create folder', small: true, onTap: () async {
          final name = c.text.trim();
          if (name.isEmpty) return;
          Navigator.pop(context);
          final f = await webRepo.createGalleryFolder(name);
          if (mounted) setState(() => folders.add(f));
        }),
      ]),
    );
  }

  void _open(GalleryItem it) {
    showSheet(
      context,
      Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 4),
        Muted('${fmtBytes(it.bytes)} · ${it.when}', size: 13),
        const SizedBox(height: 14),
        Text('Move to', style: TextStyle(color: C.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 8),
        Wrap(runSpacing: 8, children: [
          AppChip('No folder', active: it.folderId == null, onTap: () => _move(it, null)),
          for (final f in folders) AppChip(f.name, active: it.folderId == f.id, onTap: () => _move(it, f.id)),
        ]),
        const SizedBox(height: 14),
        AppButton('Delete', icon: Icons.delete_outline_rounded, small: true, style: BtnStyle.danger, onTap: () async {
          Navigator.pop(context);
          setState(() => items.remove(it));
          try {
            await webRepo.deleteGalleryItem(it.id);
          } catch (_) {
            if (mounted) {
              setState(() => items.insert(0, it));
              showMsg(context, "Couldn't delete it. Try again.");
            }
          }
        }),
      ]),
    );
  }

  Future<void> _move(GalleryItem it, String? id) async {
    Navigator.pop(context);
    setState(() => it.folderId = id);
    await webRepo.moveGalleryItem(it.id, id);
  }

  Widget _thumb(GalleryItem it) {
    final colors = switch (it.kind) { 'video' => [const Color(0xFF0A2E66), const Color(0xFF0B5FC4)], 'image' => [const Color(0xFF0F9F78), const Color(0xFF1FC9A4)], _ => [const Color(0xFFF2A100), const Color(0xFFFFC21A)] };
    final icon = switch (it.kind) { 'video' => Icons.play_circle_fill_rounded, 'image' => Icons.image_rounded, _ => Icons.description_rounded };
    final p = it.path;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors))),
        if (it.kind == 'image' && p != null && !kIsWeb) Image.file(File(p), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        if (it.kind != 'image' || p == null) Center(child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 30)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withValues(alpha: 0.65)])),
            child: Text(it.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shown = items.where((i) => folder == null || i.folderId == folder).toList();
    return AppPage(reveal: false, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${fmtBytes(used)} of 2 GB used', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
            Muted('${items.length} files', size: 12.5),
          ]),
          const SizedBox(height: 10),
          LiquidProgress(value: used / kGalleryTotalLimit, minHeight: 8, backgroundColor: C.surface2, color: C.primary),
        ]),
      ).reveal(context, 0),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: AppButton('Add files', icon: Icons.upload_rounded, small: true, loading: busy, onTap: _upload)),
        const SizedBox(width: 8),
        Expanded(child: AppButton('New folder', icon: Icons.create_new_folder_rounded, small: true, style: BtnStyle.ghost, onTap: _newFolder)),
      ]).reveal(context, 1),
      const SizedBox(height: 14),
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          AppChip('All', active: folder == null, onTap: () => setState(() => folder = null)),
          for (final f in folders) AppChip(f.name, active: folder == f.id, onTap: () => setState(() => folder = f.id)),
        ]),
      ),
      const SizedBox(height: 10),
      if (shown.isEmpty)
        const EmptyState(Icons.photo_library_rounded, 'Nothing here yet', 'Add videos, pictures and documents to use in your posts.')
      else
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: [for (var i = 0; i < shown.length; i++) Pressable(onTap: () => _open(shown[i]), scale: 0.95, child: _thumb(shown[i])).reveal(context, 2 + i, 0.06)],
        ),
    ]);
  }
}
