// ignore_for_file: deprecated_member_use

import 'package:flatch/blocs/upload_fart/upload_fart_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UploadButtonWidget extends StatelessWidget {
  final bool canUpload;
  final VoidCallback onUpload;

  const UploadButtonWidget({
    super.key,
    required this.canUpload,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UploadFartBloc, UploadFartState>(
      listener: (context, state) {
        if (state is UploadFartFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error)),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is UploadFartLoading;

        final buttonColor =
            canUpload && !isLoading ? AppColors.primary : Colors.grey[400];

        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: canUpload && !isLoading ? onUpload : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonColor,
              elevation: canUpload ? 6 : 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              shadowColor:
                  canUpload
                      ? AppColors.primary.withOpacity(0.4)
                      : Colors.transparent,
            ),
            child:
                isLoading
                    ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Saving...',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    )
                    : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        const Text(
                          'Save to Library',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
          ),
        );
      },
    );
  }
}
