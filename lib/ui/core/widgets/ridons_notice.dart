import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../theme/ridons_colors.dart';

enum RidonsNoticeTone { info, success, warning, error }

/// Consistent transient feedback shown at the TOP of the screen.
///
/// Uses an Overlay so it appears above everything — maps, sheets, bottom nav.
class RidonsNotice {
  const RidonsNotice._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    RidonsNoticeTone tone = RidonsNoticeTone.info,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null || message.trim().isEmpty) return;

    final colors = _colors(tone);
    final localizedMessage = message.tr();
    final topPadding = MediaQuery.paddingOf(context).top + 8;

    // Dismiss any existing notice first.
    _dismiss();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NoticeWidget(
        message: localizedMessage,
        colors: colors,
        topPadding: topPadding,
        onDismiss: _dismiss,
      ),
    );

    _current = entry;
    overlay.insert(entry);

    _timer = Timer(const Duration(seconds: 4), _dismiss);
  }

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }

  static void success(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.success);

  static void info(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.info);

  static void warning(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.warning);

  static void error(BuildContext context, String message) =>
      show(context, message, tone: RidonsNoticeTone.error);

  static _NoticeColors _colors(RidonsNoticeTone tone) {
    return switch (tone) {
      RidonsNoticeTone.success => _NoticeColors(
        background: const Color(0xFF166534),
        foreground: Colors.white,
        icon: Icons.check_circle_outline_rounded,
      ),
      RidonsNoticeTone.warning => _NoticeColors(
        background: const Color(0xFFB45309),
        foreground: Colors.white,
        icon: Icons.warning_amber_rounded,
      ),
      RidonsNoticeTone.error => _NoticeColors(
        background: RidonsColors.primaryDark,
        foreground: Colors.white,
        icon: Icons.error_outline_rounded,
      ),
      RidonsNoticeTone.info => _NoticeColors(
        background: RidonsColors.primary,
        foreground: Colors.white,
        icon: Icons.info_outline_rounded,
      ),
    };
  }
}

class _NoticeColors {
  const _NoticeColors({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;
}

class _NoticeWidget extends StatefulWidget {
  const _NoticeWidget({
    required this.message,
    required this.colors,
    required this.topPadding,
    required this.onDismiss,
  });

  final String message;
  final _NoticeColors colors;
  final double topPadding;
  final VoidCallback onDismiss;

  @override
  State<_NoticeWidget> createState() => _NoticeWidgetState();
}

class _NoticeWidgetState extends State<_NoticeWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onVerticalDragEnd: (details) {
                if (details.primaryVelocity != null &&
                    details.primaryVelocity! < 0) {
                  widget.onDismiss();
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: widget.colors.background,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.colors.icon,
                      color: widget.colors.foreground,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.colors.foreground,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
