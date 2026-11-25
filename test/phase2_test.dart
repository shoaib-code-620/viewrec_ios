import 'package:flutter_test/flutter_test.dart';
import 'package:viewrec/repo.dart';

void main() {
  test('profile, follower lists, report and block work on the sample data', () async {
    final r = MockRepo();
    final p = await r.publicProfile('b1');
    expect(p.name, 'Brightside Dental');
    expect(p.posts, isNotEmpty);
    expect(p.blocked, isFalse);

    final followers = await r.followersOf('b1');
    expect(followers.any((b) => b.businessId == 'b1'), isFalse, reason: 'a business is not its own follower');
    expect(followers, isNotEmpty);

    await r.report(targetType: 'post', targetId: 'r1', reason: 'spam', note: 'test');
    expect(r.reportsSent.single['reason'], 'spam');

    await r.setBlock('b1', true);
    expect((await r.reels()).any((x) => x.businessId == 'b1'), isFalse);
    expect((await r.stories()).any((g) => g.id == 'b1'), isFalse);
    expect((await r.blockedAccounts()).single.businessId, 'b1');
    expect((await r.followersOf('b2')).any((b) => b.businessId == 'b1'), isFalse);

    await r.setBlock('b1', false);
    expect((await r.reels()).any((x) => x.businessId == 'b1'), isTrue);
    expect(await r.blockedAccounts(), isEmpty);
  });

  test('a profile that does not exist is refused', () async {
    expect(MockRepo().publicProfile('nope'), throwsException);
  });
}
