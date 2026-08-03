import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';

/// Gates the actions that put content into the community — uploading,
/// commenting, voting — behind a verified email address.
///
/// Browsing, listening, and using the Flatch device are deliberately NOT gated:
/// the verification wall used to sit at login, which cost every new user a trip
/// to their inbox before they had any reason to care. Moving it here keeps the
/// protections that actually matter (account recovery, ban evasion, vote
/// farming) and asks only at the point the user is invested.
///
/// Google/Apple sign-ins arrive already verified, so this never fires for them.
class EmailVerificationGate {
  EmailVerificationGate._();

  /// True when the signed-in user may post. Re-checks with the server first, so
  /// a user who verified in another tab isn't told to do it again. Shows a
  /// prompt (with resend) when they can't.
  static Future<bool> ensureVerified(
    BuildContext context, {
    required String action,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (user.emailVerified) return true;

    // The cached flag goes stale the moment they click the link in their email.
    try {
      await user.reload();
    } catch (_) {}
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed?.emailVerified ?? false) return true;

    if (!context.mounted) return false;
    await _showPrompt(context, email: refreshed?.email ?? '', action: action);
    return false;
  }

  static Future<void> _showPrompt(
    BuildContext context, {
    required String email,
    required String action,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _VerifyPromptDialog(
        email: email,
        action: action,
      ),
    );
  }
}

class _VerifyPromptDialog extends StatefulWidget {
  final String email;
  final String action;
  const _VerifyPromptDialog({required this.email, required this.action});

  @override
  State<_VerifyPromptDialog> createState() => _VerifyPromptDialogState();
}

class _VerifyPromptDialogState extends State<_VerifyPromptDialog> {
  bool _sending = false;
  bool _checking = false;
  String? _note;

  Future<void> _resend() async {
    setState(() {
      _sending = true;
      _note = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.sendEmailVerification();
      if (mounted) _note = 'Sent — check your inbox (and spam).';
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _note = e.code == 'too-many-requests'
            ? 'Too many requests. Wait a minute and try again.'
            : 'Could not send right now. Try again shortly.';
      }
    } catch (_) {
      if (mounted) _note = 'Could not send right now. Try again shortly.';
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _recheck() async {
    setState(() {
      _checking = true;
      _note = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
    } catch (_) {}
    final verified =
        FirebaseAuth.instance.currentUser?.emailVerified ?? false;
    if (!mounted) return;
    if (verified) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _checking = false;
      _note = "Still not verified. Open the link in the email first.";
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Verify your email first'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You can browse and use your Flatch freely, but to '
            '${widget.action} we need to confirm your email address'
            '${widget.email.isEmpty ? '' : ' (${widget.email})'}.',
            style: const TextStyle(height: 1.4),
          ),
          if (_note != null) ...[
            const SizedBox(height: 12),
            Text(
              _note!,
              style: const TextStyle(fontSize: 13, color: AppColors.primary),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        TextButton(
          onPressed: _sending ? null : _resend,
          child: Text(_sending ? 'Sending…' : 'Resend email'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _checking ? null : _recheck,
          child: Text(_checking ? 'Checking…' : "I've verified"),
        ),
      ],
    );
  }
}
