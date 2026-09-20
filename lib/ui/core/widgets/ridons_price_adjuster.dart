import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/ridons_colors.dart';

/// Negotiated fare ± control (RWF) from Price estimation PDF.
class RidonsPriceAdjuster extends StatelessWidget {
  const RidonsPriceAdjuster({
    super.key,
    required this.amountRwf,
    required this.onDecrement,
    required this.onIncrement,
    this.step = 100,
    this.enabled = true,
  });

  final int amountRwf;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final int step;
  final bool enabled;

  static final _fmt = NumberFormat('#,###');

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: context.ridonsSheet,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: RidonsColors.primary, width: 1.4),
        ),
        child: Row(
          children: [
            _CircleBtn(
              icon: Icons.remove,
              onPressed: enabled ? onDecrement : null,
            ),
            Expanded(
              child: Text(
                '${_fmt.format(amountRwf)} RWF',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.ridonsInk,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _CircleBtn(
              icon: Icons.add,
              onPressed: enabled ? onIncrement : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.ridonsSoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: RidonsColors.primary),
        ),
      ),
    );
  }
}
