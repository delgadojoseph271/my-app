import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'splash_bloc.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => context.read<SplashBloc>()
        ..add(LoadSplashsRequested()),
      child: const _SplashView(),
    );
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Splash')),
      body: BlocBuilder<SplashBloc, SplashState>(
        builder: (context, state) {
          if (state is SplashLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SplashError) {
            return Center(child: Text('Error: ${state.message}'));
          }
          if (state is SplashsLoaded) {
            return ListView.builder(
              itemCount: state.items.length,
              itemBuilder: (context, index) {
                final item = state.items[index];
                return ListTile(title: Text('ID: ${item.id}'));
              },
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
