// routes.dart
import 'package:go_router/go_router.dart';
import 'package:store_app/main.dart';
import 'src/auth/login_screens/screen.dart';
import 'src/auth/shared/views/page_not_found_view.dart';
import 'src/home_page/home_screen.dart';

class ViewRouter {
  static final GoRouter loggedOutRouter = GoRouter(
    navigatorKey: globalNavigatorKey,
    routes: [GoRoute(path: '/', builder: (_, __) => const LoginScreen())],
    errorBuilder: (_, __) => const LoginScreen(),
  );

  static final GoRouter loggedInRouter = GoRouter(
    navigatorKey: globalNavigatorKey,
    // Use either initialLocation OR a redirect from '/', not both.
    initialLocation: HomeScreen.routePath,
    routes: [
      // If you keep initialLocation, let '/' render Home directly (no redirect)
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: HomeScreen.routePath, // '/home'
        name: HomeScreen.routeName,
        builder: (_, __) => const HomeScreen(),
      ),
      // add other routes here...
    ],
    errorBuilder: (_, __) => const PageNotFoundView(),
  );
}
