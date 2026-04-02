import 'package:flutter/material.dart';

enum StreakBadgeState { validated, waiting, grace, broken }

class StreakBadge extends StatefulWidget {
  final int streak;
  final StreakBadgeState state;
  final VoidCallback? onTapBroken;

  const StreakBadge({
    super.key,
    required this.streak,
    required this.state,
    this.onTapBroken,
  });

  @override
  State<StreakBadge> createState() => _StreakBadgeState();
}

class _StreakBadgeState extends State<StreakBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  bool get _shouldPulse => widget.state == StreakBadgeState.validated;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    _scale = Tween<double>(begin: 1.0, end: 1.07).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (_shouldPulse) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldPulse) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isBroken = widget.state == StreakBadgeState.broken;
    final isValidated = widget.state == StreakBadgeState.validated;
    final isGrace = widget.state == StreakBadgeState.grace;

    final bg = isBroken
        ? Colors.grey.shade900
        : isValidated
            ? const Color(0xFF22150B)
            : isGrace
                ? const Color(0xFF111B22)
            : const Color(0xFF1C1212);

    final border = isBroken
        ? Colors.white10
        : isValidated
            ? const Color(0x66FFC107)
            : isGrace
                ? const Color(0x6638BDF8)
            : const Color(0x33FF6A00);

    final glow = isBroken
        ? Colors.transparent
        : isValidated
            ? const Color(0x66FFC107)
            : isGrace
                ? const Color(0x6638BDF8)
            : Colors.transparent;

    final iconColor = isBroken
        ? Colors.white38
        : isValidated
            ? const Color(0xFFFFD54F)
            : isGrace
                ? const Color(0xFF7DD3FC)
            : const Color(0xFFFF6A00);

    final textColor = isBroken ? Colors.white38 : Colors.white;

    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
        boxShadow: [
          if (!isBroken && (isValidated || glow != Colors.transparent))
            BoxShadow(
              color: glow,
              blurRadius: 10,
              spreadRadius: 0.5,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isBroken ? Icons.heart_broken : (isGrace ? Icons.timer : Icons.local_fire_department),
            size: 16,
            color: iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.streak}',
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );

    if (isBroken) {
      badge = InkWell(
        onTap: widget.onTapBroken,
        borderRadius: BorderRadius.circular(14),
        child: badge,
      );
    } else if (_shouldPulse) {
      badge = ScaleTransition(scale: _scale, child: badge);
    }

    return badge;
  }
}

