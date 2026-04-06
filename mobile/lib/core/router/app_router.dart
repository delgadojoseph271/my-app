import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
  ],
);
