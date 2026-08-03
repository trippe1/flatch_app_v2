import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/models/fart_model.dart';
import 'package:flatch/common/services/audio_cache_service.dart';
import 'package:flatch/common/services/audio_fx.dart';
import 'package:flatch/common/services/audio_dsp.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/audio_effects_panel.dart';
import 'package:flatch/common/widgets/audio_player.dart';
import 'package:flatch/common/widgets/audio_service.dart';
import 'package:flatch/cubits/audio_trim/audio_trim_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:toastification/toastification.dart';

/// Edit a clip you've already uploaded: re-crop and/or add effects, then save
/// in place — re-uploads the file and updates the fart document.
class EditFartScreen extends StatefulWidget {
  final FartModel fart;
  const EditFartScreen({super.key, required this.fart});

  @override
  State<EditFartScreen> createState() => _EditFartScreenState();
}

class _EditFartScreenState extends State<EditFartScreen> {
  final AudioService _audioService = AudioService();
  String? _originalPath;
  String? _localPath;
  bool _saving = false;
  String? _error;

  FxSettings _fx = const FxSettings();
  bool _fxProcessing = false;

  // Preserve the crop across effect changes.
  double _trimStart = 0.0;
  double? _trimEnd;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await getOrDownloadFart(widget.fart.fileUrl);
      if (mounted) {
        setState(() {
          _originalPath = p;
          _localPath = p;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this sound.');
    }
  }

  Future<void> _reprocessEffects() async {
    if (_originalPath == null) return;
    setState(() => _fxProcessing = true);
    final ext = _originalPath!.split('.').last.toLowerCase();
    final result = await AudioFx.render(
      _originalPath!,
      _fx,
      outputExt: ext.isEmpty ? 'm4a' : ext,
    );
    if (!mounted) return;
    setState(() {
      _fxProcessing = false;
      if (result != null) _localPath = result.path;
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_localPath == null) return;
    setState(() => _saving = true);
    try {
      final trimCubit = context.read<AudioTrimCubit>();
      var state = trimCubit.state;
      // Materialize the current trim selection to a file.
      if (state.trimmedPath == null) {
        await trimCubit.updateTrim(state.trimStart, state.trimEnd);
        state = trimCubit.state;
      }
      final pathToUpload = state.trimmedPath ?? _localPath!;
      final durationMs =
          state.trimmedDuration?.inMilliseconds ?? widget.fart.duration;

      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ext = pathToUpload.split('.').last;
      final ref = FirebaseStorage.instance
          .ref()
          .child('farts')
          .child(uid)
          .child('${DateTime.now().millisecondsSinceEpoch}.$ext');
      await ref.putFile(File(pathToUpload));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('user_farts')
          .doc(widget.fart.id)
          .update({
            'fileUrl': url,
            'duration': durationMs,
            'fileType': ext,
            'updatedAt': DateTime.now().millisecondsSinceEpoch,
          });

      // Best-effort: remove the previously stored file.
      try {
        await FirebaseStorage.instance.refFromURL(widget.fart.fileUrl).delete();
      } catch (_) {}

      if (!mounted) return;
      showToast(
        context: context,
        message: 'Changes saved.',
        type: ToastificationType.success,
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showToast(
        context: context,
        message: 'Save failed. $e',
        type: ToastificationType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit sound')),
      body: BlocListener<AudioTrimCubit, AudioTrimState>(
        listener: (context, s) {
          if (_localPath == null) return;
          _trimStart = s.trimStart;
          _trimEnd = s.trimEnd;
        },
        child:
            _error != null
                ? Center(child: Text(_error!))
                : _localPath == null
                ? const Center(child: CircularProgressIndicator())
                : SafeArea(
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              AudioPlayerWidget(
                                key: ValueKey(_localPath),
                                filePath: _localPath!,
                                fileName: widget.fart.title,
                                audioService: _audioService,
                                initialTrimStart: _trimStart,
                                initialTrimEnd: _trimEnd,
                                // Trim applied on save via AudioTrimCubit.
                                onTrimmed: (p, d) {},
                              ),
                              const SizedBox(height: 16),
                              AudioEffectsPanel(
                                settings: _fx,
                                processing: _fxProcessing,
                                onChanged: (next, {required commit}) {
                                  setState(() => _fx = next);
                                  if (commit) _reprocessEffects();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: _saving ? null : _save,
                            child:
                                _saving
                                    ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('Save changes'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
      ),
    );
  }
}
