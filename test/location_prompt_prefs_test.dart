import 'package:flutter_test/flutter_test.dart';
import 'package:ridons/data/services/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('location prompt is shown until the user dismisses it', () async {
    final prefs = PrefsStore();

    expect(await prefs.locationPromptDismissed(), isFalse);
    await prefs.setLocationPromptDismissed(true);
    expect(await prefs.locationPromptDismissed(), isTrue);
  });
}
