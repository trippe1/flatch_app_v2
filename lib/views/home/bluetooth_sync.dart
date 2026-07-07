// ignore_for_file: use_build_context_synchronously, avoid_print

import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flatch/blocs/my_uploads/my_uploads_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/extensions/media_query_extension.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/fart_card.dart';
import 'package:flatch/cubits/flatch_ble/flatch_ble_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
  double _currentDownloadProgress = 0.0;

  @override
  void initState() {
    context.read<MyUploadsBloc>().add(FetcnInitialUploads());

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
      ),
      body: BlocListener<FlatchBleCubit, FlatchBleState>(
        listener: (context, state) {
          // Listen for download progress changes
          if (state.isDownloading && state.downloadingSlot != null) {
            if (!_isDownloadingDialogOpen) {
              _currentDownloadSlot = state.downloadingSlot;
              _currentDownloadProgress = state.downloadProgress;
              _showDownloadDialog(context, state.downloadingSlot!);
            } else {
              _currentDownloadProgress = state.downloadProgress;
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

  void _showDownloadDialog(BuildContext context, int slot) {
    _isDownloadingDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Downloading"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Downloading sound from slot $slot..."),
                  const SizedBox(height: 20),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
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
            title: const Text("Download Complete"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "The file has been saved successfully!",
                  textAlign: TextAlign.center,
                ),
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
        await Share.shareXFiles([
          xFile,
        ], text: 'Check out this sound: $fileName');
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
    final isOn = state.isBluetoothOn;
    final isConnecting = state.isConnecting;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        isLoading
                            ? null
                            : () =>
                                context.read<FlatchBleCubit>().scanDevices(),
                    icon: const Icon(Icons.refresh),
                    label: const Text("Refresh"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!isOn)
            SliverFillRemaining(
              child: _buildCenterText("Bluetooth is off. Turn it on"),
            )
          else if (isConnecting)
            SliverFillRemaining(
              child: Column(
                children: [
                  _buildCenterText("Connecting to device..."),
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
            SliverFillRemaining(child: _buildCenterText("No devices found"))
          else if (!isLoading)
            SliverList(
              delegate: SliverChildBuilderDelegate((_, index) {
                final d = state.devices[index];
                final name =
                    d.advName.toLowerCase().startsWith('latch')
                        ? 'Flatch'
                        : (d.advName.isNotEmpty
                            ? d.advName
                            : d.remoteId.toString());

                return ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: Text(name),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Text(
            state.error ?? 'Unknown error',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text("Retry"),
            onPressed: () {
              context.read<FlatchBleCubit>().scanDevices();
            },
          ),
        ],
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
                'Sync to Flatch',
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
                    message: 'Sync completed successfully',
                    type: ToastificationType.success,
                  );
                } else {
                  showToast(
                    context: context,
                    message: 'Sync failed',
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
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex < newIndex) newIndex -= 1;
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
        final fileName = hasLocalFile ? filePath!.split('/').last : '';

        return Padding(
          key: ValueKey(slot),
          padding: const EdgeInsets.only(bottom: 12),
          child: FartCard(
            isReorderWidget: true,
            title: 'Slot $slot',
            fileUrl: hasLocalFile ? filePath! : '',
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
            onShare: hasLocalFile ? () => _shareFile(filePath!) : null,
          ),
        );
      },
    );
  }
}
