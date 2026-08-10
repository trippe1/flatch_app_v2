import 'package:flutter/material.dart';

/// Three render sizes of the scoreboard.
enum AccidentCounterSize { full, badge, mini }

/// Fenway-Park-style "Days Since Last Accident" scoreboard, themed to the app
/// (dark bezel + lime glow, deep-green plate, black reels). Renders a 3-digit
/// day count with a slot-machine roll-up; a null [value] shows dashes.
///
/// Streaks of a year or more grow a fourth **YR** reel on the left (lime year
/// digit, "YR" label on full/badge). The overall footprint is identical in
/// both modes — reels narrow and a label row trades against reel height.
///
/// The roll runs on first appearance and whenever [value] (or [rollToken])
/// changes. Reduced-motion snaps straight to the final number.
class AccidentCounter extends StatelessWidget {
  final int? value; // null → dashes
  final AccidentCounterSize size;
  final VoidCallback? onTap;

  /// Bump to force a re-roll even if [value] is unchanged (e.g. app-open roll).
  final int rollToken;

  const AccidentCounter({
    super.key,
    required this.value,
    this.size = AccidentCounterSize.full,
    this.onTap,
    this.rollToken = 0,
  });

  // ---- app-themed tokens (from the feature spec) ----
  static const _bezel = Color(0xFF242A24);
  static const _plate = Color(0xFF12351F);
  static const _reelBg = Color(0xFF0A0C0A);
  static const _numeral = Color(0xFFF4F6F2);
  static const _lime = Color(0xFF7ED957);

  /// Whole-year cap: at ≥10 years we freeze the display at 9 YR / 364 days.
  static const int _maxYears = 9;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isMini = size == AccidentCounterSize.mini;

    // ---- resolve the digit layout (year mode vs day mode) ----
    // years = floor(days/365); day reels show days % 365. Cap at 9 YR / 364 d.
    List<int?> digits; // leftmost first; YR reel (if present) is index 0
    bool yearMode = false;

    if (value == null) {
      digits = [null, null, null];
    } else {
      final v = value!;
      if (v >= 365) {
        yearMode = true;
        var yrs = v ~/ 365;
        var rem = v % 365;
        if (yrs > _maxYears) {
          yrs = _maxYears;
          rem = 364;
        }
        digits = [yrs, rem ~/ 100, (rem ~/ 10) % 10, rem % 10];
      } else {
        // 0..364 → three reels.
        digits = [v ~/ 100, (v ~/ 10) % 10, v % 10];
      }
    }

    final d = _dimsFor(size, yearMode);

    // Duration scales with the count (days): 1s..5s.
    final base = value == null
        ? 1.0
        : 1.0 + 4.0 * (value! > 500 ? 500 : value!) / 500.0;

    final board = Semantics(
      label: value == null
          ? 'Days since last accident: not set'
          : '$value days since last accident',
      button: onTap != null,
      child: Container(
        decoration: BoxDecoration(
          color: _bezel,
          borderRadius: BorderRadius.circular(isMini ? 8 : 14),
          boxShadow: [
            BoxShadow(color: _lime.withValues(alpha: 0.22), blurRadius: d.glow),
          ],
          border: Border.all(color: _lime.withValues(alpha: 0.55), width: 1.5),
        ),
        padding: isMini
            ? const EdgeInsets.fromLTRB(5, 4, 5, 5)
            : const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: _plate,
            borderRadius: BorderRadius.circular(isMini ? 5 : 9),
            border: Border.all(color: _lime.withValues(alpha: 0.35), width: 1.5),
          ),
          padding: isMini
              ? const EdgeInsets.fromLTRB(5, 4, 5, 5)
              : const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (d.screws) ..._screws(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (d.title) ...[
                    Text(
                      'DAYS SINCE LAST ACCIDENT',
                      style: TextStyle(
                        color: _lime,
                        fontSize: d.titleSize,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(digits.length, (i) {
                      // In year mode the leftmost reel is the YR reel (lime).
                      final isYr = yearMode && i == 0;
                      final reel = _Reel(
                        digit: digits[i],
                        spins: 6 + i * 2,
                        durationMs: ((base + i * 0.18) * 1000).round(),
                        dims: d,
                        animate: !reduceMotion,
                        rollToken: rollToken,
                        numeralColor: isYr ? _lime : _numeral,
                      );

                      // A label row (only the YR label is visible) keeps the
                      // year-mode height equal to day-mode.
                      final child = d.label
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: d.labelH,
                                  child: isYr
                                      ? Text(
                                          'YR',
                                          style: TextStyle(
                                            color: _lime,
                                            fontSize: d.labelSize,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                            height: 1.0,
                                          ),
                                        )
                                      : null,
                                ),
                                reel,
                              ],
                            )
                          : reel;

                      return Padding(
                        padding: EdgeInsets.only(
                          right: i < digits.length - 1 ? d.gap : 0,
                        ),
                        child: child,
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return board;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: board,
    );
  }

  /// Per-size dimensions, with narrower reels + a label row in year mode so the
  /// counter's overall width and height are identical in both modes.
  static _Dims _dimsFor(AccidentCounterSize size, bool year) {
    switch (size) {
      case AccidentCounterSize.full:
        // 3×64 + 2×8 = 208 == 4×46 + 3×8; label 14 + reel 78 = 92.
        return year
            ? const _Dims(reelW: 46, reelH: 78, font: 44, gap: 8, title: true,
                screws: true, glow: 22, titleSize: 11, label: true,
                labelH: 14, labelSize: 9)
            : const _Dims(reelW: 64, reelH: 92, font: 60, gap: 8, title: true,
                screws: true, glow: 22, titleSize: 11);
      case AccidentCounterSize.badge:
        // 3×51 + 2×6 = 165 == 4×36.75 + 3×6; label 11.3 + reel 62.7 = 74.
        return year
            ? const _Dims(reelW: 36.75, reelH: 62.7, font: 35, gap: 6,
                title: true, screws: true, glow: 18, titleSize: 10,
                label: true, labelH: 11.3, labelSize: 8)
            : const _Dims(reelW: 51, reelH: 74, font: 48, gap: 6, title: true,
                screws: true, glow: 18, titleSize: 10);
      case AccidentCounterSize.mini:
        // 3×18 + 2×2.5 ≈ 4×13 + 3×2.5; no label — lime digit marks the year.
        return year
            ? const _Dims(reelW: 13, reelH: 26, font: 13, gap: 2.5,
                title: false, screws: false, glow: 10, titleSize: 0)
            : const _Dims(reelW: 18, reelH: 26, font: 17, gap: 2.5,
                title: false, screws: false, glow: 10, titleSize: 0);
    }
  }

  /// Four corner "screws" for the plate (full/badge sizes).
  List<Widget> _screws() {
    const g = RadialGradient(
      center: Alignment(-0.3, -0.3),
      colors: [Color(0xFFB9C4B4), Color(0xFF4A544A)],
    );
    Widget dot() => Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: g),
    );
    return [
      Positioned(top: -3, left: -3, child: dot()),
      Positioned(top: -3, right: -3, child: dot()),
      Positioned(bottom: -3, left: -3, child: dot()),
      Positioned(bottom: -3, right: -3, child: dot()),
    ];
  }
}

class _Dims {
  final double reelW, reelH, font, gap, titleSize;
  final double glow;
  final bool title, screws;

  /// Year-mode label row above each reel (only YR is visible).
  final bool label;
  final double labelH, labelSize;

  const _Dims({
    required this.reelW,
    required this.reelH,
    required this.font,
    required this.gap,
    required this.title,
    required this.screws,
    required this.glow,
    required this.titleSize,
    this.label = false,
    this.labelH = 0,
    this.labelSize = 0,
  });
}

/// One digit reel. A vertical strip of repeating 0–9 digits translated up to
/// the target after several full revolutions, with a decelerating ease.
class _Reel extends StatefulWidget {
  final int? digit; // null → dash
  final int spins;
  final int durationMs;
  final _Dims dims;
  final bool animate;
  final int rollToken;
  final Color numeralColor;

  const _Reel({
    required this.digit,
    required this.spins,
    required this.durationMs,
    required this.dims,
    required this.animate,
    required this.rollToken,
    required this.numeralColor,
  });

  @override
  State<_Reel> createState() => _ReelState();
}

class _ReelState extends State<_Reel> with SingleTickerProviderStateMixin {
  static const int _repeats = 14; // 0–9 × 14 = 140 digits (covers max spins)
  late final AnimationController _c;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this);
    _configure();
  }

  @override
  void didUpdateWidget(covariant _Reel old) {
    super.didUpdateWidget(old);
    // Reel height can change when switching in/out of year mode — reconfigure
    // so the strip lands on the correct pixel offset.
    if (old.digit != widget.digit ||
        old.rollToken != widget.rollToken ||
        old.dims.reelH != widget.dims.reelH) {
      _configure();
    }
  }

  void _configure() {
    final h = widget.dims.reelH;
    if (widget.digit == null) return; // dash — no animation
    final targetIndex = widget.spins * 10 + widget.digit!;
    final endPx = -targetIndex * h;

    if (!widget.animate) {
      // Reduced motion: land straight on the digit (no spin).
      _anim = AlwaysStoppedAnimation(-widget.digit! * h);
      _c.value = 1;
      setState(() {});
      return;
    }

    _c.duration = Duration(milliseconds: widget.durationMs);
    // Start each roll from the top (digit 0) and roll down — matches the
    // reference mockup's slot-machine behaviour.
    _anim = Tween<double>(begin: 0, end: endPx).animate(
      CurvedAnimation(parent: _c, curve: const Cubic(0.12, 0.8, 0.25, 1)),
    );
    _c
      ..reset()
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.dims;
    return Container(
      width: d.reelW,
      height: d.reelH,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AccidentCounter._reelBg,
        borderRadius: BorderRadius.circular(d.reelH < 40 ? 3 : 6),
        border: Border.all(
          color: AccidentCounter._lime.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          if (widget.digit == null)
            _dash(d)
          else
            AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                // The strip is far taller than the reel window; let it exceed
                // the clip bounds without tripping the overflow warning.
                return OverflowBox(
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: Offset(0, _anim.value),
                    child: Column(
                      children: [
                        for (int r = 0; r < _repeats; r++)
                          for (int n = 0; n < 10; n++)
                            _digitCell(n.toString(), d),
                      ],
                    ),
                  ),
                );
              },
            ),
          // Rolling-drum shading top/bottom.
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Color(0xA6000000),
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0xA6000000),
                    ],
                    stops: const [0.0, 0.22, 0.78, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _digitCell(String s, _Dims d) => SizedBox(
    height: d.reelH,
    child: Center(
      child: Text(
        s,
        style: TextStyle(
          color: widget.numeralColor,
          fontSize: d.font,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
          height: 1.0,
        ),
      ),
    ),
  );

  Widget _dash(_Dims d) => Center(
    child: Text(
      '–',
      style: TextStyle(
        color: widget.numeralColor,
        fontSize: d.font,
        fontWeight: FontWeight.w800,
        height: 1.0,
      ),
    ),
  );
}
