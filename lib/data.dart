import 'package:flutter/material.dart';

class Customer {
  final String id, name, job, date, reason;
  String status; // suggested | approved | invited | recorded | skipped
  Customer({
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
  });

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
      );
}

Color _hex(String s) => Color(int.parse('FF${s.replaceAll('#', '')}', radix: 16));

List<Customer> demoCustomers() => [
      Customer(id: '1', name: 'Sarah Mitchell', job: 'Roof replacement', date: '12 days ago', reason: 'Recent job, replied to your last email', status: 'suggested'),
      Customer(id: '2', name: 'Daniel Okafor', job: 'Gutter repair', date: '3 weeks ago', reason: 'Left a 5-star Google review', status: 'suggested'),
      Customer(id: '3', name: 'Priya Nair', job: 'Full re-roof', date: '1 month ago', reason: 'Repeat customer', status: 'approved'),
      Customer(id: '4', name: 'Tom Hendricks', job: 'Chimney flashing', date: '5 weeks ago', reason: 'Recent job', status: 'invited'),
      Customer(id: '5', name: 'Lena Fischer', job: 'Skylight install', date: '6 weeks ago', reason: 'Referred two neighbours', status: 'recorded'),
      Customer(id: '6', name: 'Marcus Webb', job: 'Storm damage repair', date: '2 months ago', reason: 'Job went badly - dispute open', status: 'skipped'),
    ];

List<Video> demoVideos() => [
      Video(id: 'v1', name: 'Lena Fischer', job: 'Skylight install', duration: '1:48', quote: 'They turned up when they said they would, cleaned up after themselves, and the roof has been perfect since.', status: 'pending', views: 0, hue: const Color(0xFF3B2A6B), platforms: []),
      Video(id: 'v2', name: 'Priya Nair', job: 'Full re-roof', duration: '2:03', quote: 'Honestly the easiest builder I have ever dealt with. Fixed price, no surprises.', status: 'published', views: 1243, hue: const Color(0xFF1F4A5C), platforms: ['Google', 'Website', 'Facebook']),
      Video(id: 'v3', name: 'James Carter', job: 'Gutter replacement', duration: '1:32', quote: 'Quick, tidy and fair. I told my whole street about them.', status: 'approved', views: 312, hue: const Color(0xFF5C2A3B), platforms: ['Website']),
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
  final int price;
  final bool recommended;
  final List<String> features;
  const Plan(this.id, this.name, this.price, this.blurb, this.features, {this.recommended = false});
}

const plans = [
  Plan('std', 'Standard', 49, 'Start collecting video reviews.', ['Unlimited video testimonials', 'Review page and free public listing', 'Email and text invitations', 'One reminder after 3 days', 'Show reviews on your website']),
  Plan('pro', 'Pro', 149, 'More customers, not just more reviews.', ['Everything in Standard', 'Your logo on invitations', 'Up to 5 reminders', 'Facebook and Instagram posting', 'Embeds, wall and subtitles', 'Avatar mode for camera-shy customers'], recommended: true),
  Plan('plus', 'Pro Plus', 299, 'Marketing on more automation.', ['Everything in Pro', 'Posting on 11 platforms', 'Plan a month of posts at once', 'Discount coupons for reviewers', 'Customer loyalty rewards', 'Setup call with our team']),
];

const script = [
  'They turned up when they said they would,',
  'cleaned up after themselves,',
  'and the roof has been perfect since.',
];
