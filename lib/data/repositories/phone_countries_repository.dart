import '../../domain/models/phone_country.dart';
import '../services/api_client.dart';
import '../services/prefs_store.dart';

class PhoneCountriesRepository {
  PhoneCountriesRepository({
    required ApiClient apiClient,
    required PrefsStore prefs,
  }) : _api = apiClient,
       _prefs = prefs;

  final ApiClient _api;
  final PrefsStore _prefs;

  /// Loads cached countries first, then refreshes from `/auth/phone-countries`
  /// so the app always stays in sync with admin settings on startup.
  Future<PhoneCountriesConfig> loadCachedOrFallback() async {
    return await _prefs.readPhoneCountries() ?? PhoneCountriesConfig.fallback;
  }

  Future<PhoneCountriesConfig> refresh() async {
    try {
      final response = await _api.dio.get<Map<String, dynamic>>(
        '/auth/phone-countries',
      );
      final data = response.data;
      if (data == null) {
        return await loadCachedOrFallback();
      }
      final config = PhoneCountriesConfig.fromJson(data);
      await _prefs.savePhoneCountries(config);
      return config;
    } catch (_) {
      return await loadCachedOrFallback();
    }
  }
}
