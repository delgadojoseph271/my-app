// app.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'features/auth/presentation/auth_bloc.dart';

import 'core/router/app_router.dart';
import 'core/di/injection.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [BlocProvider(create: (_) => sl<AuthBloc>())],
      child: MaterialApp.router(
        title: 'My app',
        routerConfig: appRouter,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
