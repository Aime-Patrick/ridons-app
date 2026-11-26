import 'session_user.dart';

class GoogleAuthResult {
  const GoogleAuthResult({this.session, this.pendingToken});

  final AuthSession? session;
  final String? pendingToken;

  bool get requiresPhone => pendingToken != null && pendingToken!.isNotEmpty;
}
