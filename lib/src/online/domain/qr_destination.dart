class QrDestination {
  const QrDestination(this.kind, this.id);
  final String kind;
  final String id;
  String get value => 'trimmatrix://$kind/$id';
  static QrDestination? parse(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        uri.scheme != 'trimmatrix' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        uri.hasQuery ||
        uri.hasFragment ||
        !{'salon', 'barber', 'join'}.contains(uri.host) ||
        uri.pathSegments.length != 1) {
      return null;
    }
    final id = uri.pathSegments.single;
    if (!RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(id)) {
      return null;
    }
    return QrDestination(uri.host, id.toLowerCase());
  }
}
