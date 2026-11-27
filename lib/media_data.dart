import 'package:flutter/material.dart';

/// Bumped after something is posted, so Home and Media reload their feeds.
final ValueNotifier<int> mediaRevision = ValueNotifier(0);

Color colorFromHex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

/// A piece of text placed on a photo or video. [dx]/[dy] are 0..1 positions inside the frame.
class TextOverlay {
  String text;
  double dx, dy;
  int color;
  TextOverlay({required this.text, this.dx = 0.5, this.dy = 0.5, this.color = 0xFFFFFFFF});
  Map<String, dynamic> toJson() => {'text': text, 'dx': dx, 'dy': dy, 'color': color};
  factory TextOverlay.fromJson(Map<String, dynamic> j) => TextOverlay(text: j['text'] ?? '', dx: (j['dx'] ?? 0.5).toDouble(), dy: (j['dy'] ?? 0.5).toDouble(), color: j['color'] ?? 0xFFFFFFFF);
}

/// Edits chosen in the editor. They are applied when the media plays; the original file is not changed.
class EditSpec {
  double trimStart, trimEnd; // 0..1 of the video length
  int filter; // index into the filter list
  double speed;
  bool muted;
  List<TextOverlay> texts;
  EditSpec({this.trimStart = 0, this.trimEnd = 1, this.filter = 0, this.speed = 1, this.muted = false, List<TextOverlay>? texts}) : texts = texts ?? [];
  bool get isEmpty => trimStart == 0 && trimEnd == 1 && filter == 0 && speed == 1 && !muted && texts.isEmpty;
  Map<String, dynamic> toJson() => {'trimStart': trimStart, 'trimEnd': trimEnd, 'filter': filter, 'speed': speed, 'muted': muted, 'texts': texts.map((t) => t.toJson()).toList()};
  factory EditSpec.fromJson(Map<String, dynamic> j) => EditSpec(
        trimStart: (j['trimStart'] ?? 0).toDouble(),
        trimEnd: (j['trimEnd'] ?? 1).toDouble(),
        filter: j['filter'] ?? 0,
        speed: (j['speed'] ?? 1).toDouble(),
        muted: j['muted'] == true,
        texts: (j['texts'] as List? ?? []).map((e) => TextOverlay.fromJson(e)).toList(),
      );
}

/// One slide inside a story.
class StoryItem {
  final Color hue;
  final String text, when;
  /// A photo or video (file path or URL). Null for the plain coloured demo slides.
  final String? mediaPath;
  final bool isVideo;
  final EditSpec? edits;
  const StoryItem({required this.hue, required this.text, required this.when, this.mediaPath, this.isVideo = false, this.edits});
  factory StoryItem.fromJson(Map<String, dynamic> j) => StoryItem(
        hue: colorFromHex(j['hue'] ?? '#5B3FE0'),
        text: j['text'] ?? '',
        when: j['when'] ?? '',
        mediaPath: j['mediaUrl'],
        isVideo: j['isVideo'] == true,
        edits: j['edits'] is Map<String, dynamic> ? EditSpec.fromJson(j['edits']) : null,
      );
}

/// A business's stories, shown as one circle at the top of the Media page.
class StoryGroup {
  final String id, business, category;
  bool seen;
  final bool mine;
  final List<StoryItem> items;
  StoryGroup({required this.id, required this.business, required this.category, this.seen = false, this.mine = false, this.items = const []});
  factory StoryGroup.fromJson(Map<String, dynamic> j) => StoryGroup(
        id: '${j['id']}',
        business: j['business'] ?? '',
        category: j['category'] ?? '',
        seen: j['seen'] == true,
        mine: j['mine'] == true,
        items: (j['items'] as List? ?? []).map((e) => StoryItem.fromJson(e)).toList(),
      );
}

/// A customer testimonial shown as a reel in the feed.
class Reel {
  final String id, businessId, business, handle, category, reviewer, duration;
  /// The text under the post. #tags and @mentions in it are tappable.
  String caption;
  final int rating, views;
  int likes, comments;
  final Color hue;
  bool liked, saved, following;
  final bool verified;
  /// 'testimonial' (customer video), 'post' or 'reel' (made by the business in the Create menu).
  final String kind;
  /// Uploaded photo or video (file path or URL). Null for demo content, which shows a coloured background.
  final String? mediaPath;
  final bool isVideo;
  final EditSpec? edits;
  Reel({
    this.edits,
    this.kind = 'testimonial',
    this.mediaPath,
    this.isVideo = false,
    required this.id,
    required this.businessId,
    required this.business,
    required this.handle,
    required this.category,
    required this.caption,
    required this.reviewer,
    required this.duration,
    required this.rating,
    required this.views,
    required this.likes,
    required this.comments,
    required this.hue,
    this.liked = false,
    this.saved = false,
    this.following = false,
    this.verified = true,
  });
  factory Reel.fromJson(Map<String, dynamic> j) => Reel(
        id: '${j['id']}',
        businessId: '${j['businessId']}',
        business: j['business'] ?? '',
        handle: j['handle'] ?? '',
        category: j['category'] ?? '',
        caption: j['caption'] ?? '',
        reviewer: j['reviewer'] ?? '',
        duration: j['duration'] ?? '',
        rating: j['rating'] ?? 5,
        views: j['views'] ?? 0,
        likes: j['likes'] ?? 0,
        comments: j['comments'] ?? 0,
        hue: colorFromHex(j['hue'] ?? '#5B3FE0'),
        liked: j['liked'] == true,
        saved: j['saved'] == true,
        following: j['following'] == true,
        verified: j['verified'] != false,
        kind: j['kind'] ?? 'testimonial',
        mediaPath: j['mediaUrl'],
        isVideo: j['isVideo'] == true,
        edits: j['edits'] is Map<String, dynamic> ? EditSpec.fromJson(j['edits']) : null,
      );
}

/// A business in a follower, following or blocked list.
class BusinessRef {
  final String businessId, name, handle, category;
  bool following;
  final bool verified;
  BusinessRef({required this.businessId, required this.name, required this.handle, this.category = '', this.following = false, this.verified = true});
  factory BusinessRef.fromJson(Map<String, dynamic> j) => BusinessRef(
        businessId: '${j['businessId']}',
        name: j['name'] ?? '',
        handle: j['handle'] ?? '',
        category: j['category'] ?? '',
        following: j['following'] == true,
        verified: j['verified'] != false,
      );
}

/// A saved set of stories kept on a business's profile, like Instagram's highlights.
class Highlight {
  final String id, title;
  final Color hue;
  final List<StoryItem> items;
  const Highlight({required this.id, required this.title, required this.hue, this.items = const []});
  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        id: '${j['id']}',
        title: j['title'] ?? '',
        hue: colorFromHex(j['hue'] ?? '#3E94F5'),
        items: [for (final e in (j['items'] as List? ?? [])) StoryItem.fromJson(e)],
      );
}

/// A business's public page in the Media tab.
class PublicProfile {
  final String businessId, handle, name, category, about;
  final bool verified, mine;
  int followers, followingCount, testimonials;
  final double rating;
  bool following, blocked;
  final List<Reel> posts;
  final List<Highlight> highlights;
  /// Every like on this business's posts, shown on the profile.
  int get likes => posts.fold(0, (a, r) => a + r.likes);
  PublicProfile({
    required this.businessId,
    required this.handle,
    required this.name,
    required this.category,
    this.about = '',
    this.verified = true,
    this.mine = false,
    this.followers = 0,
    this.followingCount = 0,
    this.testimonials = 0,
    this.rating = 0,
    this.following = false,
    this.blocked = false,
    this.posts = const [],
    this.highlights = const [],
  });
  factory PublicProfile.fromJson(Map<String, dynamic> j) => PublicProfile(
        businessId: '${j['businessId']}',
        handle: j['handle'] ?? '',
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        about: j['about'] ?? '',
        verified: j['verified'] != false,
        mine: j['mine'] == true,
        followers: j['followers'] ?? 0,
        followingCount: j['followingCount'] ?? 0,
        testimonials: j['testimonials'] ?? 0,
        rating: (j['rating'] ?? 0).toDouble(),
        following: j['following'] == true,
        blocked: j['blocked'] == true,
        posts: (j['posts'] as List? ?? []).map((e) => Reel.fromJson(e)).toList(),
        highlights: [for (final e in (j['highlights'] as List? ?? [])) Highlight.fromJson(e)],
      );
}

/// Why someone reports content. The key goes to the server.
const reportReasons = [
  ('spam', 'Spam or a scam'),
  ('abusive', 'Abusive or hateful'),
  ('misleading', 'Misleading or fake'),
  ('inappropriate', 'Inappropriate content'),
  ('other', 'Something else'),
];

class Comment {
  final String id, author, text, when;
  const Comment({required this.id, required this.author, required this.text, required this.when});
  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
        id: '${j['id']}',
        author: j['author'] ?? '',
        text: j['text'] ?? '',
        when: j['when'] ?? '',
      );
}

// ---------------------------------------------------------------------------
// Sample content (neutral names, used until the real backend exists)
// ---------------------------------------------------------------------------

List<StoryGroup> demoStories() => [
      StoryGroup(id: 'me', business: 'Your story', category: '', mine: true, items: <StoryItem>[]),
      StoryGroup(id: 'b1', business: 'Brightside Dental', category: 'Health & Medical', items: const [
        StoryItem(hue: Color(0xFF3E94F5), text: 'New patients welcome this month', when: '2h'),
        StoryItem(hue: Color(0xFF0F9F78), text: 'Meet Dr. Hall and the team', when: '5h'),
      ]),
      StoryGroup(id: 'b2', business: 'Northgate Autos', category: 'Automotive', items: const [
        StoryItem(hue: Color(0xFFFF6B5E), text: 'Free winter check this week', when: '1h'),
      ]),
      StoryGroup(id: 'b3', business: 'Green Leaf Landscaping', category: 'Home & Trades', items: const [
        StoryItem(hue: Color(0xFF0F9F78), text: 'Before and after: Elm Road garden', when: '3h'),
        StoryItem(hue: Color(0xFF0A2E66), text: 'Spring bookings are open', when: '6h'),
        StoryItem(hue: Color(0xFFF2A100), text: 'Our crew at work', when: '9h'),
      ]),
      StoryGroup(id: 'b7', business: 'Ember Kitchen', category: 'Food & Restaurants', items: const [
        StoryItem(hue: Color(0xFFF2A100), text: "Tonight's special: slow-cooked lamb", when: '30m'),
      ]),
      StoryGroup(id: 'b5', business: 'Summit Fitness', category: 'Beauty & Wellness', seen: true, items: const [
        StoryItem(hue: Color(0xFF0847A0), text: '6am class is back', when: '8h'),
      ]),
      StoryGroup(id: 'b6', business: 'Harbour Plumbing', category: 'Home & Trades', seen: true, items: const [
        StoryItem(hue: Color(0xFF1F4A5C), text: '24/7 emergency line', when: '11h'),
      ]),
      StoryGroup(id: 'b9', business: 'Clearview Windows', category: 'Construction', seen: true, items: const [
        StoryItem(hue: Color(0xFF2A5C3F), text: 'New double glazing range', when: '14h'),
      ]),
    ];

List<Reel> demoReels() => _tagged([
      Reel(id: 'r1', businessId: 'b1', business: 'Brightside Dental', handle: '@brightsidedental', category: 'Health & Medical', reviewer: 'Emma Clarke', caption: 'Painless, friendly and they explained every step. My daughter actually asked to go back!', duration: '0:48', rating: 5, views: 3200, likes: 412, comments: 28, hue: const Color(0xFF3E94F5), following: true),
      Reel(id: 'r2', businessId: 'b2', business: 'Northgate Autos', handle: '@northgateautos', category: 'Automotive', reviewer: 'Liam Foster', caption: 'Quoted £280, charged £280. Car back a day early. Honest garage at last.', duration: '1:02', rating: 5, views: 1800, likes: 233, comments: 14, hue: const Color(0xFFFF6B5E)),
      Reel(id: 'r3', businessId: 'b3', business: 'Green Leaf Landscaping', handle: '@greenleafgardens', category: 'Home & Trades', reviewer: 'Chloe Bennett', caption: 'Our garden looks like a magazine now. Tidy crew, and they took all the rubbish away.', duration: '1:15', rating: 5, views: 5400, likes: 689, comments: 51, hue: const Color(0xFF0F9F78), following: true),
      Reel(id: 'r4', businessId: 'b0', business: 'Hartley Roofing', handle: '@hartleyroofing', category: 'Home & Trades', reviewer: 'Lena Fischer', caption: 'They turned up when they said they would, cleaned up after themselves, and the roof has been perfect since.', duration: '1:48', rating: 5, views: 2100, likes: 301, comments: 19, hue: const Color(0xFF0A2E66), following: true),
      Reel(id: 'r5', businessId: 'b4', business: 'Willow & Co Interiors', handle: '@willowandco', category: 'Property & Real Estate', reviewer: 'Hannah Price', caption: 'They found us the perfect flat in a week and handled every bit of paperwork.', duration: '0:55', rating: 4, views: 960, likes: 118, comments: 7, hue: const Color(0xFF8CC3FF)),
      Reel(id: 'r6', businessId: 'b5', business: 'Summit Fitness', handle: '@summitfitness', category: 'Beauty & Wellness', reviewer: 'Jack Turner', caption: 'Lost 9kg in three months. The coaches genuinely care about your progress.', duration: '1:10', rating: 5, views: 4100, likes: 540, comments: 36, hue: const Color(0xFF0847A0)),
      Reel(id: 'r7', businessId: 'b6', business: 'Harbour Plumbing', handle: '@harbourplumbing', category: 'Home & Trades', reviewer: 'Olivia Grant', caption: 'Fixed a leak at 9pm on a Sunday. Absolute lifesaver, and a fair price too.', duration: '0:41', rating: 5, views: 2600, likes: 355, comments: 22, hue: const Color(0xFF1F4A5C)),
      Reel(id: 'r8', businessId: 'b7', business: 'Ember Kitchen', handle: '@emberkitchen', category: 'Food & Restaurants', reviewer: 'Noah Hughes', caption: "Best birthday dinner we've ever had. The staff made it feel really special.", duration: '0:52', rating: 5, views: 7300, likes: 902, comments: 64, hue: const Color(0xFFF2A100)),
      Reel(id: 'r9', businessId: 'b8', business: 'Atlas Movers', handle: '@atlasmovers', category: 'Logistics & Transport', reviewer: 'Grace Morgan', caption: 'Moved a three-bed house in one day with zero breakages. Brilliant team.', duration: '1:20', rating: 5, views: 1500, likes: 190, comments: 11, hue: const Color(0xFF3F3A2A)),
      Reel(id: 'r10', businessId: 'b9', business: 'Clearview Windows', handle: '@clearviewwindows', category: 'Construction', reviewer: 'Ethan Cole', caption: 'The house is warmer and so much quieter. Fitted in a single afternoon.', duration: '0:59', rating: 4, views: 1100, likes: 144, comments: 9, hue: const Color(0xFF2A5C3F)),
    ]);

/// Sample posts get a couple of hashtags, so tags can be tried before the real feed exists.
List<Reel> _tagged(List<Reel> list) {
  for (final r in list) {
    final first = r.business.split(RegExp(r'[^A-Za-z]+')).first.toLowerCase();
    final cat = r.category.split(RegExp(r'[^A-Za-z]+')).first.toLowerCase();
    r.caption = '${r.caption} #${r.rating}stars #$first #$cat';
  }
  return list;
}

List<Comment> demoComments(String reelId) => const [
      Comment(id: 'c1', author: 'Sophie Walker', text: 'This is exactly what I was looking for, thank you for sharing!', when: '2h'),
      Comment(id: 'c2', author: 'Daniel Rhodes', text: 'Used them last year too. Totally agree.', when: '5h'),
      Comment(id: 'c3', author: 'Maya Collins', text: 'Great to see real customers talking. Following!', when: '1d'),
    ];
