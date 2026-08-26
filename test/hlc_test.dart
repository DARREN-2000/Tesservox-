import 'package:flutter_test/flutter_test.dart';
import 'package:tesservox/domain/hlc.dart';

void main() {
  test('tick is monotonic even when the wall clock jumps backwards', () {
    // Cheap tablets do this constantly: NTP corrects, someone changes the
    // timezone, the battery dies. A stamp that goes backwards silently loses
    // an edit, which here means losing a word someone added to their board.
    Hlc stamp = const Hlc.zero('tablet');
    final List<Hlc> history = <Hlc>[];
    for (final int wallClock in <int>[1000, 1001, 900, 900, 800, 2000]) {
      stamp = stamp.tick(wallClock);
      history.add(stamp);
    }

    for (int i = 1; i < history.length; i++) {
      expect(
        history[i] > history[i - 1],
        isTrue,
        reason: '${history[i]} must sort after ${history[i - 1]}',
      );
    }
  });

  test('a device that thinks it is 1970 stops losing every conflict', () {
    // The school tablet has never seen the internet.
    final Hlc tablet = const Hlc.zero('tablet').tick(0);
    // The parent's phone has a correct clock.
    final Hlc phone = const Hlc.zero('phone').tick(1755721234567);

    expect(tablet < phone, isTrue, reason: 'before any sync the tablet loses');

    // One received op is enough: the tablet absorbs the phone's knowledge of
    // time, so the next edit made on the tablet wins on merit rather than
    // being discarded forever.
    final Hlc afterSync = tablet.receive(phone, 0);
    expect(afterSync > phone, isTrue);
    expect(afterSync.deviceId, 'tablet');
  });

  test('receive is monotonic against both local and remote history', () {
    Hlc local = const Hlc.zero('a').tick(5000);
    final Hlc remote = const Hlc.zero('b').tick(4000);
    final Hlc before = local;
    local = local.receive(remote, 3000); // wall clock behind both
    expect(local > before, isTrue);
    expect(local > remote, isTrue);
  });

  test('the order is total, so two devices can never both think they won', () {
    const Hlc a = Hlc(500, 0, 'device-a');
    const Hlc b = Hlc(500, 0, 'device-b');

    expect(a == b, isFalse);
    expect(a < b, isTrue);
    expect(b > a, isTrue);
    expect(a.compareTo(b), -b.compareTo(a), reason: 'antisymmetric');
  });

  test('encode and parse round-trip, including colons in the device id', () {
    const Hlc original = Hlc(1755721234567, 3, 'ta:blet:01');
    final Hlc parsed = Hlc.parse(original.encode());
    expect(parsed, original);
    expect(parsed.deviceId, 'ta:blet:01');
    expect(parsed.counter, 3);
  });

  test('malformed stamps are rejected rather than silently zeroed', () {
    expect(() => Hlc.parse('nope'), throwsFormatException);
    expect(() => Hlc.parse('a:b:c'), throwsFormatException);
    expect(() => Hlc.parse('1:2'), throwsFormatException);
  });
}
