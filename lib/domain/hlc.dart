import 'dart:math' as math;

/// A hybrid logical clock.
///
/// Tesservox syncs peer to peer -- a parent's phone and a child's tablet meeting
/// over QR or the local network, with no server and no accounts. Device clocks
/// on cheap tablets are routinely wrong by hours, and a school tablet that has
/// never seen the internet may think it is 1970.
///
/// An HLC gives us a *total order* that is monotonic per device and still
/// tracks wall time closely enough for a human to read. Ties are broken by
/// device id, so two devices can never disagree about which edit won.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.counter, this.deviceId);

  /// The zero value for a device that has never issued a stamp.
  const Hlc.zero(String deviceId) : this(0, 0, deviceId);

  factory Hlc.parse(String encoded) {
    final List<String> parts = encoded.split(':');
    if (parts.length < 3) {
      throw FormatException('Malformed HLC', encoded);
    }
    final int? millis = int.tryParse(parts[0]);
    final int? counter = int.tryParse(parts[1]);
    if (millis == null || counter == null) {
      throw FormatException('Malformed HLC', encoded);
    }
    // Device ids are opaque and may contain colons, so re-join the tail.
    return Hlc(millis, counter, parts.sublist(2).join(':'));
  }

  final int millis;
  final int counter;
  final String deviceId;

  /// Stamp a local event. Never goes backwards, even if the wall clock does.
  Hlc tick(int wallMillis) => wallMillis > millis
      ? Hlc(wallMillis, 0, deviceId)
      : Hlc(millis, counter + 1, deviceId);

  /// Stamp the receipt of a [remote] event, absorbing its knowledge of time.
  Hlc receive(Hlc remote, int wallMillis) {
    final int maxMillis =
        math.max(millis, math.max(remote.millis, wallMillis));

    if (maxMillis == millis && maxMillis == remote.millis) {
      return Hlc(maxMillis, math.max(counter, remote.counter) + 1, deviceId);
    }
    if (maxMillis == millis) {
      return Hlc(maxMillis, counter + 1, deviceId);
    }
    if (maxMillis == remote.millis) {
      return Hlc(maxMillis, remote.counter + 1, deviceId);
    }
    return Hlc(maxMillis, 0, deviceId);
  }

  @override
  int compareTo(Hlc other) {
    final int byMillis = millis.compareTo(other.millis);
    if (byMillis != 0) return byMillis;
    final int byCounter = counter.compareTo(other.counter);
    if (byCounter != 0) return byCounter;
    // Total order: without this, two devices could each think they won.
    return deviceId.compareTo(other.deviceId);
  }

  bool operator >(Hlc other) => compareTo(other) > 0;
  bool operator <(Hlc other) => compareTo(other) < 0;
  bool operator >=(Hlc other) => compareTo(other) >= 0;
  bool operator <=(Hlc other) => compareTo(other) <= 0;

  String encode() => '$millis:$counter:$deviceId';

  @override
  bool operator ==(Object other) => other is Hlc && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(millis, counter, deviceId);

  @override
  String toString() => encode();
}
