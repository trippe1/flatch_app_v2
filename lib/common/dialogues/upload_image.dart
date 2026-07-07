import 'package:flatch/blocs/student_profile_managment/profile_managment_bloc.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/common/widgets/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

class UploadImageDialog extends StatelessWidget {
  const UploadImageDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      contentPadding: const EdgeInsets.only(bottom: 10),
      title: const Center(
        child: TextWidget(text: "Update Image", weight: FontWeight.bold),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Gap(10),
            const TextWidget(text: "Update profile image using"),
            const Gap(15),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                2,
                (index) => TextButton(
                  onPressed: () {
                    context.read<ProfileManagmentBloc>().add(
                      UploadUserImageEvent(
                        source:
                            index == 0
                                ? ImageSource.camera
                                : ImageSource.gallery,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: const ButtonStyle().copyWith(
                    minimumSize: const WidgetStatePropertyAll(Size(120, 40)),
                    textStyle: WidgetStatePropertyAll(
                      style(size: 16, weight: FontWeight.bold),
                    ),
                    backgroundColor: WidgetStatePropertyAll(
                      index == 0 ? AppColors.background : null,
                    ),
                    foregroundColor: WidgetStatePropertyAll(
                      index == 0 ? AppColors.primary : null,
                    ),
                  ),
                  child: Text(index == 0 ? "Camera" : "Gallery"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
