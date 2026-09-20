import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/config/api_config.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/geo_api.dart';
import '../../../data/services/prefs_store.dart';
import '../../../data/services/realtime_client.dart';
import '../../../data/services/token_store.dart';
import '../../../data/services/trip_api.dart';
import '../../../domain/models/app_role.dart';
import '../../../domain/models/session_user.dart';
import '../../features/auth/view_models/auth_view_model.dart';
import 'app_role_provider.dart';

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());
final prefsStoreProvider = Provider<PrefsStore>((ref) => PrefsStore());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: defaultGatewayUrl(),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final geoApiProvider = Provider<GeoApi>((ref) {
  return GeoApi(ref.watch(apiClientProvider));
});

final tripApiProvider = Provider<TripApi>((ref) {
  return TripApi(ref.watch(apiClientProvider));
});

final realtimeClientProvider = Provider<RealtimeClient>((ref) {
  final client = RealtimeClient(
    wsUrl: defaultGatewayUrl(),
    readToken: () => ref.read(tokenStoreProvider).readAccess(),
  );
  ref.onDispose(client.dispose);
  return client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return RemoteAuthRepository(
    apiClient: ref.watch(apiClientProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  );
});

final authSessionProvider =
    AsyncNotifierProvider<AuthSessionNotifier, AuthSession?>(
  AuthSessionNotifier.new,
);

class AuthSessionNotifier extends AsyncNotifier<AuthSession?> {
  @override
  Future<AuthSession?> build() async {
    final session = await ref.read(authRepositoryProvider).restore();
    if (session != null) {
      ref.read(appRoleProvider.notifier).state = session.user.role;
    } else {
      final stored = await ref.read(prefsStoreProvider).readRole();
      if (stored != null) {
        ref.read(appRoleProvider.notifier).state = stored;
      }
    }
    return session;
  }

  Future<void> setSession(AuthSession session) async {
    state = AsyncData(session);
  }

  /// Soft refresh of `/me` without clearing tokens on transient failures.
  Future<void> refreshProfile() async {
    final current = state.asData?.value;
    if (current == null) return;
    try {
      final response =
          await ref.read(apiClientProvider).dio.get<Map<String, dynamic>>('/me');
      final userMap =
          (response.data?['user'] as Map<String, dynamic>?) ?? const {};
      final session = AuthSession(
        token: current.token,
        user: SessionUser.fromJson(userMap),
      );
      state = AsyncData(session);
      ref.read(appRoleProvider.notifier).state = session.user.role;
    } catch (_) {
      // Keep current session if refresh fails (network / gateway).
    }
  }

  Future<void> clear() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(null);
  }
}

final onboardedProvider = FutureProvider<bool>((ref) {
  return ref.read(prefsStoreProvider).isOnboarded();
});

final restoredRoleProvider = FutureProvider<AppRole?>((ref) {
  return ref.read(prefsStoreProvider).readRole();
});

final authViewModelProvider = ChangeNotifierProvider<AuthViewModel>((ref) {
  return AuthViewModel(authRepository: ref.watch(authRepositoryProvider));
});

final notificationBadgeProvider = FutureProvider<int>((ref) {
  return ref.watch(prefsStoreProvider).notificationBadge();
});
