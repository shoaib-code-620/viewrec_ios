import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'data.dart';
import 'models.dart';

/// Everything the UI needs from a server. Screens only ever talk to [repo].
/// - No API_URL given  -> [MockRepo]: in-memory demo data, works offline.
/// - `--dart-define=API_URL=https://...` -> [ApiRepo]: the real backend.
abstract class Repo {
  Future<OverviewStats> overview();

  Future<List<Customer>> customers();
  Future<Customer> addCustomer({required String name, required String job, String? contact});
  Future<void> setCustomerStatus(String id, String status);

  Future<List<Video>> videos();
  Future<void> updateVideo(String id, {String? status, List<String>? platforms});

  Future<List<Lead>> leads();
  Future<void> setLeadStatus(String id, String status);

  Future<PostsData> posts();

  Future<InsightsData> insights();

  Future<List<ThreadMessage>> leadMessages(String leadId);
  Future<ThreadMessage> sendLeadMessage(String leadId, String text);

  /// platformId -> account display name (only connected ones are present).
  Future<Map<String, String>> accounts();
  Future<void> connectAccount(String platformId);
  Future<void> disconnectAccount(String platformId);

  Future<List<AppNotification>> notifications();
  Future<BillingInfo> billing();

  Future<AutomationSettings> automations();
  Future<void> saveAutomations(AutomationSettings s);

  Future<BusinessProfile> profile();
  Future<void> saveProfile(BusinessProfile p);

  /// Customer side: upload a recorded testimonial. [onProgress] gets 0..1.
  Future<void> uploadVideo(XFile file, {required String inviteToken, required String duration, required String agreedAt, int rating = 5, String? avatar, void Function(double)? onProgress});

  /// Customer side: submit a written testimonial instead of a video.
  Future<void> submitWrittenTestimonial({required String inviteToken, required int rating, required String text, required String agreedAt});
}

/// Demo invite token used until deep links carry the real one.
const demoInviteToken = 'tok_sarah';

const _apiUrl = String.fromEnvironment('API_URL');
bool get usingMock => _apiUrl.isEmpty;

final Repo repo = usingMock ? MockRepo() : ApiRepo(_apiUrl);

// ===========================================================================
// Mock
// ===========================================================================

class MockRepo implements Repo {
  /// Simulated network delay, so loading states are visible and testable.
  static const _lag = Duration(milliseconds: 650);
  Future<T> _wait<T>(T v) async {
    await Future.delayed(_lag);
    return v;
  }

  final _customers = demoCustomers();
  final _videos = demoVideos();
  final _accounts = <String, String>{
    'google': 'Hartley Roofing · Manchester',
    'fb': 'Hartley Roofing Ltd',
    'ig': '@hartleyroofing',
    'yt': 'Hartley Roofing',
  };
  final _leads = [
    Lead(id: 'l1', name: 'Rebecca Shaw', service: 'Roof inspection', message: 'Hi, I saw your video reviews. Can someone look at a leak above our bay window this week?', when: '12 min ago', source: 'Directory', status: 'new'),
    Lead(id: 'l2', name: 'Imran Qureshi', service: 'Gutter replacement', message: 'Looking for a quote for a 3-bed semi. Photos available.', when: '2 h ago', source: 'Review page', status: 'new'),
    Lead(id: 'l3', name: 'Claire Dubois', service: 'Chimney repair', message: 'Recommended by a neighbour. Free on Thursday morning.', when: 'Yesterday', source: 'Website embed', status: 'contacted'),
    Lead(id: 'l4', name: 'Pete Warren', service: 'Skylight install', message: 'Thanks, we went with another firm.', when: '3 days ago', source: 'Directory', status: 'lost'),
    Lead(id: 'l5', name: 'Nadia Aziz', service: 'Full re-roof', message: 'Accepted your quote.', when: 'Last week', source: 'Review page', status: 'won'),
  ];
  var _automations = AutomationSettings();
  var _profile = BusinessProfile(
    name: 'Hartley Roofing',
    category: 'Home & Trades',
    phone: '+44 161 496 0123',
    email: 'demo@viewrec.com',
    website: 'https://hartleyroofing.example',
    area: 'Greater Manchester · 25 miles',
    about: 'Family-run roofers for over 20 years. Fixed prices, no surprises.',
  );

  @override
  Future<OverviewStats> overview() => _wait(OverviewStats(
        testimonials: _videos.length,
        videos: _videos.where((v) => !v.written).length,
        waiting: _videos.where((v) => v.status == 'pending').length,
        averageRating: _videos.isEmpty ? 0 : _videos.map((v) => v.rating).reduce((a, b) => a + b) / _videos.length,
        customers: _customers.where((c) => c.status == 'approved' || c.status == 'suggested').length,
        invitesSent: 31,
        reviewPages: 1,
        linkedAccounts: _accounts.length,
        embeds: 0,
        videoLink: 'https://viewrec.com/r/demo',
      ));

  @override
  Future<List<Customer>> customers() => _wait(List.of(_customers));

  @override
  Future<Customer> addCustomer({required String name, required String job, String? contact}) async {
    final c = Customer(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, job: job, date: 'just now', reason: 'Added by you', status: 'approved');
    _customers.insert(0, c);
    return _wait(c);
  }

  @override
  Future<void> setCustomerStatus(String id, String status) async {
    _customers.firstWhere((c) => c.id == id).status = status;
    await _wait(null);
  }

  @override
  Future<List<Video>> videos() => _wait(List.of(_videos));

  @override
  Future<void> updateVideo(String id, {String? status, List<String>? platforms}) async {
    final v = _videos.firstWhere((x) => x.id == id);
    if (status != null) v.status = status;
    if (platforms != null) v.platforms = platforms;
    await _wait(null);
  }

  @override
  Future<List<Lead>> leads() => _wait(List.of(_leads));

  @override
  Future<void> setLeadStatus(String id, String status) async {
    _leads.firstWhere((l) => l.id == id).status = status;
    await _wait(null);
  }

  @override
  Future<PostsData> posts() => _wait(const PostsData(usedThisMonth: 9, monthlyLimit: 22, posts: [
        Post(id: 'p1', title: 'Priya Nair - quote card', platform: 'Instagram', when: 'Today, 17:30', status: 'scheduled'),
        Post(id: 'p2', title: 'Aisha Rahman - video clip', platform: 'YouTube', when: 'Tomorrow, 10:00', status: 'scheduled'),
        Post(id: 'p3', title: 'Lena Fischer - story', platform: 'Facebook', when: 'Fri, 09:00', status: 'scheduled'),
        Post(id: 'p4', title: 'James Carter - quote card', platform: 'Google', when: '2 days ago', status: 'published', reactions: 14),
        Post(id: 'p5', title: 'Priya Nair - video', platform: 'Facebook', when: '4 days ago', status: 'published', reactions: 52),
        Post(id: 'p6', title: 'Omar Haddad - carousel', platform: 'Instagram', when: '5 days ago', status: 'failed'),
      ]));

  @override
  Future<InsightsData> insights() => _wait(const InsightsData(
        weeklyViews: [120, 180, 150, 260, 310, 280, 420, 512],
        totalViews: 2232,
        plays: 1604,
        linkClicks: 389,
        avgWatchPercent: 72,
        responseRate: 0.28,
        byPlatform: [PlatformViews('Google', 940), PlatformViews('Facebook', 610), PlatformViews('Website', 420), PlatformViews('Instagram', 262)],
      ));

  final _threads = <String, List<ThreadMessage>>{};

  @override
  Future<List<ThreadMessage>> leadMessages(String leadId) {
    final lead = _leads.firstWhere((l) => l.id == leadId);
    final list = _threads.putIfAbsent(leadId, () => [ThreadMessage(id: 'm0', from: 'customer', text: lead.message, when: lead.when)]);
    return _wait(List.of(list));
  }

  @override
  Future<ThreadMessage> sendLeadMessage(String leadId, String text) async {
    final m = ThreadMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), from: 'business', text: text, when: 'just now');
    _threads.putIfAbsent(leadId, () => []).add(m);
    final lead = _leads.firstWhere((l) => l.id == leadId);
    if (lead.status == 'new') lead.status = 'contacted';
    return _wait(m);
  }

  @override
  Future<Map<String, String>> accounts() => _wait(Map.of(_accounts));

  @override
  Future<void> connectAccount(String platformId) async {
    _accounts[platformId] = 'Hartley Roofing';
    await _wait(null);
  }

  @override
  Future<void> disconnectAccount(String platformId) async {
    _accounts.remove(platformId);
    await _wait(null);
  }

  @override
  Future<List<AppNotification>> notifications() => _wait(const [
        AppNotification(id: 'n1', kind: 'video', title: 'Lena Fischer recorded a video', subtitle: 'Ready for your approval · 2h ago'),
        AppNotification(id: 'n2', kind: 'suggestion', title: '2 customers suggested', subtitle: 'Approve before invitations go out · 5h ago'),
        AppNotification(id: 'n3', kind: 'views', title: "Priya Nair's video hit 1,000 views", subtitle: 'On Google and your website · 1d ago'),
        AppNotification(id: 'n4', kind: 'invite', title: 'Invitation sent to Tom Hendricks', subtitle: 'Reminder goes out in 3 days · 2d ago'),
      ]);

  @override
  Future<BillingInfo> billing() => _wait(const BillingInfo(
        plan: 'Pro',
        status: 'trial',
        trialDay: 4,
        trialLength: 15,
        afterTrialNote: 'then \$49 / month on Standard unless you choose another plan.',
        billingEmail: 'demo@viewrec.com',
        hasCard: false,
        usage: [UsageItem('Invitations sent', 31, 'unlimited'), UsageItem('Reminders', 22, '5 per invitation'), UsageItem('Social posts', 9, '22'), UsageItem('Loyalty rewards', 2, '15')],
        invoices: [Invoice('Trial activation', '\$1.00', '19 Nov 2026'), Invoice('Trial activation (test)', '\$1.00', '12 Nov 2026')],
      ));

  @override
  Future<AutomationSettings> automations() => _wait(AutomationSettings.fromJson(_automations.toJson()));

  @override
  Future<void> saveAutomations(AutomationSettings s) async {
    _automations = AutomationSettings.fromJson(s.toJson());
    await _wait(null);
  }

  @override
  Future<BusinessProfile> profile() => _wait(BusinessProfile.fromJson(_profile.toJson()));

  @override
  Future<void> saveProfile(BusinessProfile p) async {
    _profile = BusinessProfile.fromJson(p.toJson());
    await _wait(null);
  }

  @override
  Future<void> uploadVideo(XFile file, {required String inviteToken, required String duration, required String agreedAt, int rating = 5, String? avatar, void Function(double)? onProgress}) async {
    for (var i = 1; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 180));
      onProgress?.call(i / 10);
    }
  }

  @override
  Future<void> submitWrittenTestimonial({required String inviteToken, required int rating, required String text, required String agreedAt}) async {
    await _wait(null);
  }
}

// ===========================================================================
// Real API
// ===========================================================================

/// iPhones record .mov (QuickTime), Android .mp4, browsers .webm.
String _videoExt(XFile f) {
  if (kIsWeb) return 'webm';
  final dot = f.path.lastIndexOf('.');
  final ext = dot < 0 ? 'mp4' : f.path.substring(dot + 1).toLowerCase();
  return (ext == 'mov' || ext == 'mp4' || ext == 'webm') ? ext : 'mp4';
}

String _videoSubtype(XFile f) => switch (_videoExt(f)) { 'mov' => 'quicktime', 'webm' => 'webm', _ => 'mp4' };

class ApiRepo implements Repo {
  final String base;
  ApiRepo(this.base);

  static const _timeout = Duration(seconds: 10);
  static const _json = {'Content-Type': 'application/json'};

  Uri _u(String p) => Uri.parse('$base$p');

  String _err(http.Response r) {
    try {
      return (jsonDecode(r.body)['error'] ?? 'Request failed (${r.statusCode})').toString();
    } catch (_) {
      return 'Request failed (${r.statusCode})';
    }
  }

  Future<dynamic> _get(String p) async {
    final r = await http.get(_u(p)).timeout(_timeout);
    if (r.statusCode >= 400) throw Exception(_err(r));
    return jsonDecode(r.body);
  }

  Future<dynamic> _send(String method, String p, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, _u(p))..headers.addAll(_json);
    if (body != null) req.body = jsonEncode(body);
    final r = await http.Response.fromStream(await req.send().timeout(_timeout));
    if (r.statusCode >= 400) throw Exception(_err(r));
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  @override
  Future<OverviewStats> overview() async => OverviewStats.fromJson(await _get('/api/overview'));

  @override
  Future<List<Customer>> customers() async => (await _get('/api/customers') as List).map((e) => Customer.fromJson(e)).toList();

  @override
  Future<Customer> addCustomer({required String name, required String job, String? contact}) async =>
      Customer.fromJson(await _send('POST', '/api/customers', {'name': name, 'job': job, 'contact': contact}));

  @override
  Future<void> setCustomerStatus(String id, String status) => _send('PATCH', '/api/customers/$id', {'status': status});

  @override
  Future<List<Video>> videos() async => (await _get('/api/videos') as List).map((e) => Video.fromJson(e)).toList();

  @override
  Future<void> updateVideo(String id, {String? status, List<String>? platforms}) =>
      _send('PATCH', '/api/videos/$id', {if (status != null) 'status': status, if (platforms != null) 'platforms': platforms});

  @override
  Future<List<Lead>> leads() async => (await _get('/api/leads') as List).map((e) => Lead.fromJson(e)).toList();

  @override
  Future<void> setLeadStatus(String id, String status) => _send('PATCH', '/api/leads/$id', {'status': status});

  @override
  Future<PostsData> posts() async => PostsData.fromJson(await _get('/api/posts'));

  @override
  Future<InsightsData> insights() async => InsightsData.fromJson(await _get('/api/insights'));

  @override
  Future<List<ThreadMessage>> leadMessages(String leadId) async =>
      (await _get('/api/leads/$leadId/messages') as List).map((e) => ThreadMessage.fromJson(e)).toList();

  @override
  Future<ThreadMessage> sendLeadMessage(String leadId, String text) async =>
      ThreadMessage.fromJson(await _send('POST', '/api/leads/$leadId/messages', {'text': text}));

  @override
  Future<Map<String, String>> accounts() async => Map<String, String>.from(await _get('/api/accounts') as Map);

  @override
  Future<void> connectAccount(String platformId) => _send('PUT', '/api/accounts/$platformId');

  @override
  Future<void> disconnectAccount(String platformId) => _send('DELETE', '/api/accounts/$platformId');

  @override
  Future<List<AppNotification>> notifications() async => (await _get('/api/notifications') as List).map((e) => AppNotification.fromJson(e)).toList();

  @override
  Future<BillingInfo> billing() async => BillingInfo.fromJson(await _get('/api/billing'));

  @override
  Future<AutomationSettings> automations() async => AutomationSettings.fromJson(await _get('/api/automations'));

  @override
  Future<void> saveAutomations(AutomationSettings s) => _send('PUT', '/api/automations', s.toJson());

  @override
  Future<BusinessProfile> profile() async => BusinessProfile.fromJson(await _get('/api/profile'));

  @override
  Future<void> saveProfile(BusinessProfile p) => _send('PUT', '/api/profile', p.toJson());

  @override
  Future<void> submitWrittenTestimonial({required String inviteToken, required int rating, required String text, required String agreedAt}) =>
      _send('POST', '/api/invites/$inviteToken/written', {
        'rating': rating,
        'text': text,
        'consent': {'agreed': true, 'agreedAt': agreedAt, 'singleSession': true, 'platform': kIsWeb ? 'web' : defaultTargetPlatform.name},
      });

  @override
  Future<void> uploadVideo(XFile file, {required String inviteToken, required String duration, required String agreedAt, int rating = 5, String? avatar, void Function(double)? onProgress}) async {
    final total = await file.length();
    var sent = 0;
    final stream = file.openRead().map((chunk) {
      sent += chunk.length;
      onProgress?.call(total == 0 ? 0 : sent / total);
      return chunk;
    });

    final req = http.MultipartRequest('POST', _u('/api/invites/$inviteToken/video'))
      ..fields['consent'] = jsonEncode({
        'agreed': true,
        'agreedAt': agreedAt,
        'singleSession': true,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      })
      ..fields['duration'] = duration
      ..fields['rating'] = '$rating'
      ..fields['avatar'] = avatar ?? ''
      ..files.add(http.MultipartFile('video', stream, total,
          filename: 'testimonial.${_videoExt(file)}', contentType: MediaType('video', _videoSubtype(file))));

    http.StreamedResponse res;
    try {
      res = await req.send().timeout(const Duration(minutes: 5));
    } catch (_) {
      throw Exception('Could not reach the server. Check your connection and try again.');
    }
    final body = await res.stream.bytesToString();
    if (res.statusCode >= 400) {
      String msg = 'Upload failed (${res.statusCode})';
      try {
        msg = jsonDecode(body)['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }
}
