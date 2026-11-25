import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import 'repo.dart';

// ---------------------------------------------------------------------------
// Features that the ViewRec website already has and the app now has too:
// Gallery, contact bundles, calendar, review templates, business verification,
// review access requests, referrals, video settings, embeds, support chat,
// security, marketing email and workspaces.
// While the real API is not connected, [MockWebRepo] keeps everything in memory.
// ---------------------------------------------------------------------------

// ---------------- models

class GalleryFolder {
  final String id;
  String name;
  GalleryFolder(this.id, this.name);
  factory GalleryFolder.fromJson(Map<String, dynamic> j) => GalleryFolder('${j['id']}', j['name'] ?? '');
}

class GalleryItem {
  final String id, name, kind, when; // kind: image | video | document
  final int bytes;
  String? folderId;
  final String? path; // a file on this phone (sample mode) or a web address
  GalleryItem({required this.id, required this.name, required this.kind, required this.bytes, this.folderId, this.path, this.when = 'just now'});
  factory GalleryItem.fromJson(Map<String, dynamic> j) => GalleryItem(
        id: '${j['id']}',
        name: j['name'] ?? '',
        kind: j['kind'] ?? 'document',
        bytes: j['bytes'] ?? 0,
        folderId: j['folderId']?.toString(),
        path: j['url'],
        when: j['when'] ?? '',
      );
}

/// Limits the website enforces on the gallery.
const kGalleryFileLimit = 100 * 1024 * 1024; // 100 MB a file
const kGalleryTotalLimit = 2 * 1024 * 1024 * 1024; // 2 GB a business

/// One line of subtitles: shown from [startMs] to [endMs].
class CaptionLine {
  int startMs, endMs;
  String text;
  CaptionLine({required this.startMs, required this.endMs, required this.text});
  factory CaptionLine.fromJson(Map<String, dynamic> j) => CaptionLine(
        startMs: (j['startMs'] ?? 0).toInt(),
        endMs: (j['endMs'] ?? 0).toInt(),
        text: j['text'] ?? '',
      );
  Map<String, dynamic> toJson() => {'startMs': startMs, 'endMs': endMs, 'text': text};
}

class Bundle {
  final String id;
  String name;
  List<String> memberIds;
  String lastSent;
  Bundle({required this.id, required this.name, required this.memberIds, this.lastSent = 'Never sent'});
  factory Bundle.fromJson(Map<String, dynamic> j) => Bundle(
        id: '${j['id']}',
        name: j['name'] ?? '',
        memberIds: [for (final m in (j['memberIds'] as List? ?? [])) '$m'],
        lastSent: j['lastSent'] ?? 'Never sent',
      );
}

class CalendarEvent {
  final String id, title, who;
  final DateTime date;
  final String kind; // invite | reminder | automation | bundle
  const CalendarEvent({required this.id, required this.date, required this.title, required this.kind, this.who = ''});
  factory CalendarEvent.fromJson(Map<String, dynamic> j) => CalendarEvent(
        id: '${j['id']}',
        date: DateTime.tryParse(j['date'] ?? '') ?? DateTime.now(),
        title: j['title'] ?? '',
        kind: j['kind'] ?? 'invite',
        who: j['who'] ?? '',
      );
}

class ReviewTemplate {
  final String id;
  String name;
  List<String> questions;
  bool isDefault;
  ReviewTemplate({required this.id, required this.name, required this.questions, this.isDefault = false});
  factory ReviewTemplate.fromJson(Map<String, dynamic> j) => ReviewTemplate(
        id: '${j['id']}',
        name: j['name'] ?? '',
        questions: [for (final q in (j['questions'] as List? ?? [])) '$q'],
        isDefault: j['isDefault'] == true,
      );
}

class VerificationDoc {
  final String id, name, when;
  String status; // pending | approved | rejected
  VerificationDoc({required this.id, required this.name, required this.status, this.when = 'just now'});
  factory VerificationDoc.fromJson(Map<String, dynamic> j) => VerificationDoc(id: '${j['id']}', name: j['name'] ?? '', status: j['status'] ?? 'pending', when: j['when'] ?? '');
}

class Verification {
  String status; // none | in_review | verified | rejected
  String note;
  final List<VerificationDoc> docs;
  Verification({required this.status, this.note = '', required this.docs});
  factory Verification.fromJson(Map<String, dynamic> j) => Verification(
        status: j['status'] ?? 'none',
        note: j['note'] ?? '',
        docs: [for (final d in (j['docs'] as List? ?? [])) VerificationDoc.fromJson(d)],
      );
}

class ReviewAccessRequest {
  final String id, name, email, message, when;
  String status; // pending | approved | declined
  ReviewAccessRequest({required this.id, required this.name, required this.email, required this.message, required this.when, this.status = 'pending'});
  factory ReviewAccessRequest.fromJson(Map<String, dynamic> j) => ReviewAccessRequest(
        id: '${j['id']}',
        name: j['name'] ?? '',
        email: j['email'] ?? '',
        message: j['message'] ?? '',
        when: j['when'] ?? '',
        status: j['status'] ?? 'pending',
      );
}

class Referred {
  final String name, status, when; // status: signed up | paid
  final int creditCents;
  const Referred({required this.name, required this.status, required this.creditCents, required this.when});
  factory Referred.fromJson(Map<String, dynamic> j) => Referred(name: j['name'] ?? '', status: j['status'] ?? 'signed up', creditCents: j['creditCents'] ?? 0, when: j['when'] ?? '');
}

class ReferralInfo {
  final String link, code;
  final int creditCents;
  final List<Referred> referred;
  const ReferralInfo({required this.link, required this.code, required this.creditCents, required this.referred});
  factory ReferralInfo.fromJson(Map<String, dynamic> j) => ReferralInfo(
        link: j['link'] ?? '',
        code: j['code'] ?? '',
        creditCents: j['creditCents'] ?? 0,
        referred: [for (final r in (j['referred'] as List? ?? [])) Referred.fromJson(r)],
      );
}

class VideoSettings {
  bool subtitles, watermark;
  VideoSettings({required this.subtitles, required this.watermark});
  factory VideoSettings.fromJson(Map<String, dynamic> j) => VideoSettings(subtitles: j['subtitles'] == true, watermark: j['watermark'] != false);
  Map<String, dynamic> toJson() => {'subtitles': subtitles, 'watermark': watermark};
}

class EmbedItem {
  final String id, name, layout, created; // layout: wall | carousel
  final int count;
  const EmbedItem({required this.id, required this.name, required this.layout, required this.count, required this.created});
  factory EmbedItem.fromJson(Map<String, dynamic> j) => EmbedItem(id: '${j['id']}', name: j['name'] ?? '', layout: j['layout'] ?? 'wall', count: j['count'] ?? 0, created: j['created'] ?? '');

  /// The snippet a business pastes into their own website.
  String get code => '<script src="https://viewrec.com/api/embed/$id" async></script>';
}

class SignedInDevice {
  final String id, device, place, when;
  final bool current;
  const SignedInDevice({required this.id, required this.device, required this.place, required this.when, this.current = false});
  factory SignedInDevice.fromJson(Map<String, dynamic> j) => SignedInDevice(id: '${j['id']}', device: j['device'] ?? '', place: j['place'] ?? '', when: j['when'] ?? '', current: j['current'] == true);
}

class SecurityInfo {
  bool twoFactor;
  final List<SignedInDevice> devices;
  SecurityInfo({required this.twoFactor, required this.devices});
  factory SecurityInfo.fromJson(Map<String, dynamic> j) => SecurityInfo(twoFactor: j['twoFactor'] == true, devices: [for (final d in (j['devices'] as List? ?? [])) SignedInDevice.fromJson(d)]);
}

class Workspace {
  final String id, name, role; // role: Owner | Admin | Member
  bool current;
  Workspace({required this.id, required this.name, required this.role, this.current = false});
  factory Workspace.fromJson(Map<String, dynamic> j) => Workspace(id: '${j['id']}', name: j['name'] ?? '', role: j['role'] ?? 'Member', current: j['current'] == true);
}

class MarketingResult {
  final int sent, excluded;
  const MarketingResult(this.sent, this.excluded);
}

// ---------------- the interface

abstract class WebRepo {
  Future<List<GalleryFolder>> galleryFolders();
  Future<List<GalleryItem>> galleryItems();
  Future<GalleryItem> addGalleryItem({required String name, required String kind, required int bytes, required String path, String? folderId});
  Future<void> deleteGalleryItem(String id);
  Future<void> moveGalleryItem(String id, String? folderId);
  Future<GalleryFolder> createGalleryFolder(String name);

  Future<List<Bundle>> bundles();
  /// Turn the speech in a recorded video into timed caption lines. [script] is the planned wording, if any.
  Future<List<CaptionLine>> transcribeVideo(String path, {required int durationMs, String script = ''});
  /// Write a short video script with AI. [tone] is friendly, professional or punchy.
  Future<String> writeScript({required String topic, String tone = 'friendly', String business = ''});
  Future<Bundle> saveBundle({String? id, required String name, required List<String> memberIds});
  Future<void> deleteBundle(String id);
  Future<void> sendBundle(String id, {required String subject, required String body});

  Future<List<CalendarEvent>> calendarEvents(DateTime month);

  Future<List<ReviewTemplate>> templates();
  Future<ReviewTemplate> saveTemplate({String? id, required String name, required List<String> questions});
  Future<void> deleteTemplate(String id);
  Future<void> setDefaultTemplate(String id);

  Future<Verification> verification();
  Future<Verification> uploadVerificationDoc({required String name, required String path});

  Future<List<ReviewAccessRequest>> reviewRequests();
  Future<void> decideReviewRequest(String id, {required bool approve});

  Future<ReferralInfo> referrals();

  Future<VideoSettings> videoSettings();
  Future<void> saveVideoSettings(VideoSettings s);

  Future<List<EmbedItem>> embeds();
  Future<EmbedItem> createEmbed({required String name, required String layout, required int count});
  Future<void> deleteEmbed(String id);

  // Support is a conversation like the Inbox: text, photos, files, voice notes, ticks, edit and delete.
  // You are the 'business' side and the ViewRec team is the 'customer' side, so the same message type is used.
  Future<List<ThreadMessage>> supportThread();
  Future<ThreadMessage> sendSupportMessage(String text);
  Future<ThreadMessage> sendSupportAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress});
  Future<ThreadMessage> editSupportMessage(String messageId, String text);
  Future<void> deleteSupportMessage(String messageId);

  Future<SecurityInfo> security();
  Future<void> setTwoFactor(bool on);
  Future<void> revokeDevice(String id);
  Future<void> signOutOtherDevices();
  Future<void> changePassword({required String current, required String next});
  Future<void> requestDataExport();
  Future<void> requestAccountDeletion();

  Future<List<Workspace>> workspaces();
  Future<void> switchWorkspace(String id);

  Future<MarketingResult> sendMarketingEmail({required String subject, required String body, required String audience});
}

// ---------------- sample-data version

class MockWebRepo implements WebRepo {
  static const _lag = Duration(milliseconds: 380);
  Future<T> _w<T>(T v) async {
    await Future<void>.delayed(_lag);
    return v;
  }

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  // gallery
  final _folders = [GalleryFolder('f1', 'Roof jobs'), GalleryFolder('f2', 'Team photos')];
  final _items = [
    GalleryItem(id: 'g1', name: 'Skylight install.mp4', kind: 'video', bytes: 48 * 1024 * 1024, folderId: 'f1', when: '3 days ago'),
    GalleryItem(id: 'g2', name: 'Before and after.jpg', kind: 'image', bytes: 2400000, folderId: 'f1', when: '5 days ago'),
    GalleryItem(id: 'g3', name: 'Crew at work.jpg', kind: 'image', bytes: 3100000, folderId: 'f2', when: 'Last week'),
    GalleryItem(id: 'g4', name: 'Insurance certificate.pdf', kind: 'document', bytes: 820000, when: 'Last week'),
    GalleryItem(id: 'g5', name: 'Price list 2026.pdf', kind: 'document', bytes: 410000, when: '2 weeks ago'),
  ];
  @override
  Future<List<GalleryFolder>> galleryFolders() => _w(List.of(_folders));
  @override
  Future<List<GalleryItem>> galleryItems() => _w(List.of(_items));
  @override
  Future<GalleryItem> addGalleryItem({required String name, required String kind, required int bytes, required String path, String? folderId}) async {
    final it = GalleryItem(id: _id(), name: name, kind: kind, bytes: bytes, path: path, folderId: folderId);
    _items.insert(0, it);
    return _w(it);
  }

  @override
  Future<void> deleteGalleryItem(String id) async {
    _items.removeWhere((i) => i.id == id);
    await _w(null);
  }

  @override
  Future<void> moveGalleryItem(String id, String? folderId) async {
    _items.firstWhere((i) => i.id == id).folderId = folderId;
    await _w(null);
  }

  @override
  Future<GalleryFolder> createGalleryFolder(String name) async {
    final f = GalleryFolder(_id(), name);
    _folders.add(f);
    return _w(f);
  }

  // bundles
  final _bundles = [
    Bundle(id: 'b1', name: 'Roof replacements 2026', memberIds: ['1', '2', '3', '4', '5', '6', '7', '8', '9', '10'], lastSent: '12 days ago'),
    Bundle(id: 'b2', name: 'Gutter customers', memberIds: ['2', '4', '6', '8', '10', '12', '14', '16', '18', '20'], lastSent: 'Never sent'),
  ];
  @override
  Future<List<Bundle>> bundles() => _w(List.of(_bundles));

  @override
  Future<List<CaptionLine>> transcribeVideo(String path, {required int durationMs, String script = ''}) async {
    final text = script.trim().isEmpty
        ? 'Hi, I am so glad you stopped by. We have been helping local families for years. Every job is done properly, on time. Message us today for a free quote.'
        : script.trim();
    final parts = text.split(RegExp(r'(?<=[.!?])\s+')).where((s) => s.trim().isNotEmpty).toList();
    final total = durationMs <= 0 ? parts.length * 3000 : durationMs;
    final each = total ~/ parts.length;
    return _w([for (var i = 0; i < parts.length; i++) CaptionLine(startMs: i * each, endMs: (i + 1) * each, text: parts[i].trim())]);
  }

  @override
  Future<String> writeScript({required String topic, String tone = 'friendly', String business = ''}) async {
    final who = business.isEmpty ? 'our team' : business;
    final t = topic.trim().isEmpty ? 'what we do' : topic.trim();
    final text = switch (tone) {
      'professional' => 'Hello, and thank you for watching. At $who we specialise in $t. Our work is carried out to a high standard, with clear pricing and no surprises. Contact us today to arrange a free consultation.',
      'punchy' => 'Need $t? We have got you. Fast. Fair. Done right. Message $who today.',
      _ => 'Hi there! Quick hello from $who. If you are thinking about $t, we would love to help. We keep things simple, honest and friendly. Drop us a message and we will sort you out.',
    };
    return _w(text);
  }
  @override
  Future<Bundle> saveBundle({String? id, required String name, required List<String> memberIds}) async {
    if (id != null) {
      final b = _bundles.firstWhere((x) => x.id == id);
      b.name = name;
      b.memberIds = memberIds;
      return _w(b);
    }
    final b = Bundle(id: _id(), name: name, memberIds: memberIds);
    _bundles.insert(0, b);
    return _w(b);
  }

  @override
  Future<void> deleteBundle(String id) async {
    _bundles.removeWhere((b) => b.id == id);
    await _w(null);
  }

  @override
  Future<void> sendBundle(String id, {required String subject, required String body}) async {
    _bundles.firstWhere((b) => b.id == id).lastSent = 'just now';
    await _w(null);
  }

  // calendar
  @override
  Future<List<CalendarEvent>> calendarEvents(DateTime month) {
    final n = DateTime.now();
    DateTime d(int days) => DateTime(n.year, n.month, n.day).add(Duration(days: days));
    final all = [
      CalendarEvent(id: 'c1', date: d(-6), title: 'Invitation sent', kind: 'invite', who: 'Sarah Mitchell'),
      CalendarEvent(id: 'c2', date: d(-3), title: 'Reminder 1 sent', kind: 'reminder', who: 'Sarah Mitchell'),
      CalendarEvent(id: 'c3', date: d(-2), title: 'Group email: Roof replacements', kind: 'bundle', who: '10 people'),
      CalendarEvent(id: 'c4', date: d(0), title: 'Reminder 2 due', kind: 'reminder', who: 'Sarah Mitchell'),
      CalendarEvent(id: 'c5', date: d(0), title: 'Ask after job', kind: 'automation', who: 'Priya Nair'),
      CalendarEvent(id: 'c6', date: d(2), title: 'Invitation to send', kind: 'invite', who: 'Daniel Rhodes'),
      CalendarEvent(id: 'c7', date: d(4), title: 'Group email: Gutter customers', kind: 'bundle', who: '10 people'),
      CalendarEvent(id: 'c8', date: d(7), title: 'Reminder 1 due', kind: 'reminder', who: 'Lena Fischer'),
      CalendarEvent(id: 'c9', date: d(11), title: 'Ask after job', kind: 'automation', who: 'Imran Qureshi'),
    ];
    return _w(all.where((e) => e.date.year == month.year && e.date.month == month.month).toList());
  }

  // templates
  final _templates = [
    ReviewTemplate(id: 't1', name: 'Roof job', isDefault: true, questions: ['What did we do for you?', 'How was the team on the day?', 'Would you recommend us, and why?']),
    ReviewTemplate(id: 't2', name: 'Quick thanks', questions: ['What did you like most?', 'Anything we could do better?']),
  ];
  @override
  Future<List<ReviewTemplate>> templates() => _w(List.of(_templates));
  @override
  Future<ReviewTemplate> saveTemplate({String? id, required String name, required List<String> questions}) async {
    if (id != null) {
      final t = _templates.firstWhere((x) => x.id == id);
      t.name = name;
      t.questions = questions;
      return _w(t);
    }
    final t = ReviewTemplate(id: _id(), name: name, questions: questions);
    _templates.add(t);
    return _w(t);
  }

  @override
  Future<void> deleteTemplate(String id) async {
    _templates.removeWhere((t) => t.id == id);
    if (_templates.isNotEmpty && !_templates.any((t) => t.isDefault)) _templates.first.isDefault = true;
    await _w(null);
  }

  @override
  Future<void> setDefaultTemplate(String id) async {
    for (final t in _templates) {
      t.isDefault = t.id == id;
    }
    await _w(null);
  }

  // verification
  final _verification = Verification(status: 'none', docs: []);
  @override
  Future<Verification> verification() => _w(_verification);
  @override
  Future<Verification> uploadVerificationDoc({required String name, required String path}) async {
    _verification.docs.insert(0, VerificationDoc(id: _id(), name: name, status: 'pending'));
    _verification.status = 'in_review';
    _verification.note = 'A ViewRec reviewer will check your documents, usually within one working day.';
    return _w(_verification);
  }

  // review access requests
  final _access = [
    ReviewAccessRequest(id: 'a1', name: 'Tom Harding', email: 'tom@example.com', message: 'I had my gutters done in March and would like to leave a review.', when: '2 h ago'),
    ReviewAccessRequest(id: 'a2', name: 'Fatima Noor', email: 'fatima@example.com', message: 'Your team replaced my skylight. Happy to record a video.', when: 'Yesterday'),
    ReviewAccessRequest(id: 'a3', name: 'Chris Lowe', email: 'chris@example.com', message: 'Can I review you? I was a customer last year.', when: '4 days ago', status: 'approved'),
  ];
  @override
  Future<List<ReviewAccessRequest>> reviewRequests() => _w(List.of(_access));
  @override
  Future<void> decideReviewRequest(String id, {required bool approve}) async {
    _access.firstWhere((r) => r.id == id).status = approve ? 'approved' : 'declined';
    await _w(null);
  }

  // referrals
  @override
  Future<ReferralInfo> referrals() => _w(const ReferralInfo(
        link: 'https://viewrec.com/join/HARTLEY-7K2',
        code: 'HARTLEY-7K2',
        creditCents: 4900,
        referred: [
          Referred(name: 'Brightside Dental', status: 'paid', creditCents: 4900, when: '2 weeks ago'),
          Referred(name: 'Northgate Autos', status: 'signed up', creditCents: 0, when: '3 days ago'),
          Referred(name: 'Green Leaf Landscaping', status: 'signed up', creditCents: 0, when: 'Yesterday'),
        ],
      ));

  // video settings
  final _video = VideoSettings(subtitles: true, watermark: true);
  @override
  Future<VideoSettings> videoSettings() => _w(_video);
  @override
  Future<void> saveVideoSettings(VideoSettings s) async {
    _video
      ..subtitles = s.subtitles
      ..watermark = s.watermark;
    await _w(null);
  }

  // embeds
  final _embeds = [const EmbedItem(id: 'e1', name: 'Home page wall', layout: 'wall', count: 6, created: '10 days ago')];
  @override
  Future<List<EmbedItem>> embeds() => _w(List.of(_embeds));
  @override
  Future<EmbedItem> createEmbed({required String name, required String layout, required int count}) async {
    final e = EmbedItem(id: _id().substring(6), name: name, layout: layout, count: count, created: 'just now');
    _embeds.insert(0, e);
    return _w(e);
  }

  @override
  Future<void> deleteEmbed(String id) async {
    _embeds.removeWhere((e) => e.id == id);
    await _w(null);
  }

  // support chat
  final _support = <ThreadMessage>[
    ThreadMessage(id: 's0', from: 'customer', text: 'Hi, this is ViewRec support. Ask us anything about your account, plan or recordings.', when: '2 days ago'),
  ];

  void _supportReceipts(ThreadMessage m, String reply) {
    m.status = 'sent';
    Future<void>.delayed(const Duration(milliseconds: 1500), () => m.status = 'delivered');
    Future<void>.delayed(const Duration(milliseconds: 4200), () => m.status = 'read');
    Future<void>.delayed(const Duration(seconds: 6), () {
      _support.add(ThreadMessage(id: _id(), from: 'customer', text: reply, when: 'just now'));
    });
  }

  @override
  Future<List<ThreadMessage>> supportThread() => _w(List.of(_support));
  @override
  Future<ThreadMessage> sendSupportMessage(String text) async {
    final m = ThreadMessage(id: _id(), from: 'business', text: text, when: 'just now');
    _support.add(m);
    _supportReceipts(m, 'Thanks, we have your message. A member of the team will reply here shortly.');
    return _w(m);
  }

  @override
  Future<ThreadMessage> sendSupportAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress}) async {
    final m = ThreadMessage(id: _id(), from: 'business', text: '', when: 'just now', kind: kind, fileName: name, path: path, sizeBytes: size, durationMs: durationMs);
    _support.add(m);
    _supportReceipts(m, kind == 'voice' ? 'Thanks for the voice note. We will listen and reply here.' : 'Thanks, we have received your ${kind == 'image' ? 'photo' : 'file'}.');
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i / 4);
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    return m;
  }

  @override
  Future<ThreadMessage> editSupportMessage(String messageId, String text) async {
    final m = _support.firstWhere((x) => x.id == messageId);
    m.text = text;
    m.edited = true;
    return _w(m);
  }

  @override
  Future<void> deleteSupportMessage(String messageId) async {
    _support.removeWhere((x) => x.id == messageId);
    await _w(null);
  }

  // security
  final _sec = SecurityInfo(twoFactor: false, devices: [
    const SignedInDevice(id: 'd1', device: 'This phone', place: 'Manchester, UK', when: 'Active now', current: true),
    const SignedInDevice(id: 'd2', device: 'Chrome on Windows', place: 'Manchester, UK', when: '2 hours ago'),
    const SignedInDevice(id: 'd3', device: 'Safari on iPhone', place: 'Leeds, UK', when: '5 days ago'),
  ]);
  @override
  Future<void> changePassword({required String current, required String next}) async {
    if (current.isEmpty) throw Exception('Enter your current password');
    await _w(null);
  }

  @override
  Future<void> requestDataExport() => _w(null);

  @override
  Future<void> requestAccountDeletion() => _w(null);

  @override
  Future<SecurityInfo> security() => _w(_sec);
  @override
  Future<void> setTwoFactor(bool on) async {
    _sec.twoFactor = on;
    await _w(null);
  }

  @override
  Future<void> revokeDevice(String id) async {
    _sec.devices.removeWhere((d) => d.id == id && !d.current);
    await _w(null);
  }

  @override
  Future<void> signOutOtherDevices() async {
    _sec.devices.removeWhere((d) => !d.current);
    await _w(null);
  }

  // workspaces
  final _spaces = [
    Workspace(id: 'w1', name: 'Hartley Roofing', role: 'Owner', current: true),
    Workspace(id: 'w2', name: 'Brightside Dental', role: 'Member'),
  ];
  @override
  Future<List<Workspace>> workspaces() => _w(List.of(_spaces));
  @override
  Future<void> switchWorkspace(String id) async {
    for (final w in _spaces) {
      w.current = w.id == id;
    }
    await _w(null);
  }

  // marketing email
  @override
  Future<MarketingResult> sendMarketingEmail({required String subject, required String body, required String audience}) async {
    // The website drops opted-out people and anyone contacted too recently.
    final all = audience == 'approved' ? 14 : 31;
    return _w(MarketingResult(all - 3, 3));
  }
}

// ---------------- real API version (addresses are assumed until the mobile API exists)

class ApiWebRepo implements WebRepo {
  final String base;
  ApiWebRepo(this.base);
  static const _timeout = Duration(seconds: 12);

  Uri _u(String p) => Uri.parse('$base$p');

  Future<dynamic> _call(String method, String p, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, _u(p))..headers.addAll(ApiAuth.headers(json: true));
    if (body != null) req.body = jsonEncode(body);
    final r = await http.Response.fromStream(await req.send().timeout(_timeout));
    if (r.statusCode >= 400) {
      String msg = 'Request failed (${r.statusCode})';
      try {
        msg = (jsonDecode(r.body)['error'] ?? msg).toString();
      } catch (_) {}
      throw Exception(msg);
    }
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  List<T> _list<T>(dynamic j, T Function(Map<String, dynamic>) f) => [for (final e in (j as List)) f(e as Map<String, dynamic>)];

  @override
  Future<List<GalleryFolder>> galleryFolders() async => _list(await _call('GET', '/api/v1/gallery/folders'), GalleryFolder.fromJson);
  @override
  Future<List<GalleryItem>> galleryItems() async => _list(await _call('GET', '/api/v1/gallery/items'), GalleryItem.fromJson);
  @override
  Future<GalleryItem> addGalleryItem({required String name, required String kind, required int bytes, required String path, String? folderId}) async {
    final req = http.MultipartRequest('POST', _u('/api/v1/gallery/upload'))
      ..headers.addAll(ApiAuth.headers())
      ..fields['kind'] = kind
      ..fields['folderId'] = folderId ?? ''
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: name));
    final res = await req.send().timeout(const Duration(minutes: 5));
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 400) throw Exception('Upload failed (${res.statusCode})');
    return GalleryItem.fromJson(jsonDecode(body));
  }

  @override
  Future<void> deleteGalleryItem(String id) => _call('DELETE', '/api/v1/gallery/items/$id');
  @override
  Future<void> moveGalleryItem(String id, String? folderId) => _call('PATCH', '/api/v1/gallery/items/$id', {'folderId': folderId});
  @override
  Future<GalleryFolder> createGalleryFolder(String name) async => GalleryFolder.fromJson(await _call('POST', '/api/v1/gallery/folders', {'name': name}));

  @override
  Future<List<Bundle>> bundles() async => _list(await _call('GET', '/api/v1/bundles'), Bundle.fromJson);

  @override
  Future<List<CaptionLine>> transcribeVideo(String path, {required int durationMs, String script = ''}) async {
    final req = http.MultipartRequest('POST', _u('/api/v1/ai/transcribe'))
      ..headers.addAll(ApiAuth.headers())
      ..fields['durationMs'] = '$durationMs'
      ..fields['script'] = script
      ..files.add(await http.MultipartFile.fromPath('file', path));
    final res = await req.send().timeout(const Duration(minutes: 5));
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 400) throw Exception('Could not make captions (${res.statusCode})');
    return _list(jsonDecode(body), CaptionLine.fromJson);
  }

  @override
  Future<String> writeScript({required String topic, String tone = 'friendly', String business = ''}) async {
    final j = await _call('POST', '/api/v1/ai/script', {'topic': topic, 'tone': tone, 'business': business});
    return (j is Map ? j['script'] : j).toString();
  }
  @override
  Future<Bundle> saveBundle({String? id, required String name, required List<String> memberIds}) async =>
      Bundle.fromJson(await _call(id == null ? 'POST' : 'PUT', id == null ? '/api/v1/bundles' : '/api/v1/bundles/$id', {'name': name, 'memberIds': memberIds}));
  @override
  Future<void> deleteBundle(String id) => _call('DELETE', '/api/v1/bundles/$id');
  @override
  Future<void> sendBundle(String id, {required String subject, required String body}) => _call('POST', '/api/v1/bundles/$id/send', {'subject': subject, 'body': body});

  @override
  Future<List<CalendarEvent>> calendarEvents(DateTime month) async => _list(await _call('GET', '/api/v1/calendar?month=${month.year}-${month.month.toString().padLeft(2, '0')}'), CalendarEvent.fromJson);

  @override
  Future<List<ReviewTemplate>> templates() async => _list(await _call('GET', '/api/v1/templates'), ReviewTemplate.fromJson);
  @override
  Future<ReviewTemplate> saveTemplate({String? id, required String name, required List<String> questions}) async =>
      ReviewTemplate.fromJson(await _call(id == null ? 'POST' : 'PUT', id == null ? '/api/v1/templates' : '/api/v1/templates/$id', {'name': name, 'questions': questions}));
  @override
  Future<void> deleteTemplate(String id) => _call('DELETE', '/api/v1/templates/$id');
  @override
  Future<void> setDefaultTemplate(String id) => _call('PUT', '/api/v1/templates/$id/default');

  @override
  Future<Verification> verification() async => Verification.fromJson(await _call('GET', '/api/v1/verification'));
  @override
  Future<Verification> uploadVerificationDoc({required String name, required String path}) async {
    final req = http.MultipartRequest('POST', _u('/api/v1/verification/documents'))
      ..headers.addAll(ApiAuth.headers())..files.add(await http.MultipartFile.fromPath('file', path, filename: name));
    final res = await req.send().timeout(const Duration(minutes: 3));
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 400) throw Exception('Upload failed (${res.statusCode})');
    return Verification.fromJson(jsonDecode(body));
  }

  @override
  Future<List<ReviewAccessRequest>> reviewRequests() async => _list(await _call('GET', '/api/v1/review-requests'), ReviewAccessRequest.fromJson);
  @override
  Future<void> decideReviewRequest(String id, {required bool approve}) => _call('POST', '/api/v1/review-requests/$id/${approve ? 'approve' : 'decline'}');

  @override
  Future<ReferralInfo> referrals() async => ReferralInfo.fromJson(await _call('GET', '/api/v1/referrals'));

  @override
  Future<VideoSettings> videoSettings() async => VideoSettings.fromJson(await _call('GET', '/api/v1/video-settings'));
  @override
  Future<void> saveVideoSettings(VideoSettings s) => _call('PUT', '/api/v1/video-settings', s.toJson());

  @override
  Future<List<EmbedItem>> embeds() async => _list(await _call('GET', '/api/v1/embeds'), EmbedItem.fromJson);
  @override
  Future<EmbedItem> createEmbed({required String name, required String layout, required int count}) async =>
      EmbedItem.fromJson(await _call('POST', '/api/v1/embeds', {'name': name, 'layout': layout, 'count': count}));
  @override
  Future<void> deleteEmbed(String id) => _call('DELETE', '/api/v1/embeds/$id');

  @override
  Future<List<ThreadMessage>> supportThread() async => _list(await _call('GET', '/api/v1/support/thread'), ThreadMessage.fromJson);
  @override
  Future<ThreadMessage> sendSupportMessage(String text) async => ThreadMessage.fromJson(await _call('POST', '/api/v1/support/thread', {'text': text}));
  @override
  Future<ThreadMessage> sendSupportAttachment({required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress}) async {
    final req = http.MultipartRequest('POST', _u('/api/v1/support/thread/attachment'))
      ..headers.addAll(ApiAuth.headers())
      ..fields['kind'] = kind
      ..fields['durationMs'] = '$durationMs'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: name));
    final res = await req.send().timeout(const Duration(minutes: 3));
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 400) throw Exception('Upload failed (${res.statusCode})');
    onProgress?.call(1);
    return ThreadMessage.fromJson(jsonDecode(body));
  }

  @override
  Future<ThreadMessage> editSupportMessage(String messageId, String text) async => ThreadMessage.fromJson(await _call('PATCH', '/api/v1/support/thread/messages/$messageId', {'text': text}));
  @override
  Future<void> deleteSupportMessage(String messageId) => _call('DELETE', '/api/v1/support/thread/messages/$messageId');

  @override
  Future<void> changePassword({required String current, required String next}) =>
      _call('POST', '/api/v1/auth/password', {'currentPassword': current, 'newPassword': next});
  @override
  Future<void> requestDataExport() => _call('POST', '/api/v1/account/export');
  @override
  Future<void> requestAccountDeletion() => _call('POST', '/api/v1/account/delete');
  @override
  Future<SecurityInfo> security() async => SecurityInfo.fromJson(await _call('GET', '/api/v1/security'));
  @override
  Future<void> setTwoFactor(bool on) => _call('PUT', '/api/v1/security/two-factor', {'enabled': on});
  @override
  Future<void> revokeDevice(String id) => _call('DELETE', '/api/v1/security/devices/$id');
  @override
  Future<void> signOutOtherDevices() => _call('POST', '/api/v1/security/sign-out-others');

  @override
  Future<List<Workspace>> workspaces() async => _list(await _call('GET', '/api/v1/workspaces'), Workspace.fromJson);
  @override
  Future<void> switchWorkspace(String id) => _call('POST', '/api/v1/workspaces/$id/switch');

  @override
  Future<MarketingResult> sendMarketingEmail({required String subject, required String body, required String audience}) async {
    final j = await _call('POST', '/api/v1/marketing/email', {'subject': subject, 'body': body, 'audience': audience}) as Map<String, dynamic>;
    return MarketingResult(j['sent'] ?? 0, j['excluded'] ?? 0);
  }
}

final WebRepo webRepo = usingMock ? MockWebRepo() : ApiWebRepo(apiBaseUrl);
