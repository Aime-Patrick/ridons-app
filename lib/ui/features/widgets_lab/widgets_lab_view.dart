import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
        title: Text('shared_widgets'.tr()),
        actions: [
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: Text('shell'.tr()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('buttons'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsButton(label: 'continue', onPressed: () {}),
          const SizedBox(height: 8),
          RidonsButton(
            label: 'continue_with_google',
            variant: RidonsButtonVariant.outline,
            leading: const Icon(Icons.g_mobiledata, size: 28),
            onPressed: () {},
          ),
          const SizedBox(height: 8),
          RidonsButton(
            label: 'report_a_problem',
            variant: RidonsButtonVariant.secondary,
            onPressed: () {},
          ),
          const SizedBox(height: 24),
          Text('phone'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsPhoneField(controller: _phone),
          const SizedBox(height: 24),
          Text('otp'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsOtpField(onChanged: (c) => setState(() => _otp = c)),
          Text(
            'code_value'.tr(namedArgs: {'code': _otp}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text(
            'price_offer'.tr(),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          RidonsPriceAdjuster(
            amountRwf: _price,
            onDecrement: () =>
                setState(() => _price = (_price - 100).clamp(500, 50000)),
            onIncrement: () =>
                setState(() => _price = (_price + 100).clamp(500, 50000)),
          ),
          const SizedBox(height: 24),
          Text('driver'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const RidonsDriverCard(
            name: 'Jean Bosco Nsabimana',
            rating: 4.5,
            plate: 'RAD 123 A',
          ),
          const SizedBox(height: 24),
          Text('rating'.tr(), style: Theme.of(context).textTheme.titleMedium),
          RidonsStarRating(
            value: _stars,
            onChanged: (v) => setState(() => _stars = v),
          ),
          const SizedBox(height: 24),
          Text('places'.tr(), style: Theme.of(context).textTheme.titleMedium),
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
          Text('sheet'.tr(), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          RidonsBottomSheet(
            title: 'route',
            child: Column(
              children: [
                const RidonsTextField(hint: 'my_location'),
                const SizedBox(height: 8),
                const RidonsTextField(hint: 'choose_dropoff_location'),
                const SizedBox(height: 12),
                RidonsButton(label: 'continue', onPressed: () {}),
              ],
            ),
          ),
          const SizedBox(height: 16),
          RidonsTextLink(
            prefix: 'already_have_account',
            text: 'sign_in',
            onTap: () {},
          ),
          const SizedBox(height: 24),
          Text(
            'brand_colors'.tr(),
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: RidonsColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
