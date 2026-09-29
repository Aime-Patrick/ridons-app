import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';
import 'ridons_bottom_sheet.dart';

/// Shared active-trip sheet shell used by both passenger and driver flows.
///
/// The role-specific content is supplied by [body], while the surface,
/// header, and spacing stay consistent across the app. Scrolling is handled
/// by [RidonsTripSheetHost].
class RidonsTripSheet extends StatelessWidget {
  const RidonsTripSheet({
    super.key,
    required this.title,
    required this.body,
    this.trailing,
    this.decorate = true,
  });

  final String title;
  final Widget body;
  final Widget? trailing;
  final bool decorate;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title.tr(),
                style: TextStyle(
                  color: context.ridonsInk,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: 12),
        body,
      ],
    );

    return RidonsBottomSheet(
      showHandle: false,
      decorate: decorate,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: content,
    );
  }
}

/// Shared draggable host for active-trip sheets on the map.
///
/// Keeping the controller, snap points, scroll controller, and map surface in
/// one place prevents passenger and driver sheets from drifting apart in
/// height or drag behavior.
class RidonsTripSheetHost extends StatelessWidget {
  static const defaultSnapSizes = <double>[
    0.1,
    0.24,
    0.28,
    0.34,
    0.38,
    0.40,
    0.44,
    0.52,
    0.82,
  ];

  const RidonsTripSheetHost({
    super.key,
    required this.child,
    required this.initialChildSize,
    required this.minChildSize,
    required this.maxChildSize,
    required this.snapSizes,
    this.controller,
  });

  final Widget child;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final List<double> snapSizes;
  final DraggableScrollableController? controller;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: true,
      snapSizes: snapSizes,
      builder: (context, scrollController) {
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        return Material(
          color: context.ridonsSheet,
          elevation: 12,
          shadowColor: const Color(0x33000000),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            controller: scrollController,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(0, 4, 0, 4 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      color: context.ridonsLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        );
      },
    );
  }
}
