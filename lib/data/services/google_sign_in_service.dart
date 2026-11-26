import 'package:google_sign_in/google_sign_in.dart';

import '../config/api_config.dart';

class GoogleSignInService {
  GoogleSignInService()
    : _googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        clientId: RidonsEnv.googleIosClientId,
        serverClientId: RidonsEnv.googleWebClientId,
      );

  final GoogleSignIn _googleSignIn;

  Future<String?> signInForIdToken() async {
    final account = await _googleSignIn.signIn();
    if (account == null) return null;
    final authentication = await account.authentication;
    final idToken = authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Google did not return an ID token.');
    }
    return idToken;
  }

  Future<void> signOut() => _googleSignIn.signOut();
}
