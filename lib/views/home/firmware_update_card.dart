import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/services/firmware_release_service.dart';
import 'package:flatch/cubits/flatch_ble/flatch_ble_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shows on the connected-device screen: offers a firmware update when one is
/// available, and renders OTA progress / errors. The device does the actual
/// download+install; this just triggers it and relays status from the cubit.
class FirmwareUpdateCard extends StatefulWidget {
  const FirmwareUpdateCard({super.key});

  @override
  State<FirmwareUpdateCard> createState() => _FirmwareUpdateCardState();
}

class _FirmwareUpdateCardState extends State<FirmwareUpdateCard> {
  FirmwareRelease? _release;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    FirmwareReleaseService.current().then((r) {
      if (!mounted) return;
      setState(() {
        _release = r;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FlatchBleCubit, FlatchBleState>(
      buildWhen: (a, b) =>
          a.otaStateLabel != b.otaStateLabel ||
          a.otaProgress != b.otaProgress ||
          a.otaError != b.otaError ||
          a.deviceFirmwareVersion != b.deviceFirmwareVersion,
      builder: (context, state) {
        // 1. An OTA is running.
        if (state.otaStateLabel != null) {
          return _progressCard(context, state);
        }
        // 2. An OTA just failed.
        if (state.otaError != null) {
          return _errorCard(context, state.otaError!);
        }
        // 3. Update available?
        if (!_loaded || _release == null) return const SizedBox.shrink();
        final r = _release!;
        if (!FirmwareReleaseService.isNewer(
          r.version,
          state.deviceFirmwareVersion,
        )) {
          return const SizedBox.shrink(); // up to date
        }
        return _availableCard(context, r, state.deviceFirmwareVersion);
      },
    );
  }

  Widget _shell({required Widget child, Color? border}) => Container(
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: (border ?? AppColors.primary).withValues(alpha: 0.4),
      ),
    ),
    child: child,
  );

  Widget _availableCard(
    BuildContext context,
    FirmwareRelease r,
    String? current,
  ) {
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.system_update, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Device update available (v${r.version})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 4),
            Text(
              'Your Flatch is on v$current.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          if (r.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.notes, style: const TextStyle(fontSize: 13)),
          ],
          const SizedBox(height: 6),
          Text(
            'Keep your Flatch on and charged (≥${r.minBatteryPct}%) during the '
            'update. It restarts when done.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.download),
              label: const Text('Update device'),
              onPressed: () => _startFlow(context, r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _progressCard(BuildContext context, FlatchBleState state) {
    final pct = (state.otaProgress * 100).round();
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.otaStateLabel ?? 'Updating…',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: state.otaProgress > 0 ? state.otaProgress : null,
              minHeight: 8,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.otaProgress > 0 ? '$pct%' : 'Working…',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(
            "Don't power off your Flatch. If the update is interrupted it "
            'safely keeps the current version.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(BuildContext context, String message) {
    return _shell(
      border: Colors.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Update not completed',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  context.read<FlatchBleCubit>().clearOtaError(),
              child: const Text('Dismiss'),
            ),
          ),
        ],
      ),
    );
  }

  /// Collects Wi-Fi credentials (the device needs them to download), then
  /// starts the OTA.
  Future<void> _startFlow(BuildContext context, FirmwareRelease r) async {
    final creds = await showDialog<({String ssid, String password})>(
      context: context,
      builder: (_) => const _WifiDialog(),
    );
    if (creds == null || !context.mounted) return;
    await context.read<FlatchBleCubit>().startOta(
      r,
      wifiSsid: creds.ssid,
      wifiPassword: creds.password,
    );
  }
}

class _WifiDialog extends StatefulWidget {
  const _WifiDialog();

  @override
  State<_WifiDialog> createState() => _WifiDialogState();
}

class _WifiDialogState extends State<_WifiDialog> {
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ssid.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wi-Fi for the update'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Your Flatch downloads the update over Wi-Fi. Enter a 2.4 GHz '
            'network it can reach.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ssid,
            onChanged: (_) => setState(() {}), // re-evaluate the Start button
            decoration: const InputDecoration(
              labelText: 'Network name (SSID)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _ssid.text.trim().isEmpty
              ? null
              : () => Navigator.pop(
                  context,
                  (ssid: _ssid.text.trim(), password: _pass.text),
                ),
          child: const Text('Start update'),
        ),
      ],
    );
  }
}
