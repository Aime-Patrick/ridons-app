import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ridons/app.dart';
import 'package:ridons/data/repositories/auth_repository.dart';
import 'package:ridons/domain/models/app_role.dart';
import 'package:ridons/domain/models/session_user.dart';
import 'package:ridons/ui/core/providers/session_providers.dart';
import 'package:ridons/ui/core/widgets/ridons_role_card.dart';
import 'package:ridons/ui/core/widgets/ridons_otp_field.dart';
import 'package:ridons/ui/core/widgets/ridons_phone_field.dart';
import 'package:ridons/ui/features/auth/sign_in_view.dart';
import 'package:ridons/ui/features/auth/sign_up_view.dart';
import 'package:ridons/ui/features/onboarding/onboarding_view.dart';

class _MockAssetLoader extends AssetLoader {
  const _MockAssetLoader();

  @override
  Future<Map<String, dynamic>> load(String path, Locale locale) async {
    return {
      'app_name': 'Ridons',
      'tagline': 'Ride-Hailing made simple',
      'continue': 'Continue',
      'sign_in': 'Sign In',
      'choose_language': 'Choose a language',
      'kinyarwanda': 'Kinyarwanda',
      'english': 'English',
      'skip_onboarding': 'Skip',
      'get_a_ride': 'Get a ride',
      'get_a_ride_description': 'Offer your price, pick from the drivers',
      'drive_and_earn': 'Drive & Earn',
      'drive_and_earn_description': 'Get offers, pick from the passengers',
      'enter_your_number': 'Enter your number',
      'verification_code_sent':
          'We\'ll send you a verification code on your phone number',
      'verification_code_sent_short': 'A code was sent to your number',
      'no_account': 'Don\'t have an account? ',
      'create_one': 'Create One',
      'or': 'Or',
      'continue_with_google': 'Continue with Google',
      'phone_hint': '788 888 888',
      'enter_the_code': 'Enter the code',
      'resend_in': 'Resend in ',
      'resend_code': 'Resend code',
      'try_different_method': 'Try a different method',
      'get_a_ride_literal': 'Get a ride',
      'offer_your_price_literal': 'Offer your price, pick from the drivers',
      'fair_deals_tagline': 'Your app for fair deals',
      'choose_ride_tagline':
          'Choose a ride, name your price and connect instantly with drivers',
      'already_have_account': 'Already have an account? ',
      'consent_prefix': 'I agree to the ',
      'terms_conditions': 'Terms & conditions',
      'consent_joiner': ' and ',
      'privacy_policy': 'Privacy Policy',
      'continue_with_phone': 'Continue with phone',
      'Continue': 'Continue',
      'Continue with Google': 'Continue with Google',
      'Sign In': 'Sign In',
      'Get a ride': 'Get a ride',
      'Offer your price, pick from the drivers':
          'Offer your price, pick from the drivers',
    };
  }
}

class FakeAuthRepository implements AuthRepository {
  String? lastPhone;
  String? lastCode;
  String? lastIntent;
  AuthException? verifyError;

  @override
  Future<void> sendOtp({
    required String phone,
    String? intent,
    AppRole? role,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    String? policyVersion,
    String consentSource = 'mobile',
  }) async {
    lastPhone = phone;
  }

  @override
  Future<AuthSession> verifyOtp({
    required String phone,
    required String code,
    required AppRole role,
    String? intent,
    bool termsAccepted = false,
    bool privacyAccepted = false,
    String? policyVersion,
    String consentSource = 'mobile',
  }) async {
    lastCode = code;
    lastIntent = intent;
    final error = verifyError;
    if (error != null) {
      throw error;
    }
    return AuthSession(
      token: 'test-token',
      user: SessionUser(id: 'pax_test', phone: phone, role: role),
    );
  }

  @override
  Future<AuthSession> updateProfile({
    String? firstName,
    String? lastName,
    String? locale,
    String? avatarKey,
  }) async {
    return AuthSession(
      token: 'test-token',
      user: SessionUser(
        id: 'pax_test',
        phone: lastPhone ?? '+250788888888',
        role: AppRole.passenger,
        firstName: firstName ?? '',
        lastName: lastName ?? '',
        locale: locale ?? 'en',
        avatarKey: avatarKey ?? 'passenger',
      ),
    );
  }

  @override
  Future<AuthSession> switchMode(AppRole mode) async {
    return AuthSession(
      token: 'test-token',
      user: SessionUser(
        id: 'pax_test',
        phone: lastPhone ?? '+250788888888',
        role: mode,
        availableRoles: const [AppRole.passenger, AppRole.driver],
      ),
    );
  }

  @override
  Future<AuthSession> uploadAvatar(String filePath) async {
    return AuthSession(
      token: 'test-token',
      user: SessionUser(
        id: 'pax_test',
        phone: lastPhone ?? '+250788888888',
        role: AppRole.passenger,
        avatarKey: 'upload',
        avatarUrl: '/me/avatar',
      ),
    );
  }

  @override
  Future<AuthSession?> refreshSession() async => null;

  @override
  Future<AuthSession?> restore() async => null;

  @override
  Future<void> logout() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('passenger ID shows a few characters from the database id', () {
    const user = SessionUser(
      id: 'pax_Ab12Cd34Ef56',
      phone: '+250788888888',
      role: AppRole.passenger,
    );
    expect(user.passengerIdLabel, 'PAX-34EF56');
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'getAll') {
            return <String, dynamic>{};
          }
          return true;
        },
      );

  testWidgets('Ridons app boots to splash and renders', (tester) async {
    await EasyLocalization.ensureInitialized();

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('rw')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: const _MockAssetLoader(),
        saveLocale: false,
        child: ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const RidonsApp(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(RidonsApp), findsOneWidget);
  });

  testWidgets('role selection renders the two roles and navigates', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const OnboardingView()),
        GoRoute(
          path: '/widgets',
          builder: (context, state) =>
              const Scaffold(body: Text('Widgets Lab')),
        ),
        GoRoute(
          path: '/sign-in/phone',
          builder: (context, state) => const SignInView(),
        ),
        GoRoute(
          path: '/sign-in/code',
          builder: (context, state) => const SignInView(showCode: true),
        ),
        GoRoute(
          path: '/sign-up',
          builder: (context, state) => const SignUpView(),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('rw')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: const _MockAssetLoader(),
        saveLocale: false,
        child: ProviderScope(child: MaterialApp.router(routerConfig: router)),
      ),
    );

    await tester.pump();
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    expect(find.byType(RidonsRoleCard), findsNWidgets(2));
    expect(find.text('Get a ride'), findsOneWidget);
    expect(find.text('Drive & Earn'), findsOneWidget);
    expect(
      find.text('Offer your price, pick from the drivers'),
      findsOneWidget,
    );
    expect(find.text('Get offers, pick from the passengers'), findsOneWidget);
    final roleTitle = tester.widget<Text>(find.text('Get a ride'));
    expect(roleTitle.style?.fontFamily, contains('Inter'));
    expect(roleTitle.style?.fontSize, 20);
    expect(roleTitle.style?.fontWeight, FontWeight.w600);
    expect(roleTitle.style?.height, 0.88);
    expect(roleTitle.maxLines, isNull);
    expect(roleTitle.overflow, isNull);

    final roleDescription = tester.widget<Text>(
      find.text('Offer your price, pick from the drivers'),
    );
    expect(roleDescription.style?.fontFamily, contains('Inter'));
    expect(roleDescription.style?.fontSize, 16);
    expect(roleDescription.style?.fontWeight, FontWeight.w400);
    expect(roleDescription.style?.height, 1);
    expect(roleDescription.maxLines, 2);
    expect(roleDescription.overflow, TextOverflow.clip);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    await tester.tap(find.byType(RidonsRoleCard).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(SignUpView), findsOneWidget);
    expect(find.text('Your app for fair deals'), findsOneWidget);
    expect(find.text('Continue with phone'), findsOneWidget);
  });

  testWidgets('phone sign-in sends OTP then shows the code step', (
    tester,
  ) async {
    await EasyLocalization.ensureInitialized();
    final fake = FakeAuthRepository();
    final router = GoRouter(
      initialLocation: '/sign-in/phone',
      routes: [
        GoRoute(
          path: '/sign-in/phone',
          builder: (context, state) => const SignInView(),
        ),
        GoRoute(
          path: '/sign-in/code',
          builder: (context, state) => const SignInView(showCode: true),
        ),
      ],
    );

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en'), Locale('rw')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        assetLoader: const _MockAssetLoader(),
        saveLocale: false,
        child: ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(fake)],
          child: MaterialApp.router(routerConfig: router),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Enter your number'), findsOneWidget);
    await tester.enterText(find.byType(RidonsPhoneField), '788888888');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    await tester.pump();
    expect(fake.lastPhone, '+250788888888');
    expect(find.text('Enter the code'), findsOneWidget);
    expect(find.byType(RidonsOtpField), findsOneWidget);
  });

  testWidgets('role card stays within a tight height constraint', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 180,
            height: 112,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RidonsRoleCard(
                  title: 'Get a ride',
                  description: 'Offer your price, pick from the drivers',
                  imageAsset: 'assets/image/passenger_avatar.png',
                  isSelected: false,
                  onTap: () {},
                  scale: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('otp field accepts a full code and completes', (tester) async {
    String? completed;
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RidonsOtpField(
              autofocus: false,
              onChanged: (code) => changed = code,
              onCompleted: (code) => completed = code,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    expect(changed, '1234');
    expect(completed, '1234');
    expect(find.text('1'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('otp field keeps digits from an sms paste', (tester) async {
    String? changed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: RidonsOtpField(
              autofocus: false,
              onChanged: (code) => changed = code,
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Your code is 1234');
    await tester.pump();
    expect(changed, '1234');
  });
}
