// ignore_for_file: use_build_context_synchronously

import 'package:flatch/blocs/upload_fart/upload_fart_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/constants/upload_messages.dart';
import 'package:flatch/common/services/app_logger.dart';
import 'package:flatch/common/services/audio_fx.dart';
import 'package:flatch/common/services/email_verification_gate.dart';
import 'package:flatch/common/services/audio_dsp.dart';
import 'package:flatch/common/services/profanity_filter.dart';
import 'package:flatch/views/profile/my_uploads.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/audio_effects_panel.dart';
import 'package:flatch/common/widgets/audio_player.dart';
import 'package:flatch/common/widgets/audio_recorder.dart';
import 'package:flatch/common/widgets/audio_service.dart';
import 'package:flatch/common/widgets/fart_form.dart';
import 'package:flatch/common/widgets/input_selector.dart';
import 'package:flatch/common/widgets/upload.dart';
import 'package:flatch/cubits/audio_trim/audio_trim_cubit.dart';
import 'package:flatch/cubits/upload_draft/upload_draft_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toastification/toastification.dart';

class UploadFartScreen extends StatefulWidget {
  const UploadFartScreen({super.key});

  @override
  State<UploadFartScreen> createState() => _UploadFartScreenState();
}

class _UploadFartScreenState extends State<UploadFartScreen> {
  final AudioService _audioService = AudioService();
  final _titleController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  // Remembers the input tile across opens within the app session.
  static String _lastUploadChoice = 'record';

  bool _isPublic = true;
  String? _uploadChoice;
  bool _autoOpenPicker = false;

  String? _originalPath; // raw recorded/picked file (effects applied from here)
  String? _filePath; // working file = original + effects (plays / uploads)
  String? _fileName;
  Duration? _audioDuration;

  // Crop selection (seconds), preserved across effect changes + navigation.
  double _trimStart = 0.0;
  double? _trimEnd;

  // Sound-editor effect settings (noise reduction, echo, reverb).
  FxSettings _fx = const FxSettings();
  bool _fxProcessing = false;

  @override
  void initState() {
    super.initState();
    _audioService.initialize();

    // Restore an in-progress draft (survives leaving/returning to the tab).
    final draft = context.read<UploadDraftCubit>().state;
    if (draft.hasDraft) {
      _originalPath = draft.originalPath;
      _filePath = draft.workingPath;
      _fileName = draft.fileName;
      _audioDuration =
          draft.durationMs != null
              ? Duration(milliseconds: draft.durationMs!)
              : null;
      _uploadChoice = draft.uploadChoice ?? _lastUploadChoice;
      _isPublic = draft.isPublic;
      _trimStart = draft.trimStart;
      _trimEnd = draft.trimEnd > 0 ? draft.trimEnd : null;
      _titleController.text = draft.title;
      _fx = draft.fx;
      if (_filePath != null) _audioService.loadAudio(_filePath!);
    } else {
      _uploadChoice = _lastUploadChoice;
    }

    _titleController.addListener(() {
      setState(() {});
      context.read<UploadDraftCubit>().setTitle(_titleController.text);
    });
  }

  @override
  void dispose() {
    _audioService.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _resetLocal() {
    _uploadChoice = _lastUploadChoice;
    _originalPath = null;
    _filePath = null;
    _fileName = null;
    _audioDuration = null;
    _isPublic = true;
    _trimStart = 0.0;
    _trimEnd = null;
    _fx = const FxSettings();
    _titleController.clear();
    _audioService.stop();
    _audioService.loadAudio('');
    context.read<AudioTrimCubit>().clear();
  }

  void clearFormAndState() {
    setState(_resetLocal);
    context.read<UploadDraftCubit>().clear();
  }

  void _deleteDraft() {
    setState(_resetLocal);
    context.read<UploadDraftCubit>().clear();
  }

  void _onInputChoice(String choice) {
    setState(() {
      _uploadChoice = choice;
      _lastUploadChoice = choice;
      _autoOpenPicker = choice == 'audio' || choice == 'video';
    });
  }

  void _onAudioSelected(
    String path,
    String name,
    String type,
    Duration? duration,
  ) async {
    context.read<UploadFartBloc>().add(ResetUploadState());
    await _audioService.loadAudio(path);
    final totalSec = (duration?.inMilliseconds ?? 0) / 1000.0;
    final end = totalSec > 15.0 ? 15.0 : totalSec;
    setState(() {
      _originalPath = path;
      _filePath = path;
      _fileName = name;
      _audioDuration = duration;
      _trimStart = 0.0;
      _trimEnd = end > 0 ? end : null;
      _fx = const FxSettings();
    });
    final draft = context.read<UploadDraftCubit>();
    draft.setFile(
      original: path,
      working: path,
      name: name,
      durationMs: duration?.inMilliseconds,
      choice: _uploadChoice,
    );
    draft.setTrim(0.0, end);
  }

  /// Re-render the working file from the ORIGINAL with the current effect
  /// settings (non-destructive: toggling everything off restores the original).
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
      if (result != null) {
        _filePath = result.path;
        if (result.durationMs != null) {
          _audioDuration = Duration(milliseconds: result.durationMs!);
        }
      }
    });
    final draft = context.read<UploadDraftCubit>();
    draft.setEffects(_fx);
    if (result != null) {
      draft.setWorking(result.path, durationMs: result.durationMs);
    }
  }

  void _handleUpload() async {
    // Posting to the community requires a verified email (browsing does not).
    if (!await EmailVerificationGate.ensureVerified(
      context,
      action: 'share a sound',
    )) {
      return;
    }
    if (!mounted) return;
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
      showToast(
        context: context,
        message: "Please fill all required fields",
        type: ToastificationType.error,
      );
      return;
    }

    if (_filePath == null) {
      showToast(
        context: context,
        message: "Please select or record an audio file",
        type: ToastificationType.error,
      );
      return;
    }

    final trimCubit = context.read<AudioTrimCubit>();
    final trimState = trimCubit.state;

    String pathToUpload = _filePath!;
    int durationToUpload = _audioDuration?.inMilliseconds ?? 0;

    if (trimState.trimStart != 0.0 ||
        trimState.trimEnd != _audioDuration?.inSeconds.toDouble()) {
      if (trimState.trimmedPath != null) {
        pathToUpload = trimState.trimmedPath!;
        durationToUpload =
            trimState.trimmedDuration?.inMilliseconds ?? durationToUpload;
      } else {
        await trimCubit.updateTrim(trimState.trimStart, trimState.trimEnd);

        final updatedState = trimCubit.state;
        if (updatedState.trimmedPath != null) {
          pathToUpload = updatedState.trimmedPath!;
          durationToUpload =
              updatedState.trimmedDuration?.inMilliseconds ?? durationToUpload;
        } else {
          showToast(
            context: context,
            message: "Trimming failed. Please try again.",
            type: ToastificationType.error,
          );
          return;
        }
      }
    }

    if ((durationToUpload / 1000.0) > 15.0) {
      showToast(
        context: context,
        message: "Audio is too long. Please trim to 15 seconds.",
        type: ToastificationType.error,
      );
      return;
    }

    final fileType = pathToUpload.split('.').last.toLowerCase();

    appLogger.d("File Type: $fileType");
    appLogger.d("Path of the file: $pathToUpload");

    // Offensive-language control: a profane/slur title can't go to the
    // community. Keep the sound (with its real name) in the user's library, but
    // upload it privately and tell them why.
    bool uploadPublic = _isPublic;
    if (_isPublic) {
      final offending = ProfanityFilter.find(_titleController.text);
      if (offending != null) {
        uploadPublic = false;
        await _showLanguageBlockedMessage(offending);
        if (!mounted) return;
      }
    }

    context.read<UploadFartBloc>().add(
      UploadUserFart(
        title: _titleController.text,
        fileType: fileType,
        filePath: pathToUpload,
        duration: durationToUpload,
        isPublic: uploadPublic,
      ),
    );
  }

  Future<void> _showLanguageBlockedMessage(String word) async {
    final kind = ProfanityFilter.isSlur(word) ? 'a slur' : 'profanity';
    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Kept out of the community'),
            content: Text(
              "We picked up $kind in the title, so we're not posting this one "
              'to the community feed. Your sound is saved to your library — '
              'give it a community-friendly title to share it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Got it'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;
    final bool hasDraft = _filePath != null;
    final bool canUpload =
        hasDraft && _titleController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      appBar: AppBar(
        title: Image.asset(
          'assets/images/flatch_logo.png',
          height: height * 0.08,
          width: height * 0.08,
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<UploadFartBloc, UploadFartState>(
            listener: (context, state) {
              if (state is UploadFartSuccess) {
                showToast(
                  context: context,
                  message: UploadMessages.random(),
                  type: ToastificationType.success,
                );
                _audioService.pause();
                clearFormAndState();
              } else if (state is UploadFartFailure) {
                showToast(
                  context: context,
                  message: 'Submission failed. ${state.error}',
                  type: ToastificationType.error,
                );
              }
            },
          ),
          // Persist the crop so it survives effect changes + leaving the tab.
          // Skip while another screen (e.g. Edit sound) is pushed on top, since
          // it drives the same shared trim cubit.
          BlocListener<AudioTrimCubit, AudioTrimState>(
            listener: (context, s) {
              if (_filePath == null) return;
              if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
              _trimStart = s.trimStart;
              _trimEnd = s.trimEnd;
              context.read<UploadDraftCubit>().setTrim(s.trimStart, s.trimEnd);
            },
          ),
        ],
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // No draft yet → choose an input and record/pick. Once a sound
                // exists it becomes the draft and new inputs are locked out.
                if (!hasDraft) ...[
                  InputSelectorWidget(
                    selectedChoice: _uploadChoice,
                    onChoiceSelected: _onInputChoice,
                  ),
                  const SizedBox(height: 24),
                  if (_uploadChoice == 'record')
                    AudioRecorderWidget(
                      audioService: _audioService,
                      onRecordingComplete: _onAudioSelected,
                    )
                  else if (_uploadChoice == 'video')
                    VideoToAudioWidget(
                      onAudioExtracted: _onAudioSelected,
                      autoStart: _autoOpenPicker,
                    )
                  else if (_uploadChoice == 'audio')
                    AudioPickerWidget(
                      onAudioSelected: _onAudioSelected,
                      autoStart: _autoOpenPicker,
                    ),
                  const SizedBox(height: 16),
                ] else ...[
                  _draftBanner(),
                  const SizedBox(height: 12),
                  AudioPlayerWidget(
                    key: ValueKey(_filePath),
                    filePath: _filePath!,
                    fileName: _fileName ?? 'Unknown',
                    audioService: _audioService,
                    // Restore the saved crop so effect toggles / navigation
                    // don't reset it. Trim is applied at upload time.
                    initialTrimStart: _trimStart,
                    initialTrimEnd: _trimEnd,
                    onTrimmed: (p, d) {},
                  ),
                  const SizedBox(height: 16),
                  AudioEffectsPanel(
                    settings: _fx,
                    processing: _fxProcessing,
                    onChanged: (next, {required commit}) {
                      setState(() => _fx = next);
                      if (commit) {
                        _reprocessEffects();
                      } else {
                        context.read<UploadDraftCubit>().setEffects(next);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text("Make Public"),
                    value: _isPublic,
                    onChanged: (val) {
                      setState(() => _isPublic = val);
                      context.read<UploadDraftCubit>().setPublic(val);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),
                  FartDetailsForm(
                    formKey: _formKey,
                    titleController: _titleController,
                  ),
                  if (canUpload) ...[
                    const SizedBox(height: 20),
                    UploadButtonWidget(
                      canUpload: true,
                      onUpload: _handleUpload,
                    ),
                  ],
                  const SizedBox(height: 8),
                ],

                // My Fart Library — full feature set (play, rename, delete,
                // share, comments) below the upload area.
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: const [
                    Icon(
                      Icons.library_music_rounded,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'My Fart Library',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const MyUploadsListView(embedded: true),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _draftBanner() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppColors.primary, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Draft in progress — finish it below, or delete it to start a '
                  'new recording.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: ElevatedButton.icon(
            onPressed: _deleteDraft,
            icon: const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'Delete draft',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
