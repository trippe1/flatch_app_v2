// ignore_for_file: deprecated_member_use

import 'package:flatch/blocs/app_check_version/app_check_version_cubit.dart';
import 'package:flatch/common/color/app_colors.dart';
import 'package:flatch/cubits/user_app_dashboard/user_app_dashboard_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

class KBottomAppBar extends StatelessWidget {
  const KBottomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    List<String> allSvgs = [
      "assets/svgs/flatch_mark.svg", // 0 community (the Flatch app mark)
      "assets/svgs/fwb.svg", // 1 Farts with Buddies
      "assets/svgs/add.svg", // 2 upload
      "assets/svgs/device_signal.svg", // 3 device connection (wireless glyph)
      "assets/svgs/settings.svg", // 4 settings / profile
    ];

    double width = MediaQuery.of(context).size.width;

    return BlocBuilder<UserAppDashboardCubit, UserAppDashboardState>(
      builder: (context, state) {
        return BlocBuilder<AppCheckVersionCubit, AppCheckVersionState>(
          builder: (context, checkstate) {
            final bool isAndroid15 = checkstate.isAndroid15;
            return Container(
              margin:
                  isAndroid15
                      ? EdgeInsets.only(bottom: width * .09)
                      : EdgeInsets.zero,
              width: width,
              height: 90,
              decoration: BoxDecoration(
                color: Theme.of(context).bottomAppBarTheme.color,
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(-4, 0),
                    color: Theme.of(context).shadowColor.withOpacity(.2),
                    spreadRadius: -6,
                    blurRadius: 10,
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(allSvgs.length, (index) {
                  final bool isSelected = state.index == index;

                  // The Flatch mark (community, 0) has generous internal
                  // padding in its 512×512 artboard, so at 34px it reads
                  // smaller than the tight-viewBox FWB glyph. Render it larger
                  // so its visual weight matches the neighbouring icons, and
                  // trim its button padding so the tap target stays aligned.
                  final double iconSize = index == 0 ? 46 : 34;
                  final double iconPad = index == 0 ? 6 : 12;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: iconSize,
                        padding: EdgeInsets.all(iconPad),
                        style: ButtonStyle().copyWith(
                          backgroundColor: WidgetStatePropertyAll(
                            isSelected
                                ? Theme.of(
                                  context,
                                ).colorScheme.secondary.withOpacity(0.18)
                                : Colors.transparent,
                          ),
                          side: const WidgetStatePropertyAll(
                            BorderSide(color: Colors.transparent, width: 2),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        highlightColor: Colors.transparent,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          context.read<UserAppDashboardCubit>().onUpdateIndex(
                            index,
                          );
                          if (index == 2) {
                            context
                                .read<UserAppDashboardCubit>()
                                .onTapActions();
                          }
                        },
                        icon: SvgPicture.asset(
                          allSvgs[index],
                          width: iconSize,
                          height: iconSize,
                          color:
                              isSelected
                                  // The device tab lights up blue so
                                  // "hardware" reads apart from the green
                                  // community/app actions.
                                  ? (index == 3
                                      ? AppColors.signalBlue
                                      : Theme.of(context).colorScheme.primary)
                                  : Theme.of(
                                    context,
                                  ).iconTheme.color?.withOpacity(.85),
                        ),
                      ),
                      const Gap(6),
                    ],
                  );
                }),
              ),
            );
          },
        );
      },
    );
  }
}
