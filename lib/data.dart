import 'package:flutter/material.dart';

class Customer {
  final String id, date, reason;
  String name, job;
  /// Mobile number, if known. Needed to call them.
  String phone;
  String status; // suggested | approved | invited | recorded | skipped
  /// When the invitation went out (for example '29 Oct') and how many reminders followed it.
  String sentOn;
  int nudges;
  Customer({
    this.phone = '',
    this.sentOn = '',
    this.nudges = 0,
    required this.id,
    required this.name,
    required this.job,
    required this.date,
    required this.reason,
    required this.status,
  });

  factory Customer.fromJson(Map<String, dynamic> j) => Customer(
        id: '${j['id']}',
        name: j['name'] ?? '',
        job: j['job'] ?? '',
        date: j['date'] ?? '',
        reason: j['reason'] ?? '',
        status: j['status'] ?? 'suggested',
        phone: j['phone'] ?? '',
        sentOn: j['sentOn'] ?? '',
        nudges: j['nudges'] ?? 0,
      );
}

class Video {
  final String id, name, job, duration, quote;
  String status; // pending | approved | published
  final int views;
  final Color hue;
  List<String> platforms;
  final int rating;
  final bool written; // written testimonial vs video
  /// Where the customer agreed it can be used: Website, Social media, Marketing.
  final List<String> consent;
  final String template, submitted;
  /// How the recording was captured. [captureNotes] are things worth a look, never a reason to reject it.
  final bool captureVerified;
  final List<String> captureSignals, captureNotes;
  /// What was said (the customer's words, which you can correct) and what the AI found in it.
  String transcript;
  final String aiSummary;
  Video({
    required this.id,
    required this.name,
    required this.job,
    required this.duration,
    required this.quote,
    required this.status,
    required this.views,
    required this.hue,
    required this.platforms,
    this.rating = 5,
    this.written = false,
    List<String>? consent,
    this.template = 'Friendly',
    this.submitted = '',
    this.captureVerified = true,
    this.captureSignals = const [],
    this.captureNotes = const [],
    String? transcript,
    this.aiSummary = '',
  })  : consent = consent ?? const ['Website', 'Social media', 'Marketing'],
        transcript = transcript ?? quote;

  factory Video.fromJson(Map<String, dynamic> j) => Video(
        id: '${j['id']}',
        name: j['name'] ?? '',
        job: j['job'] ?? '',
        duration: j['duration'] ?? '',
        quote: j['quote'] ?? '',
        status: j['status'] ?? 'pending',
        views: (j['views'] ?? 0) as int,
        hue: _hex(j['hue'] ?? '#3b2a6b'),
        platforms: List<String>.from(j['platforms'] ?? const []),
        rating: (j['rating'] ?? 5) as int,
        written: j['written'] == true,
        consent: j['consent'] == null ? null : List<String>.from(j['consent']),
        template: j['template'] ?? 'Friendly',
        submitted: j['submitted'] ?? '',
        captureVerified: j['captureVerified'] != false,
        captureSignals: List<String>.from(j['captureSignals'] ?? const []),
        captureNotes: List<String>.from(j['captureNotes'] ?? const []),
        transcript: j['transcript'],
        aiSummary: j['aiSummary'] ?? '',
      );
}

Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

List<Customer> demoCustomers() => [
      Customer(id: '1', phone: '+44 7700 900137', name: 'Sarah Mitchell', job: 'Roof replacement', date: '12 days ago', reason: 'Recent job, replied to your last email', status: 'suggested'),
      Customer(id: '2', phone: '+44 7700 900274', name: 'Daniel Okafor', job: 'Gutter repair', date: '3 weeks ago', reason: 'Left a 5-star Google review', status: 'suggested'),
      Customer(id: '3', phone: '+44 7700 900411', name: 'Priya Nair', job: 'Full re-roof', date: '1 month ago', reason: 'Repeat customer', status: 'approved'),
      Customer(id: '4', phone: '+44 7700 900548', name: 'Tom Hendricks', job: 'Chimney flashing', date: '5 weeks ago', reason: 'Recent job', status: 'invited', sentOn: '29 Oct', nudges: 2),
      Customer(id: '5', phone: '+44 7700 900685', name: 'Lena Fischer', job: 'Skylight install', date: '6 weeks ago', reason: 'Referred two neighbours', status: 'recorded', sentOn: '14 Oct'),
      Customer(id: '6', phone: '+44 7700 900822', name: 'Marcus Webb', job: 'Storm damage repair', date: '2 months ago', reason: 'Job went badly - dispute open', status: 'skipped'),
    ];

List<Video> demoVideos() => [
      Video(id: 'v1', name: 'Lena Fischer', job: 'Skylight install', duration: '1:48', quote: 'They turned up when they said they would, cleaned up after themselves, and the roof has been perfect since.', status: 'pending', views: 0, hue: const Color(0xFF0A2E66), platforms: []),
      Video(id: 'v2', name: 'Priya Nair', job: 'Full re-roof', duration: '2:03', quote: 'Honestly the easiest builder I have ever dealt with. Fixed price, no surprises.', status: 'published', views: 1243, hue: const Color(0xFF1F4A5C), platforms: ['Google', 'Website', 'Facebook']),
      Video(id: 'v3', name: 'James Carter', job: 'Gutter replacement', duration: '1:32', quote: 'Quick, tidy and fair. I told my whole street about them.', status: 'approved', views: 312, hue: const Color(0xFF5C2A3B), platforms: ['Website'],
          submitted: '18 Nov 2026, 02:27',
          captureVerified: false,
          captureSignals: ['Recorded in the browser during this session.', 'Submitted 165s after the session opened.', '5s recording inside a 165s session.', '1779KB received.', 'Permission was given in this session.', '2 takes before the one submitted.'],
          captureNotes: ['Recorded from the same network as 1 other testimonial for this business within 30 days.'],
          aiSummary: 'Theme: speed and tidiness. Tone: warm and positive. Mentions: the gutters, the crew.'),
      Video(id: 'v4', name: 'Aisha Rahman', job: 'Flat roof repair', duration: '1:55', quote: 'Three other firms never called back. These guys fixed the leak in a day.', status: 'published', views: 874, hue: const Color(0xFF2A5C3F), platforms: ['Instagram', 'YouTube']),
      Video(id: 'v5', name: 'Hannah Cole', job: 'Boiler service', duration: '', quote: 'Booked online, engineer arrived early and explained everything. Would recommend to anyone.', status: 'published', views: 96, hue: const Color(0xFF3F3A2A), platforms: ['Google'], rating: 5, written: true),
      Video(id: 'v6', name: 'Omar Haddad', job: 'Kitchen fitting', duration: '0:58', quote: 'Finished a day early and left it spotless.', status: 'approved', views: 41, hue: const Color(0xFF2A3F5C), platforms: [], rating: 4),
    ];

class Platform {
  final String id, name;
  final IconData icon;
  const Platform(this.id, this.name, this.icon);
}

const platforms = [
  Platform('google', 'Google Business Profile', Icons.storefront_rounded),
  Platform('web', 'Your website', Icons.language_rounded),
  Platform('fb', 'Facebook', Icons.facebook_rounded),
  Platform('ig', 'Instagram', Icons.photo_camera_rounded),
  Platform('yt', 'YouTube', Icons.smart_display_rounded),
  Platform('tt', 'TikTok', Icons.music_note_rounded),
  Platform('li', 'LinkedIn', Icons.work_outline_rounded),
  Platform('pin', 'Pinterest', Icons.push_pin_rounded),
];

class Plan {
  final String id, name, blurb;
  /// Dollars a month. 0 for Managed Services, which is priced for each business.
  final int price;
  final bool recommended;
  final List<String> features;
  /// Everything switched on for this plan, and whether it is still being built (shown as "in build").
  final List<(String, bool)> onThisPlan;
  const Plan(this.id, this.name, this.price, this.blurb, this.features, {this.recommended = false, this.onThisPlan = const []});
  bool get custom => price == 0;
  String get priceLabel => custom ? 'Custom' : '\$$price';
}

const _std = <(String, bool)>[
  ('Credit for everyone you bring', false),
  ('AI support, and a ticket when it cannot help', false),
  ('Invitations and follow-ups written for you', false),
];

const _pro = <(String, bool)>[
  ('Credit for everyone you bring', false),
  ('AI support, and a ticket when it cannot help', false),
  ('Posting to Facebook and Instagram for you', false),
  ('Invitations and follow-ups written for you', false),
  ('Embeds and the testimonial wall', false),
  ('Automatic reminders, on your own schedule', false),
  ('Your logo on every invitation', false),
  ('Your logo on the thank-you screen', false),
  ('Contact groups', false),
  ('Subtitles on the video', false),
  ('Your questions answered first', false),
  ('Customer Loyalty rewards', true),
];

const _plus = <(String, bool)>[
  ..._pro,
  ('Posting on 11 platforms', true),
  ('Remove the ViewRec watermark from your videos', false),
  ('A month of posts planned in one sitting', true),
  ('Design tools, templates and content workflows', true),
  ('Discount coupons for customers who review you', true),
];

const plans = [
  Plan('std', 'Standard', 49, 'For small businesses that want to start collecting video reviews.', [
    'Unlimited video testimonials',
    'A review page and a free public listing',
    'Email and text invitations, written for you',
    'One reminder, sent after 3 days',
    'Jobsite video combined with the review',
    'Show your reviews on your own website',
    'Referral credit for businesses you bring',
  ], onThisPlan: _std),
  Plan('pro', 'Pro', 149, 'For busy businesses that want more customers, not just more reviews.', [
    'Everything in Standard',
    'Your logo on invitations and thank-you pages',
    'Up to 5 reminders on your own schedule',
    'Posting to Facebook and Instagram, with no monthly limit',
    'Embeds, testimonial wall and video subtitles',
    'Request button and Pro badge in the directory',
    'Avatar mode for camera-shy customers',
    'Your questions answered first',
  ], recommended: true, onThisPlan: _pro),
  Plan('plus', 'Pro Plus', 299, 'For businesses that want their marketing to run with more automation and content.', [
    'Everything in Pro',
    'Posting on 11 platforms, 22 posts a month',
    'Plan a full month of posts in one sitting',
    'Design tools, templates and content workflows',
    'Discount coupons for customers who review you',
    'Customer Loyalty rewards: up to 15 a month',
    'A setup call with our team',
  ], onThisPlan: _plus),
  Plan('managed', 'Managed Services', 0, 'For businesses that want the ViewRec team to run their marketing.', [
    'Everything in Pro Plus',
    'Your own agent, available around the clock',
    'We run your Google, Meta and Local Services ads',
    'Your business profiles kept active',
    'Customer rewards handled by our team',
    'Scope and fee tailored to your business',
  ], onThisPlan: [..._plus, ('Your Google, Meta and Local Services ads run for you', true), ('Your own agent, around the clock', true)]),
];

const script = [
  'They turned up when they said they would,',
  'cleaned up after themselves,',
  'and the roof has been perfect since.',
];
