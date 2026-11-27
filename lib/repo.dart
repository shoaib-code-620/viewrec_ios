import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'data.dart';
import 'media_data.dart';
import 'package:flutter/painting.dart' show Color;
import 'models.dart';

/// Everything the UI needs from a server. Screens only ever talk to [repo].
/// - No API_URL given  -> [MockRepo]: in-memory demo data, works offline.
/// - `--dart-define=API_URL=https://...` -> [ApiRepo]: the real backend.
abstract class Repo {
  Future<OverviewStats> overview();

  Future<List<Customer>> customers();
  Future<Customer> addCustomer({required String name, required String job, String? contact});
  Future<void> setCustomerStatus(String id, String status);
  /// Send the next reminder for an invitation. Returns how many reminders have gone out now.
  Future<int> remindCustomer(String id);
  Future<void> updateCustomer(String id, {String? name, String? job, String? contact});
  Future<void> deleteCustomer(String id);

  Future<List<Video>> videos();
  Future<void> updateVideo(String id, {String? status, List<String>? platforms, String? transcript});

  Future<List<Lead>> leads();
  Future<void> setLeadStatus(String id, String status);

  Future<PostsData> posts();

  Future<InsightsData> insights();
  /// Media page results for the last [days] days (7, 30 or 90).
  Future<MediaInsights> mediaInsights(int days);

  // ---- Media: stories, reels, follow, like, save, comments
  Future<List<StoryGroup>> stories();
  Future<void> markStorySeen(String groupId);
  Future<List<Reel>> reels();
  Future<void> setFollow(String businessId, bool follow);
  /// A business's public page: details, counts and its posts.
  Future<PublicProfile> publicProfile(String businessId);
  Future<List<BusinessRef>> followersOf(String businessId);
  Future<List<BusinessRef>> followingOf(String businessId);
  /// Report a post, comment, profile or message. [targetType] is post, comment, profile or message.
  Future<void> report({required String targetType, required String targetId, required String reason, String note = ''});
  Future<void> setBlock(String businessId, bool block);
  Future<List<BusinessRef>> blockedAccounts();
  Future<void> setLike(String reelId, bool like);
  Future<void> setSave(String reelId, bool save);
  Future<List<Comment>> comments(String reelId);
  Future<Comment> addComment(String reelId, String text);
  /// Publish your own content from the Create menu. [kind] is 'post', 'reel' or 'story'.
  Future<void> createContent({required String kind, required XFile file, required bool isVideo, String caption = '', String duration = '0:00', EditSpec? edits, void Function(double)? onProgress});

  Future<List<ThreadMessage>> leadMessages(String leadId);
  Future<ThreadMessage> sendLeadMessage(String leadId, String text);
  /// Send a photo, file or voice note in a conversation. [kind] is 'image', 'file' or 'voice'.
  Future<ThreadMessage> sendLeadAttachment(String leadId, {required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress});
  /// Change the text of a message you sent. The other person sees it marked as edited.
  Future<ThreadMessage> editLeadMessage(String leadId, String messageId, String text);
  /// React to a message with an emoji, or pass null to take your reaction back.
  Future<void> reactLeadMessage(String leadId, String messageId, String? emoji);
  /// Remove a message you sent, for everyone in the conversation.
  Future<void> deleteLeadMessage(String leadId, String messageId);
  /// Note in the conversation that you called this person.
  Future<ThreadMessage> logLeadCall(String leadId);

  /// platformId -> account display name (only connected ones are present).
  Future<Map<String, String>> accounts();
  Future<void> connectAccount(String platformId);
  Future<void> disconnectAccount(String platformId);

  Future<List<AppNotification>> notifications();
  Future<void> markNotificationRead(String id);
  Future<void> markAllNotificationsRead();
  Future<BillingInfo> billing();
  /// Move to another plan. The server decides when the price changes.
  Future<void> changePlan(String planId);
  /// Stop the subscription. Nothing more is charged and the paid period keeps running.
  Future<void> stopSubscription();
  Future<void> resumeSubscription();
  /// Starts adding a card. The card number is typed on the payment provider's own page, never in this app.
  /// Returns the address of that page, or null when the card was added without one (sample data).
  Future<String?> startCardSetup();
  Future<void> removeCard();
  /// Saves a card typed in the short form. The server passes it straight to the payment provider and keeps only the last four digits.
  Future<void> saveCard({required String number, required String name, required String expiry, required String cvc});

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
/// The address of the real API, or empty when the app runs on sample data.
String get apiBaseUrl => _apiUrl;

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
    Lead(id: 'l1', phone: '+44 7700 800211', name: 'Rebecca Shaw', service: 'Roof inspection', message: 'Hi, I saw your video reviews. Can someone look at a leak above our bay window this week?', when: '12 min ago', source: 'Directory', status: 'new'),
    Lead(id: 'l2', phone: '+44 7700 800422', name: 'Imran Qureshi', service: 'Gutter replacement', message: 'Looking for a quote for a 3-bed semi. Photos available.', when: '2 h ago', source: 'Review page', status: 'new'),
    Lead(id: 'l3', phone: '+44 7700 800633', name: 'Claire Dubois', service: 'Chimney repair', message: 'Recommended by a neighbour. Free on Thursday morning.', when: 'Yesterday', source: 'Website embed', status: 'contacted'),
    Lead(id: 'l4', phone: '+44 7700 800844', name: 'Pete Warren', service: 'Skylight install', message: 'Thanks, we went with another firm.', when: '3 days ago', source: 'Directory', status: 'lost'),
    Lead(id: 'l5', phone: '+44 7700 801055', name: 'Nadia Aziz', service: 'Full re-roof', message: 'Accepted your quote.', when: 'Last week', source: 'Review page', status: 'won'),
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
        approved: _videos.where((v) => v.status == 'approved' || v.status == 'published').length,
        published: _videos.where((v) => v.status == 'published' || v.platforms.isNotEmpty).length,
        hasLogo: false,
        verified: false,
        hasGroup: true,
        remindersSet: true,
        hasCard: _card.isNotEmpty,
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
    final c = _customers.firstWhere((c) => c.id == id);
    c.status = status;
    if (status == 'invited' && c.sentOn.isEmpty) c.sentOn = 'today';
    await _wait(null);
  }

  @override
  Future<int> remindCustomer(String id) async {
    final c = _customers.firstWhere((c) => c.id == id);
    c.nudges += 1;
    await _wait(null);
    return c.nudges;
  }

  @override
  Future<void> updateCustomer(String id, {String? name, String? job, String? contact}) async {
    final c = _customers.firstWhere((x) => x.id == id);
    if (name != null) c.name = name;
    if (job != null) c.job = job;
    if (contact != null) c.phone = contact;
    await _wait(null);
  }

  @override
  Future<void> deleteCustomer(String id) async {
    _customers.removeWhere((c) => c.id == id);
    await _wait(null);
  }

  @override
  Future<List<Video>> videos() => _wait(List.of(_videos));

  @override
  Future<void> updateVideo(String id, {String? status, List<String>? platforms, String? transcript}) async {
    final v = _videos.firstWhere((x) => x.id == id);
    if (status != null) v.status = status;
    if (platforms != null) v.platforms = platforms;
    if (transcript != null) v.transcript = transcript;
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
  Future<MediaInsights> mediaInsights(int days) {
    final k = days / 7;
    int n(int v) => (v * k).round();
    return _wait(MediaInsights(
      days: days,
      reach: n(1840),
      reachDelta: days == 7 ? 14 : (days == 30 ? 9 : -3),
      impressions: n(3120),
      profileVisits: n(236),
      linkTaps: n(58),
      likes: n(412),
      comments: n(67),
      saves: n(93),
      shares: n(41),
      followers: 1284,
      followersGained: n(46),
      followersLost: n(9),
      daily: [for (var i = 0; i < (days > 30 ? 30 : days); i++) 160 + ((i * 37) % 140) + (i * 3)],
      pctFollowers: 38,
      topPosts: const [
        TopPost('Roof replaced in a day', 'reel', 2310, 188, 21, 210),
        TopPost('James Carter, 5 stars', 'post', 1450, 96, 12, 150),
        TopPost('Before and after: Maple St', 'reel', 1120, 84, 9, 28),
      ],
      topPlaces: const [PlatformViews('Reels', 1210), PlatformViews('Explore', 760), PlatformViews('Profile', 540), PlatformViews('Feed', 330)],
    ));
  }

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
    lead.lastNote = 'You: $text';
    _simulateReceipts(m);
    return _wait(m);
  }

  /// Demo only: a real server marks a message delivered when the other phone gets it, and read when they open it.
  void _simulateReceipts(ThreadMessage m) {
    m.status = 'sent';
    Future<void>.delayed(const Duration(milliseconds: 1500), () => m.status = 'delivered');
    Future<void>.delayed(const Duration(milliseconds: 4200), () => m.status = 'read');
  }

  void _refreshLastNote(String leadId) {
    final lead = _leads.firstWhere((l) => l.id == leadId);
    final list = _threads[leadId] ?? [];
    final last = list.where((m) => m.kind != 'call').isEmpty ? null : list.where((m) => m.kind != 'call').last;
    if (last == null || last.id == 'm0') {
      lead.lastNote = null;
      return;
    }
    final mine = last.from == 'business' ? 'You: ' : '';
    final secs = (last.durationMs / 1000).round();
    lead.lastNote = switch (last.kind) {
      'voice' => '${mine}Voice note ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
      'image' => '${mine}Photo',
      'file' => '$mine${last.fileName}',
      _ => '$mine${last.text}',
    };
  }

  @override
  Future<void> reactLeadMessage(String leadId, String messageId, String? emoji) async {
    (_threads[leadId] ?? []).firstWhere((x) => x.id == messageId).myReaction = emoji;
    await _wait(null);
  }

  @override
  Future<ThreadMessage> editLeadMessage(String leadId, String messageId, String text) async {
    final m = (_threads[leadId] ?? []).firstWhere((x) => x.id == messageId);
    m.text = text;
    m.edited = true;
    _refreshLastNote(leadId);
    return _wait(m);
  }

  @override
  Future<void> deleteLeadMessage(String leadId, String messageId) async {
    (_threads[leadId] ?? []).removeWhere((x) => x.id == messageId);
    _refreshLastNote(leadId);
    await _wait(null);
  }

  @override
  Future<ThreadMessage> logLeadCall(String leadId) async {
    final m = ThreadMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), from: 'business', text: 'You called', when: 'just now', kind: 'call');
    _threads.putIfAbsent(leadId, () => []).add(m);
    return _wait(m);
  }

  @override
  Future<ThreadMessage> sendLeadAttachment(String leadId, {required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress}) async {
    final m = ThreadMessage(id: DateTime.now().millisecondsSinceEpoch.toString(), from: 'business', text: '', when: 'just now', kind: kind, fileName: name, path: path, sizeBytes: size, durationMs: durationMs);
    _threads.putIfAbsent(leadId, () => []).add(m);
    final lead = _leads.firstWhere((l) => l.id == leadId);
    if (lead.status == 'new') lead.status = 'contacted';
    final secs = (durationMs / 1000).round();
    lead.lastNote = switch (kind) {
      'voice' => 'You: Voice note ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
      'image' => 'You: Photo',
      _ => 'You: $name',
    };
    _simulateReceipts(m);
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i / 4);
      await Future<void>.delayed(const Duration(milliseconds: 90));
    }
    return m;
  }

  // ---- Media
  final _stories = demoStories();
  final _reels = demoReels();
  final _comments = <String, List<Comment>>{};

  final _blocked = <String>{};
  final reportsSent = <Map<String, String>>[];

  @override
  Future<List<StoryGroup>> stories() => _wait(_stories.where((g) => !_blocked.contains(g.id)).toList());

  @override
  Future<void> markStorySeen(String groupId) async {
    final i = _stories.indexWhere((g) => g.id == groupId);
    if (i >= 0) _stories[i].seen = true;
  }

  @override
  Future<List<Reel>> reels() => _wait(_reels.where((r) => !_blocked.contains(r.businessId)).toList());

  BusinessRef _ref(Reel r) => BusinessRef(
        businessId: r.businessId,
        name: r.business,
        handle: r.handle,
        category: r.category,
        following: _reels.any((x) => x.businessId == r.businessId && x.following),
        verified: r.verified,
      );

  List<BusinessRef> _allBusinesses() {
    final seen = <String>{};
    return [for (final r in _reels) if (seen.add(r.businessId)) _ref(r)];
  }

  @override
  Future<PublicProfile> publicProfile(String businessId) async {
    final mine = _reels.where((r) => r.businessId == businessId).toList();
    final story = _stories.where((g) => g.id == businessId).toList();
    if (mine.isEmpty && story.isEmpty) throw Exception('This profile is not available');
    final first = mine.isNotEmpty ? mine.first : null;
    final name = first?.business ?? story.first.business;
    final handle = first?.handle ?? '@${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}';
    final n = int.tryParse(businessId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
    return _wait(PublicProfile(
      businessId: businessId,
      handle: handle,
      name: name,
      category: first?.category ?? story.first.category,
      about: 'Local business on ViewRec. Every review on this page is a real customer on camera.',
      verified: first?.verified ?? true,
      mine: businessId == 'b0',
      followers: 80 + n * 37,
      followingCount: 12 + n * 3,
      testimonials: 6 + n * 2,
      rating: 4.5 + (n % 5) / 10,
      following: mine.any((r) => r.following),
      blocked: _blocked.contains(businessId),
      posts: mine,
      highlights: [
        Highlight(id: 'h1', title: 'Reviews', hue: const Color(0xFF3E94F5), items: [
          StoryItem(hue: const Color(0xFF3E94F5), text: 'What our customers say', when: ''),
          StoryItem(hue: const Color(0xFF0847A0), text: 'Five stars, again', when: ''),
        ]),
        Highlight(id: 'h2', title: 'Our team', hue: const Color(0xFF1FC9A4), items: [
          StoryItem(hue: const Color(0xFF1FC9A4), text: 'Meet the people behind the work', when: ''),
        ]),
        Highlight(id: 'h3', title: 'Before and after', hue: const Color(0xFFFF6B5E), items: [
          StoryItem(hue: const Color(0xFFFF6B5E), text: 'Before', when: ''),
          StoryItem(hue: const Color(0xFFF2A100), text: 'After', when: ''),
        ]),
      ],
    ));
  }

  @override
  Future<List<BusinessRef>> followersOf(String businessId) =>
      _wait(_allBusinesses().where((b) => b.businessId != businessId && !_blocked.contains(b.businessId)).toList());

  @override
  Future<List<BusinessRef>> followingOf(String businessId) {
    final all = _allBusinesses().where((b) => b.businessId != businessId && !_blocked.contains(b.businessId)).toList();
    return _wait([for (var i = 0; i < all.length; i++) if (i.isEven) all[i]]);
  }

  @override
  Future<void> report({required String targetType, required String targetId, required String reason, String note = ''}) async {
    reportsSent.add({'targetType': targetType, 'targetId': targetId, 'reason': reason, 'note': note});
    await _wait(null);
  }

  @override
  Future<void> setBlock(String businessId, bool block) async {
    if (block) {
      _blocked.add(businessId);
      for (final r in _reels.where((r) => r.businessId == businessId)) {
        r.following = false;
      }
    } else {
      _blocked.remove(businessId);
    }
    await _wait(null);
  }

  @override
  Future<List<BusinessRef>> blockedAccounts() => _wait(_allBusinesses().where((b) => _blocked.contains(b.businessId)).toList());

  @override
  Future<void> setFollow(String businessId, bool follow) async {
    for (final r in _reels.where((r) => r.businessId == businessId)) {
      r.following = follow;
    }
    await _wait(null);
  }

  @override
  Future<void> setLike(String reelId, bool like) async {
    final r = _reels.firstWhere((x) => x.id == reelId);
    if (r.liked != like) {
      r.liked = like;
      r.likes += like ? 1 : -1;
    }
    await _wait(null);
  }

  @override
  Future<void> setSave(String reelId, bool save) async {
    _reels.firstWhere((x) => x.id == reelId).saved = save;
    await _wait(null);
  }

  @override
  Future<List<Comment>> comments(String reelId) => _wait(List.of(_comments.putIfAbsent(reelId, () => List.of(demoComments(reelId)))));

  @override
  Future<Comment> addComment(String reelId, String text) async {
    final c = Comment(id: DateTime.now().millisecondsSinceEpoch.toString(), author: 'You', text: text, when: 'now');
    _comments.putIfAbsent(reelId, () => List.of(demoComments(reelId))).add(c);
    _reels.firstWhere((x) => x.id == reelId).comments += 1;
    return _wait(c);
  }

  @override
  Future<void> createContent({required String kind, required XFile file, required bool isVideo, String caption = '', String duration = '0:00', EditSpec? edits, void Function(double)? onProgress}) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    if (kind == 'story') {
      final me = _stories.firstWhere((g) => g.mine);
      me.items.add(StoryItem(hue: const Color(0xFF0847A0), text: caption, when: 'now', mediaPath: file.path, isVideo: isVideo, edits: edits));
    } else {
      _reels.insert(
        0,
        Reel(
          id: id,
          businessId: 'b0',
          business: 'Hartley Roofing',
          handle: '@hartleyroofing',
          category: 'Home & Trades',
          caption: caption,
          reviewer: '',
          duration: duration,
          rating: 0,
          views: 0,
          likes: 0,
          comments: 0,
          hue: const Color(0xFF0A2E66),
          following: true,
          kind: kind,
          mediaPath: file.path,
          isVideo: isVideo,
          edits: edits,
        ),
      );
    }
    for (var i = 1; i <= 4; i++) {
      onProgress?.call(i / 4);
      await Future<void>.delayed(const Duration(milliseconds: 120));
    }
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

  final _notifications = [
    AppNotification(id: 'n0', kind: 'lead', title: 'Rebecca Shaw sent a request', subtitle: 'Roof inspection · 12 min ago', refId: 'l1'),
    AppNotification(id: 'n1', kind: 'video', title: 'Lena Fischer recorded a video', subtitle: 'Ready for your approval · 2h ago', refId: 'v1'),
    AppNotification(id: 'n2', kind: 'suggestion', title: '2 customers suggested', subtitle: 'Approve before invitations go out · 5h ago'),
    AppNotification(id: 'n3', kind: 'views', title: "Priya Nair's video hit 1,000 views", subtitle: 'On Google and your website · 1d ago', refId: 'v2', read: true),
    AppNotification(id: 'n4', kind: 'invite', title: 'Invitation sent to Tom Hendricks', subtitle: 'Reminder goes out in 3 days · 2d ago', read: true),
  ];

  @override
  Future<List<AppNotification>> notifications() => _wait(List.of(_notifications));

  @override
  Future<void> markNotificationRead(String id) async {
    for (final n in _notifications.where((n) => n.id == id)) {
      n.read = true;
    }
    await _wait(null);
  }

  @override
  Future<void> markAllNotificationsRead() async {
    for (final n in _notifications) {
      n.read = true;
    }
    await _wait(null);
  }

  var _planName = 'Pro';
  var _stopped = false;
  var _card = '';

  @override
  Future<BillingInfo> billing() {
    final price = plans.firstWhere((p) => p.name == _planName).price;
    return _wait(BillingInfo(
      plan: _planName,
      status: 'trial',
      trialDay: 4,
      trialLength: 15,
      afterTrialNote: _stopped ? 'Your subscription is stopped. Nothing more will be charged.' : 'then \$$price a month on $_planName, on the same card.',
      billingEmail: 'demo@viewrec.com',
      hasCard: _card.isNotEmpty,
      cardLabel: _card,
      stopped: _stopped,
      endsOn: _stopped ? '10 Dec 2026' : '',
      usage: const [UsageItem('Invitations sent', 31, 'unlimited'), UsageItem('Reminders', 22, '5 per invitation'), UsageItem('Social posts', 9, '22'), UsageItem('Loyalty rewards', 2, '15')],
      invoices: [
        const Invoice('Activation · Visa ending 0002', '\$1', 'November 19, 2026'),
        const Invoice('Activation · Visa ending 1111', '\$1', 'November 19, 2026'),
        const Invoice('Activation', '\$1', 'November 19, 2026', status: 'pending'),
        const Invoice('Activation · Visa ending 1111', '\$1', 'November 12, 2026'),
      ],
    ));
  }

  @override
  Future<void> changePlan(String planId) async {
    _planName = plans.firstWhere((p) => p.id == planId).name;
    await _wait(null);
  }

  @override
  Future<void> stopSubscription() async {
    _stopped = true;
    await _wait(null);
  }

  @override
  Future<void> resumeSubscription() async {
    _stopped = false;
    await _wait(null);
  }

  @override
  Future<String?> startCardSetup() async {
    _card = 'Visa ending 4242';
    await _wait(null);
    return null;
  }

  @override
  Future<void> removeCard() async {
    _card = '';
    await _wait(null);
  }

  @override
  Future<void> saveCard({required String number, required String name, required String expiry, required String cvc}) async {
    final digits = number.replaceAll(RegExp(r'\D'), '');
    final brand = digits.startsWith('4') ? 'Visa' : (digits.startsWith('5') ? 'Mastercard' : (digits.startsWith('3') ? 'Amex' : 'Card'));
    _card = '$brand ending ${digits.substring(digits.length - 4)}';
    await _wait(null);
  }

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

/// Who is signed in, for every request to the real API. The sign-in screen will set [token]; until then requests go without one.
class ApiAuth {
  static String? token;
  static const appVersion = '1.0.0';
  static Map<String, String> headers({bool json = false}) => {
        if (json) 'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
        'X-App-Version': appVersion,
        'X-App-Platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      };
}

class ApiRepo implements Repo {
  final String base;
  ApiRepo(this.base);

  static const _timeout = Duration(seconds: 10);

  Uri _u(String p) => Uri.parse('$base$p');

  String _err(http.Response r) {
    try {
      return (jsonDecode(r.body)['error'] ?? 'Request failed (${r.statusCode})').toString();
    } catch (_) {
      return 'Request failed (${r.statusCode})';
    }
  }

  Future<dynamic> _get(String p) async {
    final r = await http.get(_u(p), headers: ApiAuth.headers()).timeout(_timeout);
    if (r.statusCode >= 400) throw Exception(_err(r));
    return jsonDecode(r.body);
  }

  Future<dynamic> _send(String method, String p, [Map<String, dynamic>? body]) async {
    final req = http.Request(method, _u(p))..headers.addAll(ApiAuth.headers(json: true));
    if (body != null) req.body = jsonEncode(body);
    final r = await http.Response.fromStream(await req.send().timeout(_timeout));
    if (r.statusCode >= 400) throw Exception(_err(r));
    return r.body.isEmpty ? null : jsonDecode(r.body);
  }

  @override
  Future<OverviewStats> overview() async => OverviewStats.fromJson(await _get('/api/v1/overview'));

  @override
  Future<List<Customer>> customers() async => (await _get('/api/v1/customers') as List).map((e) => Customer.fromJson(e)).toList();

  @override
  Future<Customer> addCustomer({required String name, required String job, String? contact}) async =>
      Customer.fromJson(await _send('POST', '/api/v1/customers', {'name': name, 'job': job, 'contact': contact}));

  @override
  Future<void> setCustomerStatus(String id, String status) => _send('PATCH', '/api/v1/customers/$id', {'status': status});

  @override
  Future<int> remindCustomer(String id) async {
    final r = await _send('POST', '/api/v1/customers/$id/remind');
    return (r is Map ? r['nudges'] : null) as int? ?? 1;
  }

  @override
  Future<void> updateCustomer(String id, {String? name, String? job, String? contact}) =>
      _send('PATCH', '/api/v1/customers/$id', {if (name != null) 'name': name, if (job != null) 'job': job, if (contact != null) 'contact': contact});

  @override
  Future<void> deleteCustomer(String id) => _send('DELETE', '/api/v1/customers/$id', null);

  @override
  Future<List<Video>> videos() async => (await _get('/api/v1/videos') as List).map((e) => Video.fromJson(e)).toList();

  @override
  Future<void> updateVideo(String id, {String? status, List<String>? platforms, String? transcript}) =>
      _send('PATCH', '/api/v1/videos/$id', {if (status != null) 'status': status, if (platforms != null) 'platforms': platforms, if (transcript != null) 'transcript': transcript});

  @override
  Future<List<Lead>> leads() async => (await _get('/api/v1/leads') as List).map((e) => Lead.fromJson(e)).toList();

  @override
  Future<void> setLeadStatus(String id, String status) => _send('PATCH', '/api/v1/leads/$id', {'status': status});

  @override
  Future<PostsData> posts() async => PostsData.fromJson(await _get('/api/v1/posts'));

  @override
  Future<MediaInsights> mediaInsights(int days) async => MediaInsights.fromJson(await _get('/api/v1/insights/media?days=$days'));

  @override
  Future<InsightsData> insights() async => InsightsData.fromJson(await _get('/api/v1/insights'));

  @override
  Future<List<ThreadMessage>> leadMessages(String leadId) async =>
      (await _get('/api/v1/leads/$leadId/messages') as List).map((e) => ThreadMessage.fromJson(e)).toList();

  @override
  Future<ThreadMessage> sendLeadMessage(String leadId, String text) async =>
      ThreadMessage.fromJson(await _send('POST', '/api/v1/leads/$leadId/messages', {'text': text}));

  // See MOBILE_API.md for every address, request and response.
  @override
  Future<ThreadMessage> editLeadMessage(String leadId, String messageId, String text) async =>
      ThreadMessage.fromJson(await _send('PATCH', '/api/v1/leads/$leadId/messages/$messageId', {'text': text}));

  @override
  Future<void> deleteLeadMessage(String leadId, String messageId) => _send('DELETE', '/api/v1/leads/$leadId/messages/$messageId');

  @override
  Future<void> reactLeadMessage(String leadId, String messageId, String? emoji) =>
      emoji == null ? _send('DELETE', '/api/v1/leads/$leadId/messages/$messageId/reaction') : _send('PUT', '/api/v1/leads/$leadId/messages/$messageId/reaction', {'emoji': emoji});

  @override
  Future<ThreadMessage> logLeadCall(String leadId) async => ThreadMessage.fromJson(await _send('POST', '/api/v1/leads/$leadId/calls'));

  // POST /api/v1/leads/{id}/messages/attachment as multipart: file, kind, durationMs.
  @override
  Future<ThreadMessage> sendLeadAttachment(String leadId, {required String kind, required String path, required String name, int size = 0, int durationMs = 0, void Function(double)? onProgress}) async {
    final req = http.MultipartRequest('POST', _u('/api/v1/leads/$leadId/messages/attachment'))
      ..headers.addAll(ApiAuth.headers())
      ..fields['kind'] = kind
      ..fields['durationMs'] = '$durationMs'
      ..files.add(await http.MultipartFile.fromPath('file', path, filename: name));
    http.StreamedResponse res;
    try {
      res = await req.send().timeout(const Duration(minutes: 3));
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
    onProgress?.call(1);
    return ThreadMessage.fromJson(jsonDecode(body));
  }

  // ---- Media
  @override
  Future<List<StoryGroup>> stories() async => (await _get('/api/v1/stories') as List).map((e) => StoryGroup.fromJson(e)).toList();

  @override
  Future<void> markStorySeen(String groupId) => _send('POST', '/api/v1/stories/$groupId/seen');

  @override
  Future<List<Reel>> reels() async => (await _get('/api/v1/feed') as List).map((e) => Reel.fromJson(e)).toList();

  @override
  Future<void> setFollow(String businessId, bool follow) => _send(follow ? 'PUT' : 'DELETE', '/api/v1/accounts/$businessId/follow');

  @override
  Future<PublicProfile> publicProfile(String businessId) async => PublicProfile.fromJson(await _get('/api/v1/profiles/$businessId') as Map<String, dynamic>);

  @override
  Future<List<BusinessRef>> followersOf(String businessId) async => (await _get('/api/v1/profiles/$businessId/followers') as List).map((e) => BusinessRef.fromJson(e)).toList();

  @override
  Future<List<BusinessRef>> followingOf(String businessId) async => (await _get('/api/v1/profiles/$businessId/following') as List).map((e) => BusinessRef.fromJson(e)).toList();

  @override
  Future<void> report({required String targetType, required String targetId, required String reason, String note = ''}) =>
      _send('POST', '/api/v1/reports', {'targetType': targetType, 'targetId': targetId, 'reason': reason, if (note.isNotEmpty) 'note': note});

  @override
  Future<void> setBlock(String businessId, bool block) => _send(block ? 'PUT' : 'DELETE', '/api/v1/blocks/$businessId');

  @override
  Future<List<BusinessRef>> blockedAccounts() async => (await _get('/api/v1/blocks') as List).map((e) => BusinessRef.fromJson(e)).toList();

  @override
  Future<void> setLike(String reelId, bool like) => _send(like ? 'PUT' : 'DELETE', '/api/v1/posts/$reelId/like');

  @override
  Future<void> setSave(String reelId, bool save) => _send(save ? 'PUT' : 'DELETE', '/api/v1/posts/$reelId/save');

  @override
  Future<List<Comment>> comments(String reelId) async => (await _get('/api/v1/posts/$reelId/comments') as List).map((e) => Comment.fromJson(e)).toList();

  @override
  Future<Comment> addComment(String reelId, String text) async => Comment.fromJson(await _send('POST', '/api/v1/posts/$reelId/comments', {'text': text}));

  // POST /api/v1/posts as multipart: file, kind (post | reel | story), caption, duration, isVideo, edits. See MOBILE_API.md.
  @override
  Future<void> createContent({required String kind, required XFile file, required bool isVideo, String caption = '', String duration = '0:00', EditSpec? edits, void Function(double)? onProgress}) async {
    final total = await file.length();
    var sent = 0;
    final stream = file.openRead().map((chunk) {
      sent += chunk.length;
      onProgress?.call(total == 0 ? 0 : sent / total);
      return chunk;
    });
    final req = http.MultipartRequest('POST', _u('/api/v1/posts'))
      ..headers.addAll(ApiAuth.headers())
      ..fields['kind'] = kind
      ..fields['caption'] = caption
      ..fields['duration'] = duration
      ..fields['isVideo'] = '$isVideo'
      ..fields['edits'] = jsonEncode(edits?.toJson() ?? {})
      ..files.add(http.MultipartFile('file', stream, total, filename: file.name, contentType: MediaType(isVideo ? 'video' : 'image', _ext(file))));
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

  static String _ext(XFile f) {
    final n = f.name.toLowerCase();
    final dot = n.lastIndexOf('.');
    final e = dot < 0 ? '' : n.substring(dot + 1);
    return e == 'jpg' || e.isEmpty ? 'jpeg' : e;
  }

  @override
  Future<Map<String, String>> accounts() async => Map<String, String>.from(await _get('/api/v1/accounts') as Map);

  @override
  Future<void> connectAccount(String platformId) => _send('PUT', '/api/v1/accounts/$platformId');

  @override
  Future<void> disconnectAccount(String platformId) => _send('DELETE', '/api/v1/accounts/$platformId');

  @override
  Future<List<AppNotification>> notifications() async => (await _get('/api/v1/notifications') as List).map((e) => AppNotification.fromJson(e)).toList();

  @override
  Future<void> markNotificationRead(String id) => _send('POST', '/api/v1/notifications/$id/read');

  @override
  Future<void> markAllNotificationsRead() => _send('POST', '/api/v1/notifications/read-all');

  @override
  Future<BillingInfo> billing() async => BillingInfo.fromJson(await _get('/api/v1/billing'));

  @override
  Future<void> changePlan(String planId) => _send('PUT', '/api/v1/billing/plan', {'planId': planId});

  @override
  Future<void> stopSubscription() => _send('POST', '/api/v1/billing/stop');

  @override
  Future<void> resumeSubscription() => _send('POST', '/api/v1/billing/resume');

  @override
  Future<String?> startCardSetup() async {
    final r = await _send('POST', '/api/v1/billing/card-setup');
    return (r is Map ? r['url'] : null) as String?;
  }

  @override
  Future<void> removeCard() => _send('DELETE', '/api/v1/billing/card');

  @override
  Future<void> saveCard({required String number, required String name, required String expiry, required String cvc}) =>
      _send('POST', '/api/v1/billing/card', {'number': number.replaceAll(RegExp(r'\D'), ''), 'name': name, 'expiry': expiry, 'cvc': cvc});

  @override
  Future<AutomationSettings> automations() async => AutomationSettings.fromJson(await _get('/api/v1/automations'));

  @override
  Future<void> saveAutomations(AutomationSettings s) => _send('PUT', '/api/v1/automations', s.toJson());

  @override
  Future<BusinessProfile> profile() async => BusinessProfile.fromJson(await _get('/api/v1/profile'));

  @override
  Future<void> saveProfile(BusinessProfile p) => _send('PUT', '/api/v1/profile', p.toJson());

  @override
  Future<void> submitWrittenTestimonial({required String inviteToken, required int rating, required String text, required String agreedAt}) =>
      _send('POST', '/api/v1/public/invites/$inviteToken/written', {
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

    final req = http.MultipartRequest('POST', _u('/api/v1/public/invites/$inviteToken/video'))
      ..headers.addAll(ApiAuth.headers())
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
