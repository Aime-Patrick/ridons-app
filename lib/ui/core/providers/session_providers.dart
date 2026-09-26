import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/config/api_config.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/services/api_client.dart';
import '../../../data/services/geo_api.dart';
import '../../../data/services/driver_documents_service.dart';
import '../../../data/services/notification_api.dart';
import '../../../data/services/prefs_store.dart';
import '../../../data/services/realtime_client.dart';
import '../../../data/services/token_store.dart';
import '../../../data/services/trip_api.dart';
import '../../../data/services/support_api.dart';
import '../../../domain/models/app_role.dart';
import '../../../domain/models/session_user.dart';
import '../../features/auth/view_models/auth_view_model.dart';
import '../../features/account/view_models/driver_documents_view_model.dart';
import '../../features/notifications/view_models/notification_center_view_model.dart';
import '../../../data/repositories/driver_documents_repository.dart';
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

final supportApiProvider = Provider<SupportApi>((ref) {
  return SupportApi(ref.watch(apiClientProvider));
});

final notificationApiProvider = Provider<NotificationApi>((ref) {
  return NotificationApi(ref.watch(apiClientProvider));
});

final driverDocumentsRepositoryProvider = Provider<DriverDocumentsRepository>((
  ref,
) {
  return DriverDocumentsRepository(
    DriverDocumentsService(ref.watch(apiClientProvider)),
  );
});

final driverDocumentsViewModelProvider =
    ChangeNotifierProvider<DriverDocumentsViewModel>((ref) {
      return DriverDocumentsViewModel(
        ref.watch(driverDocumentsRepositoryProvider),
      );
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
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get<Map<String, dynamic>>('/me');
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

final notificationCenterProvider =
    ChangeNotifierProvider<NotificationCenterViewModel>((ref) {
      final session = ref.watch(authSessionProvider).asData?.value;
      final viewModel = NotificationCenterViewModel(
        api: ref.watch(notificationApiProvider),
        realtime: ref.watch(realtimeClientProvider),
        userId: session?.user.id ?? '',
      );
      return viewModel;
    });
