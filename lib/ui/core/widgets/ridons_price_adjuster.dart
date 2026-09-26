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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        final buttonSize = (width * 0.14).clamp(36.0, 48.0).toDouble();
        final amountFontSize = (width * 0.065).clamp(18.0, 24.0).toDouble();
        final horizontalPadding = width < 280 ? 4.0 : 8.0;

        return Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: context.ridonsSheet,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: RidonsColors.primary, width: 1.4),
            ),
            child: Row(
              children: [
                _CircleBtn(
                  size: buttonSize,
                  icon: Icons.remove,
                  onPressed: enabled ? onDecrement : null,
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_fmt.format(amountRwf)} RWF',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.ridonsInk,
                        fontSize: amountFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                _CircleBtn(
                  size: buttonSize,
                  icon: Icons.add,
                  onPressed: enabled ? onIncrement : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CircleBtn extends StatelessWidget {
  const _CircleBtn({
    required this.size,
    required this.icon,
    required this.onPressed,
  });

  final double size;
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
          width: size,
          height: size,
          child: Icon(icon, color: RidonsColors.primary, size: size * 0.45),
        ),
      ),
    );
  }
}
