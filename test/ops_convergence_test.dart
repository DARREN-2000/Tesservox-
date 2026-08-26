import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tesservox/domain/hlc.dart';
import 'package:tesservox/domain/ops.dart';

/// Two devices edit the same board with no server between them. These tests
/// state the properties that make that safe:
///
///   * commutative -- op arrival order cannot matter
///   * idempotent  -- a re-scanned QR bundle or replayed file is a no-op
///   * total order -- both devices always agree on the winner
///
/// Written as properties over generated logs rather than as examples, because
/// the failure mode in the field is a specific interleaving nobody thought of.
void main() {
  test('op order does not matter: shuffled logs converge exactly', () {
    final List<Op> log = _sampleLog();
    final OpStore reference = OpStore()..applyAll(log);
    final Random random = Random(1312);

    for (int trial = 0; trial < 200; trial++) {
      final List<Op> shuffled = List<Op>.of(log)..shuffle(random);
      final OpStore replica = OpStore()..applyAll(shuffled);
      expect(replica.fingerprint(), reference.fingerprint());
      expect(replica.slotCount, reference.slotCount);
    }
  });

  test('applying the same log twice changes nothing', () {
    final List<Op> log = _sampleLog();
    final OpStore store = OpStore()..applyAll(log);
    final String before = store.fingerprint();

    final int changed = store.applyAll(log);

    expect(changed, 0, reason: 'a re-scanned QR bundle must be a no-op');
    expect(store.fingerprint(), before);
  });

  test('a partial sync followed by a full sync reaches the same state', () {
    final List<Op> log = _sampleLog();
    final OpStore full = OpStore()..applyAll(log);

    // Deliver in overlapping chunks, out of order, like a flaky peer transfer.
    final OpStore incremental = OpStore()
      ..applyAll(log.sublist(20, 60))
      ..applyAll(log.sublist(0, 40))
      ..applyAll(log.sublist(40))
      ..applyAll(log); // and one duplicate delivery for good measure

    expect(incremental.fingerprint(), full.fingerprint());
  });

  test('two devices editing the same tile agree on the winner', () {
    final Hlc early = const Hlc.zero('phone').tick(1000);
    final Hlc later = const Hlc.zero('tablet').tick(2000);

    final OpStore a = OpStore()
      ..apply(Op(entityId: 't1', field: 'label', value: 'mum', stamp: early))
      ..apply(Op(entityId: 't1', field: 'label', value: 'amma', stamp: later));

    final OpStore b = OpStore()
      ..apply(Op(entityId: 't1', field: 'label', value: 'amma', stamp: later))
      ..apply(Op(entityId: 't1', field: 'label', value: 'mum', stamp: early));

    expect(a.read('t1', 'label'), 'amma');
    expect(b.read('t1', 'label'), 'amma');
    expect(a.fingerprint(), b.fingerprint());
  });

  test('different fields on the same tile do not clobber each other', () {
    final Hlc stamp = const Hlc.zero('phone').tick(1000);
    final OpStore store = OpStore()
      ..apply(Op(entityId: 't1', field: 'label', value: 'water', stamp: stamp))
      ..apply(Op(entityId: 't1', field: 'glyph', value: 'drop', stamp: stamp));

    expect(store.slotCount, 2);
    expect(store.read('t1', 'label'), 'water');
    expect(store.read('t1', 'glyph'), 'drop');
  });

  test('Lww.merge is commutative and idempotent', () {
    final Lww<String> older = Lww<String>(
      'mum',
      const Hlc.zero('a').tick(1000),
    );
    final Lww<String> newer = Lww<String>(
      'amma',
      const Hlc.zero('b').tick(2000),
    );

    expect(older.merge(newer).value, 'amma');
    expect(newer.merge(older).value, 'amma');
    expect(newer.merge(newer).value, 'amma');
  });

  test('ops survive a JSON round trip, so export and import agree', () {
    final List<Op> log = _sampleLog();
    final List<Op> reloaded = log
        .map((Op op) => Op.fromJson(op.toJson()))
        .toList(growable: false);

    expect(
      (OpStore()..applyAll(reloaded)).fingerprint(),
      (OpStore()..applyAll(log)).fingerprint(),
    );
  });

  test('reading an unwritten slot is null, not an exception', () {
    expect(OpStore().read('nope', 'label'), isNull);
  });
}

/// Two devices with drifting clocks, repeatedly writing the same few slots.
List<Op> _sampleLog() {
  Hlc phone = const Hlc.zero('phone');
  Hlc tablet = const Hlc.zero('tablet');
  final List<Op> ops = <Op>[];

  for (int i = 0; i < 40; i++) {
    // The tablet's clock runs slow, so the two devices interleave.
    phone = phone.tick(1000000 + i * 7);
    tablet = tablet.tick(1000000 + i * 5);

    final String entity = 'tile-${i % 6}';
    final String field = i.isEven ? 'label' : 'glyph';
    ops.add(
      Op(entityId: entity, field: field, value: 'phone-$i', stamp: phone),
    );
    ops.add(
      Op(entityId: entity, field: field, value: 'tablet-$i', stamp: tablet),
    );
  }
  return ops;
}
