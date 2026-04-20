import 'package:flutter/material.dart';
import 'dart:math' as math;

enum StreakBadgeState { active, safe, broken }

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
  late final Animation<double> _activeScale;
  late final Animation<double> _pendingGlow;

  bool get _isActive => widget.state == StreakBadgeState.active;
  bool get _isBroken => widget.state == StreakBadgeState.broken;
  bool get _isPending => widget.state == StreakBadgeState.safe;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));
    _activeScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _pendingGlow = Tween<double>(begin: 0.20, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    if (_isActive || _isBroken || _isPending) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant StreakBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isActive || _isBroken || _isPending) {
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
    final isActive = _isActive;
    final isBroken = _isBroken;
    final isPending = _isPending;
    final bg = isActive
        ? const Color(0xFF2A1D0B)
        : (isBroken ? const Color(0xFF10212C) : const Color(0xFF1D1A12));
    final border = isActive
        ? const Color(0xFFFFA000)
        : (isBroken ? const Color(0xFF66D9FF) : const Color(0xFFB0853B));
    final iconColor = isActive
        ? const Color(0xFFFFB300)
        : (isBroken ? const Color(0xFFB8ECFF) : const Color(0xFFFFC86D));
    final labelColor = isBroken ? const Color(0xFFC7F1FF) : Colors.white70;

    Widget badge = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final frostPulse = isBroken ? (0.25 + 0.35 * (0.5 + 0.5 * math.sin(t * math.pi * 2))) : 0.0;
            final glare = isBroken ? (0.15 + 0.3 * (0.5 + 0.5 * math.sin(t * math.pi * 2.2))) : 0.0;

            Widget content = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border, width: isBroken ? 1.5 : 1),
                boxShadow: [
                  if (isActive)
                    const BoxShadow(
                      color: Color(0x66FF9800),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                      offset: Offset(0, 2),
                    ),
                  if (isBroken)
                    BoxShadow(
                      color: const Color(0x9944D7FF).withOpacity(0.35 + frostPulse * 0.45),
                      blurRadius: 10 + frostPulse * 8,
                      spreadRadius: 0.6 + frostPulse,
                    ),
                  if (isPending)
                    BoxShadow(
                      color: const Color(0x66FFB74D).withOpacity(_pendingGlow.value),
                      blurRadius: 8,
                      spreadRadius: 0.2,
                    ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isBroken ? Icons.favorite : Icons.local_fire_department,
                        size: 16,
                        color: iconColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.streak}',
                        style: TextStyle(
                          color: isBroken ? const Color(0xCCECF9FF) : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  if (isBroken)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Align(
                          alignment: Alignment(-1.0 + t * 2.0, 0),
                          child: Container(
                            width: 20,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withOpacity(0.0),
                                  Colors.white.withOpacity(0.35 + glare * 0.25),
                                  Colors.white.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );

            if (isActive) {
              content = ScaleTransition(scale: _activeScale, child: content);
            }

            return content;
          },
        ),
        if (isBroken)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              'TAP TO RESCUE',
              style: TextStyle(
                color: labelColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
          ),
      ],
    );

    if (isBroken) {
      badge = Tooltip(
        message: 'TAP TO RESCUE',
        child: InkWell(
          onTap: widget.onTapBroken,
          borderRadius: BorderRadius.circular(14),
          child: badge,
        ),
      );
    }

    return badge;
  }
}

