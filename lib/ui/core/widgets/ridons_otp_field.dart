import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ridons_colors.dart';

/// Single-field OTP input: SMS autofill, paste, backspace, caret, error shake.
class RidonsOtpField extends StatefulWidget {
  const RidonsOtpField({
    super.key,
    this.length = 4,
    this.onCompleted,
    this.onChanged,
    this.autofocus = true,
    this.enabled = true,
    this.hasError = false,
  });

  final int length;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool enabled;
  final bool hasError;

  @override
  State<RidonsOtpField> createState() => _RidonsOtpFieldState();
}

class _RidonsOtpFieldState extends State<RidonsOtpField>
    with TickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _caret;
  late final AnimationController _shake;
  String _lastCompleted = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode()..addListener(_rebuild);
    _caret = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    );
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    if (widget.autofocus && widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.enabled) return;
        _focusNode.requestFocus();
        _syncCaret();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncCaret();
  }

  @override
  void didUpdateWidget(RidonsOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) {
      _focusNode.unfocus();
    }
    if (widget.enabled && !oldWidget.enabled && widget.autofocus) {
      _focusNode.requestFocus();
    }
    if (widget.hasError && !oldWidget.hasError) {
      _shake.forward(from: 0);
      HapticFeedback.mediumImpact();
    }
    _syncCaret();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode
      ..removeListener(_rebuild)
      ..dispose();
    _caret.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
    _syncCaret();
  }

  bool get _reduceMotion =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;

  void _syncCaret() {
    final show =
        widget.enabled &&
        _focusNode.hasFocus &&
        _controller.text.length < widget.length &&
        !_reduceMotion;
    if (show) {
      if (!_caret.isAnimating) _caret.repeat(reverse: true);
    } else {
      _caret
        ..stop()
        ..value = 1;
    }
  }

  String get _code => _controller.text;

  void _apply(String raw, {bool fromUser = true}) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final next = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
    widget.onChanged?.call(next);
    if (fromUser && next.isNotEmpty) {
      HapticFeedback.selectionClick();
    }
    if (next.length == widget.length && next != _lastCompleted) {
      _lastCompleted = next;
      HapticFeedback.lightImpact();
      widget.onCompleted?.call(next);
    } else if (next.length < widget.length) {
      _lastCompleted = '';
    }
    setState(() {});
    _syncCaret();
  }

  Future<void> _paste() async {
    if (!widget.enabled) return;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _apply(text);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion;
    final code = _code;
    final focused = _focusNode.hasFocus;

    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) {
        final t = _shake.value;
        final dx = reduce ? 0.0 : math.sin(t * math.pi * 8) * 7 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          const gap = 10.0;
          final maxW = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : 280.0;
          final cell = ((maxW - gap * (widget.length - 1)) / widget.length)
              .clamp(48.0, 64.0);
          final rowWidth = cell * widget.length + gap * (widget.length - 1);

          return Align(
            alignment: Alignment.center,
            child: SizedBox(
              width: rowWidth,
              height: cell,
              child: Stack(
                children: [
                  Row(
                    children: List.generate(widget.length, (index) {
                      final filled = index < code.length;
                      final active =
                          focused &&
                          widget.enabled &&
                          index == code.length &&
                          index < widget.length;
                      return Padding(
                        padding: EdgeInsets.only(
                          right: index == widget.length - 1 ? 0 : gap,
                        ),
                        child: _OtpCell(
                          size: cell,
                          digit: filled ? code[index] : '',
                          active: active,
                          filled: filled,
                          hasError: widget.hasError,
                          caret: _caret,
                          reduceMotion: reduce,
                        ),
                      );
                    }),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      ignoring: !widget.enabled,
                      child: AutofillGroup(
                        child: TextSelectionTheme(
                          data: TextSelectionTheme.of(context).copyWith(
                            selectionColor: Colors.transparent,
                            selectionHandleColor: Colors.transparent,
                          ),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            enabled: widget.enabled,
                            autofocus: widget.autofocus && widget.enabled,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.oneTimeCode],
                            enableSuggestions: false,
                            autocorrect: false,
                            obscureText: false,
                            showCursor: false,
                            enableInteractiveSelection: true,
                            enableIMEPersonalizedLearning: false,
                            smartDashesType: SmartDashesType.disabled,
                            smartQuotesType: SmartQuotesType.disabled,
                            keyboardAppearance: Theme.of(context).brightness,
                            cursorColor: Colors.transparent,
                            style: const TextStyle(
                              color: Colors.transparent,
                              fontSize: 2,
                              height: 1,
                            ),
                            inputFormatters: [
                              _OtpDigitsFormatter(widget.length),
                            ],
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              filled: true,
                              fillColor: Colors.transparent,
                              isCollapsed: true,
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: _apply,
                            onTap: widget.enabled
                                ? () => _focusNode.requestFocus()
                                : null,
                            onSubmitted: (_) {
                              if (_code.length == widget.length) {
                                widget.onCompleted?.call(_code);
                              }
                            },
                            contextMenuBuilder: (context, state) {
                              return AdaptiveTextSelectionToolbar.buttonItems(
                                anchors: state.contextMenuAnchors,
                                buttonItems: [
                                  ContextMenuButtonItem(
                                    onPressed: () {
                                      ContextMenuController.removeAny();
                                      _paste();
                                    },
                                    label: 'paste',
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _OtpCell extends StatelessWidget {
  const _OtpCell({
    required this.size,
    required this.digit,
    required this.active,
    required this.filled,
    required this.hasError,
    required this.caret,
    required this.reduceMotion,
  });

  final double size;
  final String digit;
  final bool active;
  final bool filled;
  final bool hasError;
  final Animation<double> caret;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final borderColor = hasError
        ? RidonsColors.primary
        : active
        ? RidonsColors.primary
        : filled
        ? RidonsColors.primary.withValues(alpha: 0.55)
        : context.ridonsLine;
    final width = active || hasError ? 1.8 : 1.0;

    return AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.ridonsFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: width),
      ),
      child: filled
          ? Text(
              digit,
              style: GoogleFonts.inter(
                color: context.ridonsInk,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0.2,
              ),
            )
          : FadeTransition(
              opacity: reduceMotion ? const AlwaysStoppedAnimation(1) : caret,
              child: active
                  ? Container(
                      width: 2,
                      height: size * 0.38,
                      decoration: BoxDecoration(
                        color: RidonsColors.primary,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
    );
  }
}

class _OtpDigitsFormatter extends TextInputFormatter {
  const _OtpDigitsFormatter(this.maxLength);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final clipped = digits.length > maxLength
        ? digits.substring(0, maxLength)
        : digits;
    return TextEditingValue(
      text: clipped,
      selection: TextSelection.collapsed(offset: clipped.length),
    );
  }
}
