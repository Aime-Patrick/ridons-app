import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/widgets.dart';
import '../../core/providers/app_role_provider.dart';
import '../../core/providers/session_providers.dart';
import '../../../domain/models/app_role.dart';
import '../../../domain/models/geo_place.dart';
import '../account/account_view.dart';
import '../activities/activities_view.dart';
import '../driver/driver_earnings_view.dart';
import '../driver/driver_home_view.dart';
import '../home/home_map_view.dart';

/// Home, Activities, and Account — driver also gets Earnings.
class MainShellView extends ConsumerStatefulWidget {
  const MainShellView({super.key});

  @override
  ConsumerState<MainShellView> createState() => _MainShellViewState();
}

class _MainShellViewState extends ConsumerState<MainShellView> {
  RidonsNavTab _tab = RidonsNavTab.home;
  final _homeKey = GlobalKey<HomeMapViewState>();

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(appRoleProvider) ??
        ref.watch(authSessionProvider).asData?.value?.user.role ??
        AppRole.passenger;
    final isDriver = role.isDriver;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: IndexedStack(
        index: _stackIndex(isDriver),
        children: [
          if (isDriver)
            const DriverHomeView()
          else
            HomeMapView(key: _homeKey),
          if (isDriver) const DriverEarningsView(),
          ActivitiesView(
            isDriver: isDriver,
            onRebook: isDriver
                ? null
                : (trip) {
                    setState(() => _tab = RidonsNavTab.home);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _homeKey.currentState?.rebookReverse(
                        pickup: GeoPlace(
                          name: trip.dropoff,
                          latitude: trip.dropoffPoint.latitude,
                          longitude: trip.dropoffPoint.longitude,
                        ),
                        dropoff: GeoPlace(
                          name: trip.pickup,
                          latitude: trip.pickupPoint.latitude,
                          longitude: trip.pickupPoint.longitude,
                        ),
                      );
                    });
                  },
          ),
          const AccountView(),
        ],
      ),
      // Keep navigation available during an active trip. The trip state is
      // owned by DriverHomeViewModel, so changing tabs does not cancel or
      // lose the active ride.
      bottomNavigationBar: RidonsBottomNav(
        current: _tab,
        role: role,
        onChanged: (t) => setState(() => _tab = t),
      ),
    );
  }

  int _stackIndex(bool isDriver) {
    if (isDriver) {
      return switch (_tab) {
        RidonsNavTab.home => 0,
        RidonsNavTab.earnings => 1,
        RidonsNavTab.activities => 2,
        RidonsNavTab.account => 3,
      };
    }
    return switch (_tab) {
      RidonsNavTab.home => 0,
      RidonsNavTab.earnings => 0,
      RidonsNavTab.activities => 1,
      RidonsNavTab.account => 2,
    };
  }
}
