// ignore_for_file: use_build_context_synchronously

import 'package:flatch/blocs/upload_fart/upload_fart_bloc.dart';
import 'package:flatch/common/services/toast_service.dart';
import 'package:flatch/common/widgets/audio_player.dart';
import 'package:flatch/common/widgets/audio_recorder.dart';
import 'package:flatch/common/widgets/audio_service.dart';
import 'package:flatch/common/widgets/fart_form.dart';
import 'package:flatch/common/widgets/input_selector.dart';
import 'package:flatch/common/widgets/upload.dart';
import 'package:flatch/cubits/audio_trim/audio_trim_cubit.dart';
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

  bool _isPublic = true;
  String? _uploadChoice;
  String? _filePath;
  String? _fileName;
  String? _fileType;
  String? _selectedCategory;
  Duration? _audioDuration;

  @override
  void initState() {
    super.initState();

    _audioService.initialize();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _audioService.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void clearFormAndState() {
    setState(() {
      _uploadChoice = null;
      _filePath = null;
      _fileName = null;
      _fileType = null;
      _selectedCategory = null;
      _audioDuration = null;
      _isPublic = true;

      _titleController.clear();

      _audioService.stop();
      _audioService.loadAudio('');
      context.read<AudioTrimCubit>().clear();
    });
  }

  void _onInputChoice(String choice) {
    setState(() {
      _uploadChoice = choice;
      _filePath = null;
      _fileName = null;
      _fileType = null;
      _isPublic = true;
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
    setState(() {
      _filePath = path;
      _fileName = name;
      _fileType = type;
      _audioDuration = duration;
    });
  }

  void _onCategorySelected(String category) {
    setState(() => _selectedCategory = category);
  }

  void _handleUpload() async {
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

    print("File Type: $fileType");
    print("Path of the file: $pathToUpload");

    context.read<UploadFartBloc>().add(
      UploadUserFart(
        title: _titleController.text,
        category: _selectedCategory ?? '',
        fileType: fileType, 
        filePath: pathToUpload,
        duration: durationToUpload,
        isPublic: _isPublic,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    double height = MediaQuery.of(context).size.height;

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
      body: BlocListener<UploadFartBloc, UploadFartState>(
        listener: (context, state) {
          if (state is UploadFartSuccess) {
            showToast(
              context: context,
              message: 'Upload successful ✅',
              type: ToastificationType.success,
            );
            _audioService.pause();
            clearFormAndState();
          } else if (state is UploadFartFailure) {
            showToast(
              context: context,
              message: 'Upload failed ❌: ${state.error}',
              type: ToastificationType.error,
            );
          }
        },
        child: Column(
          children: [
            Expanded(
              child: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                        VideoToAudioWidget(onAudioExtracted: _onAudioSelected)
                      else if (_uploadChoice == 'audio')
                        AudioPickerWidget(onAudioSelected: _onAudioSelected),

                      const SizedBox(height: 16),

                      if (_filePath != null) ...[
                        AudioPlayerWidget(
                          filePath: _filePath!,
                          fileName: _fileName ?? 'Unknown',
                          audioService: _audioService,
                          onTrimmed: (String newPath, Duration newDuration) {
                            setState(() {
                              _filePath = newPath;
                              _audioDuration = newDuration;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        SwitchListTile(
                          title: const Text("Make Public"),
                          value: _isPublic,
                          onChanged: (val) => setState(() => _isPublic = val),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 16),

                        FartDetailsForm(
                          formKey: _formKey,
                          titleController: _titleController,
                          selectedCategory: _selectedCategory,
                          onCategoryChanged: _onCategorySelected,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // always visible upload button
            Padding(
              padding: const EdgeInsets.all(16),
              child: UploadButtonWidget(
                canUpload: true,
                onUpload: _handleUpload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
