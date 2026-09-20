import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/routing/app_router.dart';
import '../../core/theme/ridons_colors.dart';
import '../../core/widgets/widgets.dart';

/// Gallery of shared widgets — build screens by composing these.
class WidgetsLabView extends StatefulWidget {
  const WidgetsLabView({super.key});

  @override
  State<WidgetsLabView> createState() => _WidgetsLabViewState();
}

class _WidgetsLabViewState extends State<WidgetsLabView> {
  final _phone = TextEditingController(text: '788888888');
  int _price = 1900;
  int _stars = 0;
  String _otp = '';

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shared widgets'),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Shell'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Buttons', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsButton(label: 'Continue', onPressed: () {}),
          const SizedBox(height: 8),
          RidonsButton(
            label: 'Continue with Google',
            variant: RidonsButtonVariant.outline,
            leading: const Icon(Icons.g_mobiledata, size: 28),
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          RidonsButton(
            label: 'Report a problem',
            variant: RidonsButtonVariant.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: 24),
          Text('Phone', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsPhoneField(controller: _phone),
          const SizedBox(height: 24),
          Text('OTP', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsOtpField(onChanged: (c) => setState(() => _otp = c)),
          Text('code: $_otp', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 24),
          Text('Price offer', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsPriceAdjuster(
            amountRwf: _price,
            onDecrement: () => setState(() => _price = (_price - 100).clamp(500, 50000)),
            onIncrement: () => setState(() => _price = (_price + 100).clamp(500, 50000)),
          ),
          const SizedBox(height: 24),
          Text('Driver', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const RidonsDriverCard(
            name: 'Jean Bosco Nsabimana',
            rating: 4.5,
            plate: 'RAD 123 A',
          ),
          const SizedBox(height: 24),
          Text('Rating', style: Theme.of(context).textTheme.titleMedium),
          RidonsStarRating(
            value: _stars,
            onChanged: (v) => setState(() => _stars = v),
          ),
          const SizedBox(height: 24),
          Text('Places', style: Theme.of(context).textTheme.titleMedium),
          RidonsLocationTile(
            title: 'Remera Bus Park',
            subtitle: 'KG 11 Ave, Kigali',
            onTap: () {},
          ),
          RidonsLocationTile(
            title: 'Kigali City Tower',
            subtitle: 'Nyarugenge',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Text('Sheet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsBottomSheet(
            title: 'Route',
            child: Column(
              children: [
                const RidonsTextField(hint: 'My current location'),
                const SizedBox(height: 8),
                const RidonsTextField(hint: 'Choose dropoff location'),
                const SizedBox(height: 12),
                RidonsButton(label: 'Continue', onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RidonsTextLink(
            prefix: 'Already have an account? ',
            text: 'Sign In',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Text(
            'Brand primary #C91D22 · driver navy #0F172A',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: RidonsColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}
