// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/blocs/my_uploads/my_uploads_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/views/home/firmware_update_card.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/cubits/flatch_ble/flatch_ble_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:toastification/toastification.dart';

class FlatchBleScreen extends StatefulWidget {
  const FlatchBleScreen({super.key});

  @override
  State<FlatchBleScreen> createState() => _FlatchBleScreenState();
}

class _FlatchBleScreenState extends State<FlatchBleScreen> {
  StreamSubscription<double>? _downloadProgressSubscription;
  int? _currentDownloadSlot;
  bool _isDownloadingDialogOpen = false;

  @override
  void initState() {
    context.read<MyUploadsBloc>().add(FetcnInitialUploads());
    // Bring up the radio here — NOT at app launch — so the OS Bluetooth prompt
    // only appears when the user actually opens the device page.
    context.read<FlatchBleCubit>().startBle();
    super.initState();
  }

  @override
  void dispose() {
    _downloadProgressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double height = context.screenHeight;

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/flatch_logo.png',
          height: height * 0.08,
          width: height * 0.08,
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Built-in sounds',
            icon: const Icon(Icons.library_music_outlined),
            onPressed: () => context.pushNamed(AppRoute.stockSounds.name),
          ),
        ],
      ),
      body: BlocListener<FlatchBleCubit, FlatchBleState>(
        listener: (context, state) {
          // Listen for download progress changes
          if (state.isDownloading && state.downloadingSlot != null) {
            if (!_isDownloadingDialogOpen) {
              _currentDownloadSlot = state.downloadingSlot;
              _showDownloadDialog(context, state.downloadingSlot!);
            } else {
              setState(() {}); // Update dialog progress
            }
          } else if (_isDownloadingDialogOpen && !state.isDownloading) {
            Navigator.of(context, rootNavigator: true).pop();
            _isDownloadingDialogOpen = false;

            if (_currentDownloadSlot != null &&
                state.downloadedFilePaths.containsKey(_currentDownloadSlot)) {
              _showShareDialog(
                context,
                _currentDownloadSlot!,
                state.downloadedFilePaths[_currentDownloadSlot]!,
              );
            }
            _currentDownloadSlot = null;
          }
        },
        child: BlocBuilder<FlatchBleCubit, FlatchBleState>(
          builder: (context, state) {
            return state.connectedDevice == null
                ? _buildScanUI(context, state)
                : _buildMainUI(context, state);
          },
        ),
      ),
    );
  }

  /// Explains why pairing happens in-app and what to do when the device's
  /// signal times out. Dismissed by the X or by tapping anywhere outside.
  void _showBluetoothInfoDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true, // tap anywhere off the bubble to close
      builder:
          (dialogContext) => Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 46, 20, 22),
                  child: Text(
                    'We can only connect your Flatch device within the app '
                    'because each Flatch has a unique encrypted connection '
                    'with the app.\n\n'
                    'The Flatch bluetooth signal turns off after two minutes '
                    'of searching for the app to preserve battery power. '
                    'Simply turn the device off and on again to connect to '
                    'Bluetooth.',
                    style: TextStyle(fontSize: 14.5, height: 1.5),
                  ),
                ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(dialogContext).pop(),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  void _showDownloadDialog(BuildContext context, int slot) {
    _isDownloadingDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Retrieving"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Retrieving sound from slot $slot…"),
                  const SizedBox(height: 20),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Actually abort the transfer (not just close the dialog).
                    context.read<FlatchBleCubit>().cancelTransfer();
                    Navigator.pop(context);
                    _isDownloadingDialogOpen = false;
                  },
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showShareDialog(
    BuildContext context,
    int slot,
    String filePath,
  ) async {
    final fileName = filePath.split('/').last;
    final downloadsPath = await _getDownloadsPath();
    final downloadsFile = File("$downloadsPath/$fileName");
    try {
      final sourceFile = File(filePath);
      final bytes = await sourceFile.readAsBytes();
      await downloadsFile.writeAsBytes(bytes);

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Retrieval complete."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("File saved.", textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _shareFile(downloadsFile.path);
                      },
                      child: const Text("Share"),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    } catch (e) {
      showToast(
        context: context,
        message: 'Error saving file: $e',
        type: ToastificationType.error,
      );
    }
  }

  Future<String> _getDownloadsPath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      if (dir == null) {
        throw Exception('External storage not available');
      }

      // Optional: create subfolder
      final soundDir = Directory('${dir.path}/sounds');
      if (!await soundDir.exists()) {
        await soundDir.create(recursive: true);
      }

      return soundDir.path;
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      return docsDir.path;
    }
  }

  Future<void> _shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final fileName = filePath.split('/').last;
        final xFile = XFile(filePath, mimeType: _guessMime(fileName));
        await SharePlus.instance.share(
          ShareParams(files: [xFile], text: 'Check out this sound: $fileName'),
        );
      } else {
        showToast(
          context: context,
          message: 'File not found',
          type: ToastificationType.error,
        );
      }
    } catch (e) {
      showToast(
        context: context,
        message: 'Error sharing file: $e',
        type: ToastificationType.error,
      );
    }
  }

  String _guessMime(String fileName) {
    if (fileName.toLowerCase().endsWith('.wav')) return 'audio/wav';
    if (fileName.toLowerCase().endsWith('.mp3')) return 'audio/mpeg';
    if (fileName.toLowerCase().endsWith('.m4a')) return 'audio/mp4';
    return 'application/octet-stream';
  }

  Widget _buildScanUI(BuildContext context, FlatchBleState state) {
    final isLoading = state.isLoading;
    // Only treat Bluetooth as "off" when the adapter explicitly reports off —
    // not when its state is merely undetermined (iOS reports 'unknown' until
    // BLE is first used).
    final isOff = state.isBluetoothOff;
    final isConnecting = state.isConnecting;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _showBluetoothInfoDialog(context),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(
                                  text:
                                      'Turn on your Flatch and slide the on '
                                      'switch to the On ',
                                ),
                                _wirelessGlyph(),
                                const TextSpan(
                                  text:
                                      ' position, then tap Scan. Pair here in '
                                      "the app — not in your phone's settings.",
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Grant/enable Bluetooth right here rather than sending the
                  // user off to system Settings.
                  if (state.blePermissionDenied || state.isBluetoothOff) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        final cubit = context.read<FlatchBleCubit>();
                        if (state.blePermissionPermanentlyDenied) {
                          cubit.openBleSettings();
                        } else {
                          cubit.requestBleAccess();
                        }
                      },
                      icon: const Icon(Icons.bluetooth_searching),
                      label: Text(
                        state.blePermissionPermanentlyDenied
                            ? 'Open Settings to allow Bluetooth'
                            : 'Allow Bluetooth',
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton.icon(
                    onPressed:
                        isLoading
                            ? null
                            : () =>
                                context.read<FlatchBleCubit>().requestBleAccess(),
                    icon: const Icon(Icons.search),
                    label: Text(isLoading ? 'Scanning…' : 'Scan for my Flatch'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOff)
            SliverFillRemaining(
              child: _buildCenterText(
                "Bluetooth is disabled. Enable it to proceed.",
              ),
            )
          else if (isConnecting)
            SliverFillRemaining(
              child: Column(
                children: [
                  _buildCenterText(
                    state.statusMessage.isEmpty
                        ? "Connecting to your Flatch…"
                        : state.statusMessage,
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 800),
                    builder: (context, value, child) {
                      return Transform.rotate(
                        angle: value * 6.28318,
                        child: child,
                      );
                    },
                    onEnd: () {
                      if (state.isConnecting) {
                        (context as Element).markNeedsBuild();
                      }
                    },
                    child: const Icon(Icons.settings, color: Colors.grey),
                  ),
                ],
              ),
            )
          else if (state.error != null)
            SliverFillRemaining(child: _buildErrorWithRetry(context, state))
          else if (!isLoading && state.devices.isEmpty)
            SliverFillRemaining(child: _buildNoDevices(context))
          else if (!isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate((_, index) {
                final d = state.devices[index];
                // Every listed device is already filtered to Flatch. Show the
                // advertised per-unit name (e.g. "Flatch-1A2B"); if firmware
                // still advertises the legacy "Latch …" name, present "Flatch".
                final adv =
                    d.platformName.isNotEmpty ? d.platformName : d.advName;
                final name =
                    adv.isEmpty
                        ? 'Flatch'
                        : (adv.toLowerCase().startsWith('latch')
                            ? 'Flatch'
                            : adv);
                final rssi = state.deviceRssi[d.remoteId.str];

                return ListTile(
                  leading: const Icon(Icons.speaker, color: Colors.deepPurple),
                  title: Text(name),
                  subtitle: rssi == null ? null : Text(_signalLabel(rssi)),
                  trailing: _SignalBars(rssi: rssi),
                  onTap: () => context.read<FlatchBleCubit>().connectDevice(d),
                );
              }, childCount: state.devices.length),
            ),
          if (isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorWithRetry(BuildContext context, FlatchBleState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 12),
            const Text(
              "The device could not be reached.",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Something went wrong.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Tip: pair your Flatch here in the app, not in your phone’s '
                'Bluetooth settings. If you already tried pairing in Settings, '
                'open Settings → Bluetooth → your Flatch → "Forget '
                'This Device", then scan again here.',
                style: TextStyle(fontSize: 13),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Scan again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.read<FlatchBleCubit>().scanDevices(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDevices(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              'assets/svgs/device_signal.svg',
              width: 48,
              height: 48,
              colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
            ),
            const SizedBox(height: 12),
            const Text(
              'No device located.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            // Most common cause now that the device powers its radio down:
            // it has simply been on too long. Lead with it.
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Has your Flatch been on for more than 2 minutes? Its '
                'Bluetooth switches off to save battery. Turn the Flatch off '
                'and on again, then scan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, height: 1.35),
              ),
            ),
            ..._tipRich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Is your Flatch on? Slide the on switch to the On ',
                  ),
                  _wirelessGlyph(size: 13, color: Colors.grey),
                  const TextSpan(text: ' position.'),
                ],
              ),
            ),
            ..._tip('Is it within a few feet of your phone?'),
            ..._tip('Is it charged? Charge it, then scan again.'),
            const SizedBox(height: 8),
            const Text(
              'Pair here in the app, not in phone Settings.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Scan again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => context.read<FlatchBleCubit>().scanDevices(),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tip(String text) => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    ),
  ];

  /// Like [_tip] but takes rich content (so an inline glyph can be embedded).
  List<Widget> _tipRich(InlineSpan span) => [
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: Text.rich(span, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    ),
  ];

  /// Inline wireless glyph for use inside a [TextSpan] (the "On" position mark).
  /// Matches the device-tab / bottom-nav wireless icon — deliberately NOT the
  /// Bluetooth figure mark, which is a trademark we can't use.
  WidgetSpan _wirelessGlyph({
    double size = 15,
    Color color = AppColors.primary,
  }) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: SvgPicture.asset(
          'assets/svgs/device_signal.svg',
          width: size,
          height: size,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        ),
      ),
    );
  }

  Widget _buildCenterText(String text) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        text,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
      ),
    ),
  );

  Widget _buildMainUI(BuildContext context, FlatchBleState state) {
    final cubit = context.read<FlatchBleCubit>();

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              state.statusMessage.isNotEmpty
                  ? state.statusMessage
                  : 'Connected',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),

          // Firmware OTA: offers/relays a device update when connected.
          const FirmwareUpdateCard(),

          if (state.uploadProgress > 0 && state.uploadProgress < 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  Text(
                    'Upload: ${(state.uploadProgress * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: state.uploadProgress,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 10),
          Expanded(child: _buildSlotList(context, state)),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload_file),
              label: const Text(
                'Add From Library',
                style: TextStyle(fontSize: 14),
              ),
              onPressed: () {
                _showAddFromLibraryDialog(context);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.sync),
              label: const Text(
                'Deploy to Flatch',
                style: TextStyle(fontSize: 14),
              ),
              onPressed: () async {
                final bleState = context.read<FlatchBleCubit>().state;

                if (bleState.queuedLibrarySounds.isEmpty) {
                  showToast(
                    context: context,
                    message: 'Please add sounds from Library before syncing',
                    type: ToastificationType.warning,
                  );
                  return;
                }
                final bool isSuccess = await cubit.syncToFlatch();
                if (isSuccess) {
                  showToast(
                    context: context,
                    message: 'Deployment complete.',
                    type: ToastificationType.success,
                  );
                } else {
                  showToast(
                    context: context,
                    message: 'Deployment failed.',
                    type: ToastificationType.error,
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showAddFromLibraryDialog(BuildContext context) {
    final Set<String> loadingIds = {};
    final Set<String> addedIds = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return BlocBuilder<MyUploadsBloc, MyUploadsState>(
              builder: (context, state) {
                if (state is MyUploadsLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (state is MyUploadsError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(child: Text(state.message)),
                  );
                }

                if (state is MyUploadsLoaded) {
                  final myUid = FirebaseAuth.instance.currentUser?.uid;

                  final myFarts =
                      state.uploads.where((f) => f.uid == myUid).toList();
                  final communityFarts =
                      state.uploads.where((f) => f.uid != myUid).toList();

                  return SafeArea(
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 50,
                          ),
                          child: Text(
                            'Add From Library',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        Expanded(
                          child: ListView(
                            children: [
                              if (myFarts.isNotEmpty) ...[
                                _sectionHeader('My Farts'),
                                ...myFarts.map(
                                  (f) => _libraryTile(
                                    context,
                                    f,
                                    loadingIds,
                                    addedIds,
                                    setState,
                                  ),
                                ),
                              ],
                              if (communityFarts.isNotEmpty) ...[
                                _sectionHeader('Community Farts'),
                                ...communityFarts.map(
                                  (f) => _libraryTile(
                                    context,
                                    f,
                                    loadingIds,
                                    addedIds,
                                    setState,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Done'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return const SizedBox();
              },
            );
          },
        );
      },
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
        ),
      ),
    );
  }

  final MethodChannel _audioChannel = MethodChannel('audio.converter');

  Future<File> _downloadAndConvertToWav(FartModel fart) async {
    final dir = await getApplicationDocumentsDirectory();
    final libraryDir = Directory('${dir.path}/flatch/library');

    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }

    // 1️⃣ Download MP3
    final mp3File = File('${libraryDir.path}/${fart.id}.mp3');
    final request = await HttpClient().getUrl(Uri.parse(fart.fileUrl));
    final response = await request.close();
    final bytes = await consolidateHttpClientResponseBytes(response);
    await mp3File.writeAsBytes(bytes, flush: true);

    // 2️⃣ Convert MP3 → WAV (native Android)
    final wavPath = await _audioChannel.invokeMethod<String>('convertAudio', {
      'inputPath': mp3File.path,
      'outputExt': 'wav',
    });

    if (wavPath == null) {
      throw Exception('WAV conversion failed');
    }

    return File(wavPath);
  }

  Widget _libraryTile(
    BuildContext context,
    FartModel fart,
    Set<String> loadingIds,
    Set<String> addedIds,
    void Function(void Function()) setState,
  ) {
    final bleCubit = context.read<FlatchBleCubit>();

    Widget trailing;

    if (loadingIds.contains(fart.id)) {
      trailing = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (addedIds.contains(fart.id)) {
      trailing = const Icon(Icons.check_circle, color: Colors.green);
    } else {
      trailing = IconButton(
        icon: const Icon(Icons.add),
        onPressed: () async {
          setState(() {
            loadingIds.add(fart.id);
          });

          try {
            final localWav = await _downloadAndConvertToWav(fart);
            bleCubit.addFromLibrary(localWav);

            setState(() {
              loadingIds.remove(fart.id);
              addedIds.add(fart.id);
            });

            showToast(
              context: context,
              message: 'Added to queue',
              type: ToastificationType.success,
            );
          } catch (e) {
            setState(() {
              loadingIds.remove(fart.id);
            });

            showToast(
              context: context,
              message: 'Failed to add sound',
              type: ToastificationType.error,
            );
          }
        },
      );
    }

    return ListTile(
      leading: const Icon(Icons.music_note),
      title: Text(fart.title),
      trailing: trailing,
    );
  }

  Widget _buildSlotList(BuildContext context, FlatchBleState state) {
    final cubit = context.read<FlatchBleCubit>();
    final slots = List<int>.from(state.availableSlots);

    if (slots.isEmpty) {
      return const Center(child: Text('No sounds found'));
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: slots.length,
      // onReorderItem already adjusts newIndex for the removed item, so the
      // manual `if (oldIndex < newIndex) newIndex -= 1;` compensation is gone.
      onReorderItem: (oldIndex, newIndex) async {
        final item = slots.removeAt(oldIndex);
        slots.insert(newIndex, item);

        await cubit.reorderSlots(slots);

        showToast(
          context: context,
          message: 'Order updated',
          type: ToastificationType.success,
        );
      },
      itemBuilder: (context, index) {
        final slot = slots[index];
        final isDownloading =
            state.isDownloading && state.downloadingSlot == slot;
        final filePath = state.downloadedFilePaths[slot];
        final hasLocalFile = filePath != null;

        return Padding(
          key: ValueKey(slot),
          padding: const EdgeInsets.only(bottom: 12),
          child: FartCard(
            isReorderWidget: true,
            title: 'Slot $slot',
            fileUrl: hasLocalFile ? filePath : '',
            isPlaying: isDownloading,
            onPlayPause: () => cubit.playSlot(slot),
            onDownload:
                isDownloading
                    ? null
                    : () {
                      cubit.downloadSlot(slot);
                    },
            onDelete: () async {
              await cubit.deleteSlot(slot);
              showToast(
                context: context,
                message: 'Deleted slot $slot',
                type: ToastificationType.success,
              );
            },
            onShare: hasLocalFile ? () => _shareFile(filePath) : null,
          ),
        );
      },
    );
  }
}

// ---- Signal strength (RSSI) helpers for the pairing list ----

String _signalLabel(int rssi) {
  if (rssi >= -60) return 'Strong signal · very close';
  if (rssi >= -75) return 'Good signal';
  return 'Weak signal · move closer';
}

class _SignalBars extends StatelessWidget {
  final int? rssi;
  const _SignalBars({required this.rssi});

  @override
  Widget build(BuildContext context) {
    // Map RSSI (dBm) to 0–3 bars: >=-60 strong, >=-75 good, else weak.
    final r = rssi;
    final level =
        r == null
            ? 0
            : r >= -60
            ? 3
            : r >= -75
            ? 2
            : 1;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final active = i < level;
        return Container(
          width: 5,
          height: 8.0 + i * 5,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: active ? Colors.deepPurple : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }
}
