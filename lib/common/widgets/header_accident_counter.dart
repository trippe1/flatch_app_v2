import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/widgets/accident_counter.dart';
import 'package:flatch/cubits/accident_counter/accident_counter_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// The persistent mini scoreboard for AppBars — reads [AccidentCounterCubit]
/// and taps through to the detail page. Re-rolls once per app foreground via
/// the cubit's [AccidentCounterCubit.rollToken].
class HeaderAccidentCounter extends StatelessWidget {
  const HeaderAccidentCounter({super.key, this.padding});

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.only(right: 10),
      child: Center(
        child: BlocBuilder<AccidentCounterCubit, AccidentCounterState>(
          builder: (context, state) {
            return AccidentCounter(
              value: state.daysSince,
              size: AccidentCounterSize.mini,
              rollToken: state.rollToken,
              onTap: () => context.pushNamed(AppRoute.accidentCounter.name),
            );
          },
        ),
      ),
    );
  }
}
