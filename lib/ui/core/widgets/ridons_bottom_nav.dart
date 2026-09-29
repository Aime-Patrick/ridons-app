import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../domain/models/app_role.dart';

enum RidonsNavTab { home, earnings, activities, account }

/// Persistent bottom nav. Drivers also get Earnings.
class RidonsBottomNav extends StatelessWidget {
  const RidonsBottomNav({
    super.key,
    required this.current,
    required this.onChanged,
    this.role = AppRole.passenger,
  });

  final RidonsNavTab current;
  final ValueChanged<RidonsNavTab> onChanged;
  final AppRole role;

  List<RidonsNavTab> get tabs {
    if (role.isDriver) {
      return const [
        RidonsNavTab.home,
        RidonsNavTab.earnings,
        RidonsNavTab.activities,
        RidonsNavTab.account,
      ];
    }
    return const [
      RidonsNavTab.home,
      RidonsNavTab.activities,
      RidonsNavTab.account,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final visible = tabs;
    final index = visible.indexOf(current).clamp(0, visible.length - 1);
    return BottomNavigationBar(
      currentIndex: index,
      type: BottomNavigationBarType.fixed,
      onTap: (i) => onChanged(visible[i]),
      items: [for (final tab in visible) _item(tab)],
    );
  }

  BottomNavigationBarItem _item(RidonsNavTab tab) {
    return switch (tab) {
      RidonsNavTab.home => BottomNavigationBarItem(
        icon: const Icon(Icons.home_outlined),
        activeIcon: const Icon(Icons.home_rounded),
        label: 'home'.tr(),
      ),
      RidonsNavTab.earnings => BottomNavigationBarItem(
        icon: const Icon(Icons.bar_chart_outlined),
        activeIcon: const Icon(Icons.bar_chart_rounded),
        label: 'earnings'.tr(),
      ),
      RidonsNavTab.activities => BottomNavigationBarItem(
        icon: const Icon(Icons.calendar_today_outlined),
        activeIcon: const Icon(Icons.calendar_today_rounded),
        label: 'activities'.tr(),
      ),
      RidonsNavTab.account => BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline_rounded),
        activeIcon: const Icon(Icons.person_rounded),
        label: 'account'.tr(),
      ),
    };
  }
}
