import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import 'l10n/app_localizations.dart';
import 'src/auth/controllers/auth_controller.dart';
import 'src/auth/shared/providers/token_provider.dart';
import 'src/auth/shared/repositories/shared_preference_repository.dart';
import 'src/auth/shared/providers/theme_provider.dart';
import 'src/auth/shared/views/error_view.dart';
import 'src/auth/shared/views/loading_view.dart';
import 'src/components/constants.dart';
import 'src/components/socket_manager.dart';
import 'src/components/web_socket_seperate.dart';
import 'src/components/motion_widgets.dart';

final globalNavigatorKey = GlobalKey<NavigatorState>();
String currentVersion = '2.2.5';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: Do NOT call setPathUrlStrategy() multiple times.
  // If you need pretty URLs, set it ONCE here (commented to prefer hash and avoid listener bugs):
  // if (kIsWeb) setUrlStrategy(PathUrlStrategy());

  HttpOverrides.global = MyHttpOverrides();
  runApp(const ProviderScope(child: RRApp()));
}

// Bypass self-signed SSL (your original):
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final httpClient = super.createHttpClient(context);
    httpClient.badCertificateCallback =
        (X509Certificate cert, String host, int port) => true;
    return httpClient;
  }
}

class RRApp extends ConsumerStatefulWidget {
  const RRApp({super.key});
  @override
  ConsumerState<RRApp> createState() => _RRAppState();
}

class _RRAppState extends ConsumerState<RRApp> {
  final Locale _locale = const Locale('en');

  // Reuse singletons – do NOT recreate per build:
  late final GoRouter _loggedIn = ViewRouter.loggedInRouter;
  late final GoRouter _loggedOut = ViewRouter.loggedOutRouter;

  // Flutter 3.29+: stream now emits List<ConnectivityResult>
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool isConnected = true;

  void _showConnectivitySnackBar(bool connected) {
    final message =
        connected ? "Connected to the internet" : "No internet connection";
    final color = connected ? Colors.green : Colors.red;
    final ctx = globalNavigatorKey.currentContext;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Align(alignment: Alignment.center, child: Text(message)),
          backgroundColor: color,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _listenToConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      final result =
          results.isNotEmpty ? results.first : ConnectivityResult.none;
      final connected = result != ConnectivityResult.none;
      if (connected != isConnected) {
        setState(() => isConnected = connected);
        _showConnectivitySnackBar(connected);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ref.read(spRepositoryProvider).getStringValue("authToken").then((token) {
      if (mounted && token.isNotEmpty) {
        ref.read(authTokenProvider.notifier).updateToken(token);
      }
    });

    ref.read(spRepositoryProvider).getStringValue("theme").then((value) {
      if (mounted && value.isNotEmpty) {
        final index = int.tryParse(value);
        if (index != null && index >= 0 && index < Constants.themeDataList.length) {
          ref
              .read(themeDataProvider.notifier)
              .setTheme(Constants.themeDataList[index]);
        }
      }
    });

    // sockets / connectivity (as you had)
    ref.read(socketProvider).getSocket();
    _listenToConnectivity();
    ref.read(webSocketStateProvider.notifier).initSocketConnection();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // do NOT mutate providers here (no then(...) setting theme)

    // it's fine to watch socket state if needed

    ref.watch(webSocketStateProvider);

    final authStateAsync = ref.watch(authStateChangesProvider);

    return authStateAsync.when(
      data: (user) {
        final router = user != null ? _loggedIn : _loggedOut;
        return MaterialApp.router(
          // No need to swap a new key each time if router instance is stable
          // key: ValueKey(user != null),
          debugShowCheckedModeBanner: false,
          locale: _locale,
          supportedLocales: const [Locale('en'), Locale('hi')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          title: 'RR Ispat',
          theme: ref.watch(themeDataProvider),
          scrollBehavior: const AppBouncingScrollBehavior(),
          builder: (context, child) => child ?? const SizedBox.shrink(),
          routerConfig: router,
        );
      },
      error:
          (e, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            navigatorKey: globalNavigatorKey,
            home: ErrorPage(error: e.toString()),
          ),
      loading:
          () => const MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LoadingView(),
          ),
    );
  }
}
