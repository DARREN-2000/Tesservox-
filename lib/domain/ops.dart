import 'hlc.dart';

/// Conflict-free replicated state, the small honest version.
///
/// Every change to a board is an [Op]: one field, one entity, one stamp. State
/// is a fold over the op log. That makes merging two devices a set union plus a
/// max, which is commutative, associative and **idempotent** -- so a re-scanned
/// QR bundle, a duplicated file or a replayed log can never fork a board.
///
/// A full CRDT (RGA, Yjs, Automerge) buys ordered-list convergence. Tesservox does
/// not need it: tiles live at fixed grid positions on purpose, because motor
/// planning depends on a word never moving. Last-writer-wins per field is the
/// correct amount of machinery here, and that trade-off is deliberate.
library;

/// A last-writer-wins register: one value, one stamp.
class Lww<T> {
  const Lww(this.value, this.stamp);

  final T value;
  final Hlc stamp;

  /// merge(a, b) == merge(b, a) and merge(a, a) == a.
  Lww<T> merge(Lww<T> other) => stamp >= other.stamp ? this : other;

  @override
  String toString() => 'Lww($value @ $stamp)';
}

/// A single field-level change. The only way state ever moves.
class Op {
  const Op({
    required this.entityId,
    required this.field,
    required this.value,
    required this.stamp,
  });

  factory Op.fromJson(Map<String, dynamic> json) => Op(
        entityId: json['entity'] as String,
        field: json['field'] as String,
        value: json['value'],
        stamp: Hlc.parse(json['stamp'] as String),
      );

  final String entityId;
  final String field;
  final Object? value;
  final Hlc stamp;

  /// Identity of the *slot* being written. Two ops with the same key compete.
  String get key => '$entityId/$field';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'entity': entityId,
        'field': field,
        'value': value,
        'stamp': stamp.encode(),
      };

  @override
  String toString() => 'Op($key = $value @ $stamp)';
}

/// Folds an op stream into the winning value per slot.
///
/// Order-independent by construction: [apply] only ever keeps the op with the
/// greater stamp, and stamps are totally ordered by [Hlc.compareTo].
class OpStore {
  final Map<String, Op> _winners = <String, Op>{};

  /// The current winner for every slot that has ever been written.
  Map<String, Op> get winners => Map<String, Op>.unmodifiable(_winners);

  int get slotCount => _winners.length;

  /// Returns true when this op changed the resolved state. Useful for deciding
  /// whether a sync actually needs to trigger a repaint or a save.
  bool apply(Op op) {
    final Op? current = _winners[op.key];
    if (current != null && current.stamp >= op.stamp) {
      return false;
    }
    _winners[op.key] = op;
    return true;
  }

  int applyAll(Iterable<Op> ops) {
    int changed = 0;
    for (final Op op in ops) {
      if (apply(op)) changed++;
    }
    return changed;
  }

  Object? read(String entityId, String field) =>
      _winners['$entityId/$field']?.value;

  /// Everything this device knows, for handing to a peer. In a real sync you
  /// would send only ops newer than the peer's last-seen stamp per device.
  List<Op> export() => _winners.values.toList(growable: false);

  /// A stable fingerprint of resolved state. Two converged devices must agree,
  /// which is exactly what the convergence tests assert.
  String fingerprint() {
    final List<String> keys = _winners.keys.toList()..sort();
    return keys.map((String k) => '$k=${_winners[k]!.value}').join('|');
  }
}
