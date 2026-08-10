import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Days Since Last Accident" state. [lastAccidentDate] is an ISO date
/// ("YYYY-MM-DD", date only) or null (never set). [daysSince] is derived — null
/// renders as dashes on the scoreboard.
class AccidentCounterState extends Equatable {
  final String? lastAccidentDate;
  final int? daysSince;

  /// Bumps to force the header/badge counters to re-roll (cold start, and
  /// resume from background after >5 min). The detail page drives its own roll.
  final int rollToken;

  const AccidentCounterState({
    this.lastAccidentDate,
    this.daysSince,
    this.rollToken = 0,
  });

  bool get isSet => lastAccidentDate != null && lastAccidentDate!.isNotEmpty;

  @override
  List<Object?> get props => [lastAccidentDate, daysSince, rollToken];
}

/// Owns the last-accident date and the derived day count. Recomputes on app
/// foreground and at local midnight so the number is never stale across days.
/// Persists to `app_users/{uid}.lastAccidentDate` and mirrors to local storage
/// so it works offline / before the network responds.
class AccidentCounterCubit extends Cubit<AccidentCounterState>
    with WidgetsBindingObserver {
  AccidentCounterCubit() : super(const AccidentCounterState()) {
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  static const _prefsKey = 'flatch_last_accident_date';
  Timer? _midnightTimer;
  DateTime? _pausedAt;
  int _rollToken = 0;

  /// The current roll token — bumped on cold start and long-background resume.
  int get rollToken => _rollToken;

  /// Cap the DISPLAY at 999; the stored date stays exact.
  static const int displayCap = 999;

  // ---- lifecycle ----

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Roll again only if we were backgrounded for more than 5 minutes.
      final away = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
      _recompute(bumpRoll: away > const Duration(minutes: 5));
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _midnightTimer?.cancel();
    return super.close();
  }

  // ---- load / compute ----

  Future<void> _load() async {
    // Local cache first (instant, offline), then reconcile with the server.
    String? iso;
    try {
      iso = (await SharedPreferences.getInstance()).getString(_prefsKey);
    } catch (_) {}
    _emitFor(iso);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('app_users')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final remote = snap.docs.first.data()['lastAccidentDate'] as String?;
          if (remote != iso) {
            await _cacheLocally(remote);
            _emitFor(remote);
          }
        }
      } catch (_) {
        // offline / not ready — keep the local value.
      }
    }
    _scheduleMidnight();
  }

  void _recompute({bool bumpRoll = false}) {
    if (bumpRoll) _rollToken++;
    _emitFor(state.lastAccidentDate);
    _scheduleMidnight();
  }

  void _emitFor(String? iso) {
    emit(
      AccidentCounterState(
        lastAccidentDate: iso,
        daysSince: daysSinceFor(iso),
        rollToken: _rollToken,
      ),
    );
  }

  /// Whole days between [iso] and today, in the device's LOCAL timezone.
  /// null date → null; a future date clamps to 0 (input validation blocks it).
  static int? daysSinceFor(String? iso) {
    if (iso == null || iso.isEmpty) return null;
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final then = DateTime(y, m, d);
    final diff = today.difference(then).inDays;
    return diff < 0 ? 0 : diff;
  }

  void _scheduleMidnight() {
    _midnightTimer?.cancel();
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      _recompute();
    });
  }

  // ---- mutations ----

  /// Set the last-accident date. [date] is a local calendar date; stored as
  /// "YYYY-MM-DD". Rolls all counters via the new state.
  Future<void> setDate(DateTime date) async {
    final iso = _iso(date);
    await _cacheLocally(iso);
    _emitFor(iso);
    await _persistRemote(iso);
  }

  /// The TODAY reset — last accident is now.
  Future<void> setToday() => setDate(DateTime.now());

  Future<void> _cacheLocally(String? iso) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (iso == null) {
        await prefs.remove(_prefsKey);
      } else {
        await prefs.setString(_prefsKey, iso);
      }
    } catch (_) {}
  }

  Future<void> _persistRemote(String iso) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app_users')
          .where('uid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) {
        await snap.docs.first.reference.update({'lastAccidentDate': iso});
      }
    } catch (_) {
      // offline — the local cache holds it; a later save will sync.
    }
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
