import 'package:flatch/blocs/admin_farts/admin_farts_bloc.dart';
import 'package:flatch/blocs/admin_users/admin_users_bloc.dart';
import 'package:flatch/blocs/app_check_version/app_check_version_cubit.dart';
import 'package:flatch/blocs/dashboard/dashboard_bloc.dart';
import 'package:flatch/blocs/delete_my_account/delete_my_account_bloc.dart';
import 'package:flatch/blocs/email_not_verified/email_not_verified_bloc.dart';
import 'package:flatch/blocs/fetch_farts/fetch_farts_bloc.dart';
import 'package:flatch/blocs/forgot_password/forgot_password_bloc.dart';
import 'package:flatch/blocs/individual_signup/individual_signup_bloc.dart';
import 'package:flatch/blocs/login_bloc/login_bloc.dart';
import 'package:flatch/blocs/my_uploads/my_uploads_bloc.dart';
import 'package:flatch/blocs/student_profile_managment/profile_managment_bloc.dart';
import 'package:flatch/blocs/update_username/updateusername_bloc.dart';
import 'package:flatch/blocs/upload_fart/upload_fart_bloc.dart';
import 'package:flatch/blocs/user_details/user_details_bloc.dart';
import 'package:flatch/common/app_helpers/theme_helper.dart';
import 'package:flatch/common/routes/app_routes.dart';
import 'package:flatch/common/styles/app_styles.dart';
import 'package:flatch/cubits/Individual_signup/individual_signup_cubit.dart';
import 'package:flatch/cubits/audio_trim/audio_trim_cubit.dart';
import 'package:flatch/cubits/upload_draft/upload_draft_cubit.dart';
import 'package:flatch/cubits/delete_user_account/delete_user_account_cubit.dart';
import 'package:flatch/cubits/fetch_farts/fetch_farts_cubit.dart';
import 'package:flatch/cubits/flatch_ble/flatch_ble_cubit.dart';
import 'package:flatch/cubits/login/company_login_cubit.dart';
import 'package:flatch/cubits/user_app_dashboard/user_app_dashboard_cubit.dart';
import 'package:flatch/cubits/user_app_update_password/user_app_update_password_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:toastification/toastification.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<IndividualSignupBloc>(
          create: (context) => IndividualSignupBloc(),
        ),
        BlocProvider<IndividualSignupCubit>(
          create: (context) => IndividualSignupCubit(),
        ),
        BlocProvider<UploadFartBloc>(create: (context) => UploadFartBloc()),
        BlocProvider<FetchFartsBloc>(create: (context) => FetchFartsBloc()),
        BlocProvider<MyUploadsBloc>(create: (context) => MyUploadsBloc()),

        BlocProvider<LoginBloc>(create: (context) => LoginBloc()),
        BlocProvider<LoginCubit>(create: (context) => LoginCubit()),

        BlocProvider<ForgotPasswordBloc>(
          create: (context) => ForgotPasswordBloc(),
        ),

        BlocProvider<EmailNotVerifiedBloc>(
          create: (context) => EmailNotVerifiedBloc(),
        ),
        BlocProvider<UserAppDashboardCubit>(
          create: (context) => UserAppDashboardCubit(),
        ),

        BlocProvider<ProfileManagmentBloc>(
          create: (context) => ProfileManagmentBloc(),
        ),

        BlocProvider<DashboardBloc>(create: (context) => DashboardBloc()),

        BlocProvider<UpdateusernameBloc>(
          create: (context) => UpdateusernameBloc(),
        ),
        BlocProvider<UserAppUpdatePasswordCubit>(
          create: (context) => UserAppUpdatePasswordCubit(),
        ),

        BlocProvider<DeleteMyAccountBloc>(
          create: (context) => DeleteMyAccountBloc(),
        ),

        BlocProvider<FlatchBleCubit>(create: (context) => FlatchBleCubit()),
        BlocProvider<FetchFartsCubit>(create: (context) => FetchFartsCubit()),

        BlocProvider<DeleteUserAccountCubit>(
          create: (context) => DeleteUserAccountCubit(),
        ),
        BlocProvider<AppCheckVersionCubit>(
          create: (context) => AppCheckVersionCubit(),
        ),
        BlocProvider<AudioTrimCubit>(create: (context) => AudioTrimCubit()),
        BlocProvider<UploadDraftCubit>(create: (context) => UploadDraftCubit()),
        BlocProvider<UserDetailsBloc>(create: (context) => UserDetailsBloc()),
        BlocProvider<AdminFartsBloc>(create: (context) => AdminFartsBloc()),
        BlocProvider<AdminUsersBloc>(create: (context) => AdminUsersBloc()),
      ],
      child: ToastificationWrapper(
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: ThemeController.themeMode,
          builder: (context, themeMode, _) {
            return MaterialApp.router(
              routerConfig: AppRoutes.router,
              debugShowCheckedModeBanner: false,
              title: 'Flatch',
              theme: AppStyles.light,
              darkTheme: AppStyles.dark,
              themeMode: themeMode,
              builder: (context, child) {
                // Respect the OS font-size setting but clamp it so the layout
                // stays intact (was fully disabled via TextScaler.noScaling,
                // an accessibility regression + App Store review risk).
                final scale =
                    MediaQuery.textScalerOf(
                      context,
                    ).scale(1.0).clamp(0.9, 1.2).toDouble();
                return MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                );
              },
            );
          },
        ),
      ),
    );
  }
}
