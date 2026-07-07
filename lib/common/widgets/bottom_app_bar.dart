// ignore_for_file: deprecated_member_use

import 'package:flatch/blocs/app_check_version/app_check_version_cubit.dart';
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
      "assets/svgs/home1.svg",
      "assets/svgs/add.svg",
      "assets/svgs/usb.svg",
      "assets/svgs/settings.svg",
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

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        style: ButtonStyle().copyWith(
                          backgroundColor: WidgetStatePropertyAll(
                            isSelected
                                ? Theme.of(
                                  context,
                                ).colorScheme.secondary.withOpacity(0.15)
                                : Colors.transparent,
                          ),
                          side: const WidgetStatePropertyAll(
                            BorderSide(color: Colors.transparent, width: 2),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                        highlightColor: Colors.transparent,
                        onPressed: () {
                          HapticFeedback.heavyImpact();
                          context.read<UserAppDashboardCubit>().onUpdateIndex(
                            index,
                          );
                          if (index == 1) {
                            context
                                .read<UserAppDashboardCubit>()
                                .onTapActions();
                          }
                        },
                        icon: SvgPicture.asset(
                          allSvgs[index],
                          width: 25,
                          height: 25,
                          color:
                              isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(
                                    context,
                                  ).iconTheme.color?.withOpacity(.6),
                        ),
                      ),
                      const Gap(10),
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
