import 'package:flutter/material.dart';

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
      items: [
        for (final tab in visible) _item(tab),
      ],
    );
  }

  BottomNavigationBarItem _item(RidonsNavTab tab) {
    return switch (tab) {
      RidonsNavTab.home => const BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home_rounded),
          label: 'Home',
        ),
      RidonsNavTab.earnings => const BottomNavigationBarItem(
          icon: Icon(Icons.bar_chart_outlined),
          activeIcon: Icon(Icons.bar_chart_rounded),
          label: 'Earnings',
        ),
      RidonsNavTab.activities => const BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today_outlined),
          activeIcon: Icon(Icons.calendar_today_rounded),
          label: 'Activities',
        ),
      RidonsNavTab.account => const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline_rounded),
          activeIcon: Icon(Icons.person_rounded),
          label: 'Account',
        ),
    };
  }
}
