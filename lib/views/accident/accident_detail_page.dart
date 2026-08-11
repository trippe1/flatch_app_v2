import 'dart:async';
import 'dart:math' as math;

import 'package:flatch/common/widgets/accident_counter.dart';
import 'package:flatch/cubits/accident_counter/accident_counter_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// "Days since last accident" detail page — the full scoreboard, a date field,
/// the >100-day record modal, and the red TODAY button with its celebration
/// sequence (wobble → geyser + launch → "ONE OF US" plane → settle to 0).
class AccidentDetailPage extends StatefulWidget {
  const AccidentDetailPage({super.key});

  @override
  State<AccidentDetailPage> createState() => _AccidentDetailPageState();
}

class _AccidentDetailPageState extends State<AccidentDetailPage>
    with TickerProviderStateMixin {
  final _dateCtrl = TextEditingController();
  final _dateFocus = FocusNode();
  String? _dateError;
  int _rollToken = 1; // roll on entry

  // ---- TODAY sequence ----
  late final AnimationController _wobble;
  late final AnimationController _launch;
  late final AnimationController _geyser;
  late final AnimationController _plane; // left→right traversal (3.0s)
  late final AnimationController _bob; // gentle vertical bob of the plane group
  late final AnimationController _prop; // spinning propeller
  bool _seqRunning = false;
  Timer? _hapticTimer;
  final _redButtonBottomGap = 0.0;

  // spec: red is the app's ONLY red — the emergency button.
  static const _red = Color(0xFFE5484D);
  static const _redShadow = Color(0xFF8F1F26);
  static const _lime = Color(0xFF7ED957);
  static const _bg = Color(0xFF0C0E0C);
  static const _card = Color(0xFF1A1F1A);

  /// Old single-prop plane (side view, nose/front on the right) — ported from
  /// the design mockup. The propeller itself is drawn/animated in Flutter, so
  /// it's omitted here.
  static const _planeSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" width="96" height="52" '
      'viewBox="0 0 96 52">'
      // tail fin + stabilizer (left = rear)
      '<path d="M14 27 L2 10 L12 10 L20 22 Z" fill="#5FB944"/>'
      '<rect x="2" y="24" width="16" height="5" rx="2.5" fill="#5FB944"/>'
      // fuselage
      '<rect x="12" y="21" width="58" height="13" rx="6.5" fill="#7ED957"/>'
      // cockpit windshield
      '<path d="M46 21 L52 13 L58 21 Z" fill="#0C0E0C"/>'
      // wings (side view, swept slightly)
      '<ellipse cx="42" cy="30" rx="16" ry="4.5" fill="#4FA53C" '
      'transform="rotate(-10 42 30)"/>'
      '<ellipse cx="40" cy="20" rx="12" ry="3.2" fill="#5FB944" '
      'transform="rotate(-6 40 20)"/>'
      // landing gear
      '<line x1="38" y1="34" x2="35" y2="43" stroke="#5E675E" stroke-width="2"/>'
      '<line x1="50" y1="34" x2="53" y2="43" stroke="#5E675E" stroke-width="2"/>'
      '<circle cx="34" cy="45" r="4" fill="#0A0C0A" stroke="#9AA39A" '
      'stroke-width="1.5"/>'
      '<circle cx="54" cy="45" r="4" fill="#0A0C0A" stroke="#9AA39A" '
      'stroke-width="1.5"/>'
      // nose cone (right = front) + spinner hub
      '<path d="M70 21 Q80 27.5 70 34 Z" fill="#4FA53C"/>'
      '<circle cx="79" cy="27.5" r="3.5" fill="#B9C4B4"/>'
      '</svg>';

  @override
  void initState() {
    super.initState();
    _wobble = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _launch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _geyser = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _plane = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // exactly 3s crossing
    );
    _bob = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _prop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    final iso = context.read<AccidentCounterCubit>().state.lastAccidentDate;
    if (iso != null) _dateCtrl.text = _isoToMdy(iso);
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _dateFocus.dispose();
    _wobble.dispose();
    _launch.dispose();
    _geyser.dispose();
    _plane.dispose();
    _bob.dispose();
    _prop.dispose();
    _hapticTimer?.cancel();
    super.dispose();
  }

  // ---- date parsing ----

  DateTime? _parseMdy(String s) {
    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
    if (m == null) return null;
    final mm = int.parse(m.group(1)!);
    final dd = int.parse(m.group(2)!);
    final yy = int.parse(m.group(3)!);
    if (mm < 1 || mm > 12 || dd < 1 || dd > 31) return null;
    final dt = DateTime(yy, mm, dd);
    // Reject rollovers like 02/31.
    if (dt.month != mm || dt.day != dd) return null;
    return dt;
  }

  String _isoToMdy(String iso) {
    final p = iso.split('-');
    if (p.length != 3) return '';
    return '${p[1]}/${p[2]}/${p[0]}';
  }

  bool _isFuture(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).isAfter(today);
  }

  Future<void> _submitDate() async {
    setState(() => _dateError = null);
    final raw = _dateCtrl.text.trim();
    final dt = _parseMdy(raw);
    if (dt == null) {
      setState(() => _dateError = "Enter a valid date as MM/DD/YYYY.");
      return;
    }
    if (_isFuture(dt)) {
      setState(() => _dateError = "Date can't be in the future");
      return;
    }
    final days = AccidentCounterCubit.daysSinceFor(
          '${dt.year.toString().padLeft(4, '0')}-'
          '${dt.month.toString().padLeft(2, '0')}-'
          '${dt.day.toString().padLeft(2, '0')}',
        ) ??
        0;

    // >100 days on MANUAL entry → confirm (never fires from day-by-day drift).
    if (days > 100) {
      final ok = await _showRecordModal();
      if (ok != true) return;
    }
    await _save(dt);
  }

  Future<void> _save(DateTime dt) async {
    await context.read<AccidentCounterCubit>().setDate(dt);
    if (!mounted) return;
    setState(() {
      _dateCtrl.text =
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.year}';
      _rollToken++; // roll to the new value
    });
  }

  Future<bool?> _showRecordModal() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E251E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Are you sure? That might be a record',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'You entered a date more than 100 days ago.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF9AA39A), fontSize: 13),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3FD158),
                    foregroundColor: const Color(0xFF06210F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Yes, I am impressive',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF242B24),
                    foregroundColor: const Color(0xFFF2F4F2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    "No, I'll go back and tell the truth",
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- TODAY celebration ----

  Future<void> _todaySequence() async {
    if (_seqRunning) return;
    setState(() => _seqRunning = true);

    // Stage 1 — wobble + continuous-ish haptics for 3s. Flutter has no native
    // continuous vibration, so pulse heavy haptics on a tight loop.
    _wobble.repeat(reverse: true);
    _hapticTimer = Timer.periodic(
      const Duration(milliseconds: 360),
      (_) => HapticFeedback.heavyImpact(),
    );
    final skipped = await _waitOrSkip(const Duration(seconds: 3));
    if (!mounted) return;

    _wobble.stop();
    _hapticTimer?.cancel();

    if (!skipped) {
      // Stage 2 — geyser + launch (~1.4s).
      _geyser.forward(from: 0);
      _launch.forward(from: 0);
      final s2 = await _waitOrSkip(const Duration(milliseconds: 1400));
      if (!mounted) return;
      if (!s2) {
        // Stage 3 — the propeller plane tows the "ONE OF US" banner across the
        // screen in exactly 3s, bobbing, prop spinning.
        _bob.repeat(reverse: true);
        _prop.repeat();
        _plane.forward(from: 0);
        await _waitOrSkip(const Duration(milliseconds: 3000));
        if (!mounted) return;
      }
    }

    // Stage 4 — settle + commit.
    _plane.reset();
    _bob.stop();
    _prop.stop();
    _geyser.reset();
    _launch.reset();
    await context.read<AccidentCounterCubit>().setToday();
    if (!mounted) return;
    final now = DateTime.now();
    setState(() {
      _seqRunning = false;
      _rollToken++; // roll to 0
      _dateCtrl.text =
          '${now.month.toString().padLeft(2, '0')}/'
          '${now.day.toString().padLeft(2, '0')}/'
          '${now.year}';
    });
  }

  /// Wait [d], or resolve early (true) if the user taps to skip.
  Completer<bool>? _skip;
  Future<bool> _waitOrSkip(Duration d) async {
    _skip = Completer<bool>();
    Timer(d, () {
      if (_skip != null && !_skip!.isCompleted) _skip!.complete(false);
    });
    return _skip!.future;
  }

  void _skipSequence() {
    if (_skip != null && !_skip!.isCompleted) _skip!.complete(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        // The page is always dark, so pin the back arrow + title to light
        // regardless of the app theme — otherwise light mode paints a dark
        // (invisible) arrow on the dark bar.
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white, size: 28),
        title: const Text(
          'Days since last accident',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: Colors.white,
          ),
        ),
      ),
      // Any tap during the sequence skips to the end state.
      body: GestureDetector(
        onTap: _seqRunning ? _skipSequence : null,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: BlocBuilder<AccidentCounterCubit, AccidentCounterState>(
                builder: (context, state) {
                  return Column(
                    children: [
                      const SizedBox(height: 6),
                      const Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Days since last accident '),
                            TextSpan(
                              text: '(i.e. shart)',
                              style: TextStyle(
                                color: Color(0xFF9AA39A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 18),
                      AccidentCounter(
                        value: state.daysSince,
                        size: AccidentCounterSize.full,
                        rollToken: _rollToken,
                      ),
                      const SizedBox(height: 26),
                      const Text(
                        'Enter day of last accident',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _dateRow(),
                      if (_dateError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _dateError!,
                          style: const TextStyle(color: _red, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 12),
                      const Text(
                        'Date can be corrected after pressing TODAY.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF9AA39A), fontSize: 12),
                      ),
                    ],
                  );
                },
              ),
            ),
            // "ONE OF US" plane flyby.
            _planeOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _dateRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      // NOT stretch: in a scroll view the Row's height is unbounded, and
      // stretch forces infinite height on the button's Stack — which silently
      // hides the TODAY button in release builds (assertions stripped).
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 150,
          child: TextField(
            controller: _dateCtrl,
            focusNode: _dateFocus,
            keyboardType: TextInputType.datetime,
            textAlign: TextAlign.center,
            onSubmitted: (_) => _submitDate(),
            inputFormatters: [_MdyFormatter()],
            style: const TextStyle(letterSpacing: 1.0),
            decoration: InputDecoration(
              hintText: 'MM/DD/YYYY',
              hintStyle: const TextStyle(color: Color(0xFF5E675E)),
              filled: true,
              fillColor: _card,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2E362E), width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _lime, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // TODAY button with wobble + geyser.
        AnimatedBuilder(
          animation: Listenable.merge([_wobble, _launch]),
          builder: (context, child) {
            final wob = _wobble.isAnimating ? (_wobble.value * 2 - 1) : 0.0;
            final launchDy = -560.0 * Curves.easeInCubic.transform(_launch.value);
            final launchRot = 4 * 3.14159 * _launch.value; // 720°
            return Transform.translate(
              offset: Offset(0, launchDy),
              child: Transform.rotate(
                angle: wob * 0.12 + launchRot,
                child: child,
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              _geyserWidget(),
              ElevatedButton(
                onPressed: _seqRunning ? null : _todaySequence,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red,
                  disabledBackgroundColor: _red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: _redShadow, width: 0),
                  ),
                ),
                child: const Text(
                  'TODAY',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _geyserWidget() {
    return AnimatedBuilder(
      animation: _geyser,
      builder: (context, _) {
        final t = _geyser.value;
        if (t == 0) return const SizedBox.shrink();
        // Height rises then drains; matches the mockup's spout keyframes.
        final h = t < 0.35
            ? (t / 0.35) * 300
            : t < 0.7
                ? 300
                : (1 - (t - 0.7) / 0.3) * 300;
        return Positioned(
          bottom: 8 + _redButtonBottomGap,
          child: IgnorePointer(
            child: Opacity(
              opacity: t > 0.7 ? (1 - (t - 0.7) / 0.3) : 0.95,
              child: Container(
                width: 40,
                height: h.clamp(0.0, 300.0).toDouble(),
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFDFF3FF), Color(0xFF8FD0F2), Color(0xFF4AA6D8)],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _planeOverlay() {
    return AnimatedBuilder(
      animation: Listenable.merge([_plane, _bob]),
      builder: (context, _) {
        if (_plane.value == 0) return const SizedBox.shrink();
        final w = MediaQuery.of(context).size.width;
        // Whole group (banner + rope + plane) crosses left→right. Start fully
        // off the left edge, end fully off the right.
        const groupW = 260.0;
        final x = -groupW + _plane.value * (w + groupW);
        final bobDy = (_bob.value - 0.5) * 6; // ±3px gentle bob
        return Positioned(
          top: 96,
          left: x,
          child: IgnorePointer(
            child: Transform.translate(
              offset: Offset(0, bobDy),
              // Plane leads (right), banner trails behind on a rope (left) —
              // beach-advertisement style, nose-first, never mirrored.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _lime, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _lime.withValues(alpha: 0.35),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Text(
                      'ONE OF US',
                      style: TextStyle(
                        color: _lime,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  Container(
                    width: 24,
                    height: 2,
                    color: const Color(0xFF5E675E),
                  ),
                  _plane3d(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// The old single-prop plane from the mockup (lime fuselage, tail fin, cockpit,
  /// fixed gear, nose cone) with a Flutter-animated spinning propeller.
  Widget _plane3d() {
    return SizedBox(
      width: 96,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.string(_planeSvg, width: 96, height: 52),
          // Spinning propeller at the nose (viewBox x≈82, y≈27.5).
          Positioned(
            left: 79.4,
            top: 10.5,
            child: AnimatedBuilder(
              animation: _prop,
              builder: (context, _) {
                // scaleY: 1 → .12 → 1 over one turn (edge-on illusion).
                final sy = 0.12 + 0.88 * (math.cos(math.pi * _prop.value)).abs();
                return Transform.scale(
                  scaleY: sy,
                  child: Container(
                    width: 5.2,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC4CCC4).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Masks input to MM/DD/YYYY, inserting slashes as the user types digits.
class _MdyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final b = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(digits[i]);
    }
    final out = b.toString();
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}
