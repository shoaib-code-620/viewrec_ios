// Data models for everything the dashboard shows. Each has fromJson/toJson,
// and these shapes ARE the API contract (see API_CONTRACT.md).

class OverviewStats {
  final int testimonials, videos, waiting, customers, invitesSent, reviewPages, linkedAccounts, embeds;
  final double averageRating;
  final String videoLink;
  const OverviewStats({
    required this.testimonials,
    required this.videos,
    required this.waiting,
    required this.averageRating,
    required this.customers,
    required this.invitesSent,
    required this.reviewPages,
    required this.linkedAccounts,
    required this.embeds,
    required this.videoLink,
  });
  factory OverviewStats.fromJson(Map<String, dynamic> j) => OverviewStats(
        testimonials: j['testimonials'] ?? 0,
        videos: j['videos'] ?? 0,
        waiting: j['waiting'] ?? 0,
        averageRating: (j['averageRating'] ?? 0).toDouble(),
        customers: j['customers'] ?? 0,
        invitesSent: j['invitesSent'] ?? 0,
        reviewPages: j['reviewPages'] ?? 0,
        linkedAccounts: j['linkedAccounts'] ?? 0,
        embeds: j['embeds'] ?? 0,
        videoLink: j['videoLink'] ?? '',
      );
}

class Lead {
  final String id, name, service, message, when, source;
  String status; // new | contacted | won | lost
  Lead({required this.id, required this.name, required this.service, required this.message, required this.when, required this.source, required this.status});
  factory Lead.fromJson(Map<String, dynamic> j) => Lead(
        id: '${j['id']}',
        name: j['name'] ?? '',
        service: j['service'] ?? '',
        message: j['message'] ?? '',
        when: j['when'] ?? '',
        source: j['source'] ?? '',
        status: j['status'] ?? 'new',
      );
}

class Post {
  final String id, title, platform, when, status; // status: scheduled | published | failed
  final int reactions;
  const Post({required this.id, required this.title, required this.platform, required this.when, required this.status, this.reactions = 0});
  factory Post.fromJson(Map<String, dynamic> j) => Post(
        id: '${j['id']}',
        title: j['title'] ?? '',
        platform: j['platform'] ?? '',
        when: j['when'] ?? '',
        status: j['status'] ?? 'scheduled',
        reactions: j['reactions'] ?? 0,
      );
}

class PostsData {
  final List<Post> posts;
  final int usedThisMonth, monthlyLimit;
  const PostsData({required this.posts, required this.usedThisMonth, required this.monthlyLimit});
  factory PostsData.fromJson(Map<String, dynamic> j) => PostsData(
        posts: (j['posts'] as List? ?? []).map((e) => Post.fromJson(e)).toList(),
        usedThisMonth: j['usedThisMonth'] ?? 0,
        monthlyLimit: j['monthlyLimit'] ?? 0,
      );
}

class AppNotification {
  final String id, kind, title, subtitle; // kind: video | suggestion | views | invite | lead
  const AppNotification({required this.id, required this.kind, required this.title, required this.subtitle});
  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: '${j['id']}',
        kind: j['kind'] ?? 'video',
        title: j['title'] ?? '',
        subtitle: j['subtitle'] ?? '',
      );
}

class UsageItem {
  final String label, limit;
  final int used;
  const UsageItem(this.label, this.used, this.limit);
  factory UsageItem.fromJson(Map<String, dynamic> j) => UsageItem(j['label'] ?? '', j['used'] ?? 0, '${j['limit'] ?? ''}');
}

class Invoice {
  final String title, amount, date;
  const Invoice(this.title, this.amount, this.date);
  factory Invoice.fromJson(Map<String, dynamic> j) => Invoice(j['title'] ?? '', j['amount'] ?? '', j['date'] ?? '');
}

class BillingInfo {
  final String plan, status; // status: trial | active | past_due | cancelled
  final int trialDay, trialLength;
  final String afterTrialNote, billingEmail;
  final bool hasCard;
  final List<UsageItem> usage;
  final List<Invoice> invoices;
  const BillingInfo({
    required this.plan,
    required this.status,
    required this.trialDay,
    required this.trialLength,
    required this.afterTrialNote,
    required this.billingEmail,
    required this.hasCard,
    required this.usage,
    required this.invoices,
  });
  factory BillingInfo.fromJson(Map<String, dynamic> j) => BillingInfo(
        plan: j['plan'] ?? '',
        status: j['status'] ?? 'trial',
        trialDay: j['trialDay'] ?? 0,
        trialLength: j['trialLength'] ?? 15,
        afterTrialNote: j['afterTrialNote'] ?? '',
        billingEmail: j['billingEmail'] ?? '',
        hasCard: j['hasCard'] == true,
        usage: (j['usage'] as List? ?? []).map((e) => UsageItem.fromJson(e)).toList(),
        invoices: (j['invoices'] as List? ?? []).map((e) => Invoice.fromJson(e)).toList(),
      );
}

class AutomationSettings {
  bool requestAfterJob, autoInvite, thankYou, reminders, autoPublish, politeHours;
  int reminderCount, gapDays;
  String channel; // sms_email | sms | email | whatsapp
  AutomationSettings({
    this.requestAfterJob = true,
    this.autoInvite = true,
    this.thankYou = true,
    this.reminders = true,
    this.autoPublish = false,
    this.politeHours = true,
    this.reminderCount = 2,
    this.gapDays = 3,
    this.channel = 'sms_email',
  });
  factory AutomationSettings.fromJson(Map<String, dynamic> j) => AutomationSettings(
        requestAfterJob: j['requestAfterJob'] ?? true,
        autoInvite: j['autoInvite'] ?? true,
        thankYou: j['thankYou'] ?? true,
        reminders: j['reminders'] ?? true,
        autoPublish: j['autoPublish'] ?? false,
        politeHours: j['politeHours'] ?? true,
        reminderCount: j['reminderCount'] ?? 2,
        gapDays: j['gapDays'] ?? 3,
        channel: j['channel'] ?? 'sms_email',
      );
  Map<String, dynamic> toJson() => {
        'requestAfterJob': requestAfterJob,
        'autoInvite': autoInvite,
        'thankYou': thankYou,
        'reminders': reminders,
        'autoPublish': autoPublish,
        'politeHours': politeHours,
        'reminderCount': reminderCount,
        'gapDays': gapDays,
        'channel': channel,
      };
}

class BusinessProfile {
  String name, category, phone, email, website, area, about;
  BusinessProfile({this.name = '', this.category = '', this.phone = '', this.email = '', this.website = '', this.area = '', this.about = ''});
  factory BusinessProfile.fromJson(Map<String, dynamic> j) => BusinessProfile(
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        phone: j['phone'] ?? '',
        email: j['email'] ?? '',
        website: j['website'] ?? '',
        area: j['area'] ?? '',
        about: j['about'] ?? '',
      );
  Map<String, dynamic> toJson() => {'name': name, 'category': category, 'phone': phone, 'email': email, 'website': website, 'area': area, 'about': about};
}

class PlatformViews {
  final String platform;
  final int views;
  const PlatformViews(this.platform, this.views);
  factory PlatformViews.fromJson(Map<String, dynamic> j) => PlatformViews(j['platform'] ?? '', j['views'] ?? 0);
}

class InsightsData {
  final List<int> weeklyViews; // last 8 weeks, oldest first
  final int totalViews, plays, linkClicks, avgWatchPercent;
  final double responseRate; // 0..1
  final List<PlatformViews> byPlatform;
  const InsightsData({
    required this.weeklyViews,
    required this.totalViews,
    required this.plays,
    required this.linkClicks,
    required this.avgWatchPercent,
    required this.responseRate,
    required this.byPlatform,
  });
  factory InsightsData.fromJson(Map<String, dynamic> j) => InsightsData(
        weeklyViews: List<int>.from(j['weeklyViews'] ?? const []),
        totalViews: j['totalViews'] ?? 0,
        plays: j['plays'] ?? 0,
        linkClicks: j['linkClicks'] ?? 0,
        avgWatchPercent: j['avgWatchPercent'] ?? 0,
        responseRate: (j['responseRate'] ?? 0).toDouble(),
        byPlatform: (j['byPlatform'] as List? ?? []).map((e) => PlatformViews.fromJson(e)).toList(),
      );
}

class ThreadMessage {
  final String id, from, text, when; // from: customer | business
  const ThreadMessage({required this.id, required this.from, required this.text, required this.when});
  factory ThreadMessage.fromJson(Map<String, dynamic> j) => ThreadMessage(
        id: '${j['id']}',
        from: j['from'] ?? 'customer',
        text: j['text'] ?? '',
        when: j['when'] ?? '',
      );
}
