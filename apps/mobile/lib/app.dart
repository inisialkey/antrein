import 'package:antrein/core/config/app_config.dart';
import 'package:antrein/core/di/injection.dart';
import 'package:antrein/core/router/app_router.dart';
import 'package:antrein/core/theme/app_theme.dart';
import 'package:antrein/core/ui/screen_config.dart';
import 'package:antrein/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:antrein/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Root widget. Product copy is Bahasa Indonesia (flutter-brief §20), so the
/// locale is pinned to `id`; `en` stays as the l10n template + fallback.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final config = getIt<AppConfig>();
    final appRouter = getIt<AppRouter>();
    return BlocProvider<AuthCubit>.value(
      // The router owns the one app-scoped AuthCubit; share that exact instance
      // with the tree (value provider does not close it).
      value: appRouter.authCubit,
      child: ScreenUtilInit(
        designSize: kDesignSize,
        minTextAdapt: true,
        splitScreenMode: true,
        builder: (context, child) => MaterialApp.router(
          title: config.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          locale: const Locale('id'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter.router,
        ),
      ),
    );
  }
}
