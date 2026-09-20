import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/models/app_role.dart';

/// Active role for theme + navigation. Set after onboarding.
final appRoleProvider = StateProvider<AppRole?>((ref) => null);
