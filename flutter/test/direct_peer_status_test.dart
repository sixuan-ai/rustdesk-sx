import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/common/direct_peer_status.dart';

void main() {
  test(
      'direct availability describes reachability without claiming an ID login',
      () {
    for (final address in [
      '100.89.0.1',
      '100.89.0.1:22000',
      '[2001:db8::1]:22000',
      'omen.example.com:22000'
    ]) {
      expect(peerAvailabilityLabel(address, true), 'Direct port reachable');
      expect(peerAvailabilityLabel(address, false),
          'Direct availability unconfirmed');
    }
    for (final id in ['123456789', '123456789@id.example.com:21116']) {
      expect(peerAvailabilityLabel(id, true), 'Online');
      expect(peerAvailabilityLabel(id, false), 'Not confirmed online');
    }
  });
}
