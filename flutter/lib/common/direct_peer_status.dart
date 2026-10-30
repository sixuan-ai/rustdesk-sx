// UI classification only; the native connector validates and probes endpoints.
bool isDirectPeerAddress(String id) {
  if (id.contains('@') || id.contains('/') || id.contains('?')) return false;
  return id.contains(':') || RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(id);
}

String peerAvailabilityLabel(String id, bool online) {
  if (isDirectPeerAddress(id)) {
    return online ? 'Direct port reachable' : 'Direct availability unconfirmed';
  }
  return online ? 'Online' : 'Not confirmed online';
}
