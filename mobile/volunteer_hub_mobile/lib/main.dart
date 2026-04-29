import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/blog/blog_post_detail_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/home/home_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const VolunteerHubApp());
}

class VolunteerHubApp extends StatefulWidget {
  const VolunteerHubApp({super.key});

  @override
  State<VolunteerHubApp> createState() => _VolunteerHubAppState();
}

class _VolunteerHubAppState extends State<VolunteerHubApp> {
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  void _initDeepLinks() {
    // Handle links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle initial link (app launched from deep link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) _handleDeepLink(uri);
    });
  }

  /// Routes:
  ///   volunteerhub://blog/{id}
  ///   volunteerhub://events/{id}
  ///   volunteerhub://campaigns/{id}  OR  volunteerhub://donations/{id}
  void _handleDeepLink(Uri uri) {
    final segments = uri.pathSegments;
    if (segments.length < 2) return;

    final type = segments[0];
    final id = int.tryParse(segments[1]);
    if (id == null) return;

    final nav = navigatorKey.currentState;
    if (nav == null) return;

    switch (type) {
      case 'blog':
        nav.push(MaterialPageRoute(
          builder: (_) => BlogPostDetailScreen(postId: id),
        ));
        break;
      case 'events':
        nav.push(MaterialPageRoute(
          builder: (_) => EventDetailScreen(eventId: id),
        ));
        break;
      case 'campaigns':
      case 'donations':
        nav.push(MaterialPageRoute(
          builder: (_) => HomeScreen(initialTab: 3, initialCampaignId: id),
        ));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: 'VolunteerHub',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            navigatorKey: navigatorKey,
            home: auth.isAuthenticated
                ? const HomeScreen()
                : const LoginScreen(),
            routes: {
              '/login': (ctx) => const LoginScreen(),
              '/home': (ctx) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}
