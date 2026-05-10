import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'services/auth_service.dart';
import 'services/app_settings.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'pages/profile_page.dart';

import 'pages/home_page.dart';
import 'pages/parcels_page.dart';
import 'pages/alerts_page.dart';
import 'pages/tasks_page.dart';

import 'pages/breeder/breeder_home_page.dart';
import 'pages/breeder/livestock_page.dart';
import 'pages/vet/vet_home_page.dart';
import 'pages/vet/consultations_page.dart';
import 'pages/agronomist/agronomist_home_page.dart';
import 'pages/agronomist/analyses_page.dart';

import 'widgets/chatbot_widget.dart';
import 'widgets/plant_camera_widget.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  List<CameraDescription> cameras = const [];
  try {
    cameras = await availableCameras();
  } catch (e, st) {
    debugPrint('availableCameras: $e\n$st');
  }
  runApp(AgrismartApp(settings: settings, cameras: cameras));
}

class AgrismartApp extends StatelessWidget {
  final AppSettings settings;
  final List<CameraDescription> cameras;

  const AgrismartApp({
    super.key,
    required this.settings,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
      ],
      child: Consumer<AppSettings>(
        builder: (context, appSettings, _) => MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Agrismart',
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: appSettings.themeMode,
          locale: appSettings.locale,
          supportedLocales: const [
            Locale('fr'),
            Locale('ar'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          initialRoute: '/',
          routes: {
            '/': (context) => const AuthCheckScreen(),
            '/login': (context) => const LoginScreen(),
            '/register': (context) => const RegisterScreen(),
            '/home': (context) => MainShell(cameras: cameras),
          },
        ),
      ),
    );
  }
}

class AuthCheckScreen extends StatefulWidget {
  const AuthCheckScreen({super.key});
  @override
  State<AuthCheckScreen> createState() => _AuthCheckScreenState();
}

class _AuthCheckScreenState extends State<AuthCheckScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = await authService.getCurrentUser();
    if (mounted) {
      Navigator.of(context)
          .pushReplacementNamed(user != null ? '/home' : '/login');
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// ─────────────────────────────────────────────────────────────
// Config de navigation par rôle
// ─────────────────────────────────────────────────────────────
Map<String, dynamic> _navConfigForRole(String role, AppSettings s) {
  switch (role) {
    case 'admin':
      return {
        'pages': const [HomePage(), ParcelsPage(), AlertsPage(), TasksPage()],
        'titles': [s.tr('nav_dashboard'), s.tr('nav_farms'), s.tr('nav_alerts'), s.tr('nav_tasks')],
        'icons': const [
          Icons.dashboard_rounded,
          Icons.map_rounded,
          Icons.notifications_rounded,
          Icons.check_circle_rounded,
        ],
      };
    case 'vet':
      return {
        'pages': const [VetHomePage(), ConsultationsPage(), AlertsPage(), TasksPage()],
        'titles': [s.tr('nav_accueil'), s.tr('nav_consultations'), s.tr('nav_alerts'), s.tr('nav_tasks')],
        'icons': const [
          Icons.home_rounded,
          Icons.medical_services_rounded,
          Icons.health_and_safety_rounded,
          Icons.check_circle_rounded,
        ],
      };
    case 'agronomist':
      return {
        'pages': const [AgronomistHomePage(), ParcelsPage(), AnalysesPage(), TasksPage()],
        'titles': [s.tr('nav_accueil'), s.tr('nav_parcels'), s.tr('nav_analyses'), s.tr('nav_tasks')],
        'icons': const [
          Icons.home_rounded,
          Icons.grass_rounded,
          Icons.science_rounded,
          Icons.check_circle_rounded,
        ],
      };
    case 'breeder':
      return {
        'pages': const [BreederHomePage(), LivestockPage(), AlertsPage(), TasksPage()],
        'titles': [s.tr('nav_accueil'), s.tr('nav_livestock'), s.tr('nav_alerts'), s.tr('nav_tasks')],
        'icons': const [
          Icons.home_rounded,
          Icons.pets_rounded,
          Icons.warning_amber_rounded,
          Icons.check_circle_rounded,
        ],
      };
    default: // farmer
      return {
        'pages': const [HomePage(), ParcelsPage(), AlertsPage(), TasksPage()],
        'titles': [s.tr('nav_home'), s.tr('nav_parcels'), s.tr('nav_alerts'), s.tr('nav_tasks')],
        'icons': const [
          Icons.home_rounded,
          Icons.map_rounded,
          Icons.notifications_rounded,
          Icons.check_circle_rounded,
        ],
      };
  }
}

// ─────────────────────────────────────────────────────────────
// MainShell
// ─────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MainShell({super.key, required this.cameras});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final settings = context.watch<AppSettings>();
    final currentUser = authService.currentUser;
    final role = currentUser?.role ?? 'farmer';

    final config = _navConfigForRole(role, settings);
    final titles = config['titles'] as List<String>;
    final icons  = config['icons']  as List<IconData>;

    void navigateTo(int i) => setState(() => _index = i);
    final rawPages = config['pages'] as List<Widget>;
    final pages = rawPages.map((p) {
      if (p is HomePage) return HomePage(onNavigate: navigateTo);
      if (p is BreederHomePage) return BreederHomePage(onNavigate: navigateTo);
      if (p is VetHomePage) return VetHomePage(onNavigate: navigateTo);
      if (p is AgronomistHomePage) return AgronomistHomePage(onNavigate: navigateTo);
      return p;
    }).toList();

    if (_index >= pages.length) _index = 0;

    final bottomFab = 16.0 + MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBody: false,
      drawer: _buildDrawer(context, pages, titles, icons),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF34C759), Color(0xFF30D158)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.greenPrimary.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child:
                  const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                titles[_index],
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: AppTheme.glassSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassBorder, width: 1),
            ),
            child: PlantCameraWidget(
              appBarStyle: true,
              userId: currentUser?.id ?? 1,
              cameras: widget.cameras,
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: AppTheme.glassSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.glassBorder, width: 1),
            ),
            child: IconButton(
              icon: const Icon(Icons.person_rounded),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Pages
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                        begin: const Offset(0.05, 0), end: Offset.zero)
                    .animate(animation),
                child: child,
              ),
            ),
            child: Container(key: ValueKey<int>(_index), child: pages[_index]),
          ),

          // Assistant — bas droite
          Positioned(
            right: 16,
            bottom: bottomFab,
            child: const ChatbotWidget(),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    List<Widget> pages,
    List<String> titles,
    List<IconData> icons,
  ) {
    final user = context.watch<AuthService>().currentUser;

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF34C759), Color(0xFF30D158)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.eco_rounded, color: Colors.white, size: 28),
                  ),
                  const Spacer(),
                  const Text(
                    'AgriSmart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    user != null
                        ? (user.name.isNotEmpty ? user.name : user.email)
                        : 'AgriSmart',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                'Navigation',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.greenDark.withValues(alpha: 0.45),
                  letterSpacing: 0.4,
                ),
              ),
            ),
            ...List.generate(pages.length, (i) {
              final sel = _index == i;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  leading: Icon(
                    icons[i],
                    color: sel
                        ? AppTheme.greenPrimary
                        : AppTheme.greenDark.withValues(alpha: 0.45),
                  ),
                  title: Text(
                    titles[i],
                    style: TextStyle(
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                      color: sel ? AppTheme.greenDark : null,
                    ),
                  ),
                  selected: sel,
                  selectedTileColor: AppTheme.greenPrimary.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onTap: () {
                    setState(() => _index = i);
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Divider(height: 32),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: ListTile(
                leading: Icon(Icons.logout_rounded, color: AppTheme.greenDark.withValues(alpha: 0.75)),
                title: const Text('Déconnexion'),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onTap: () async {
                  Navigator.pop(context);
                  await Provider.of<AuthService>(context, listen: false).logout();
                  if (!context.mounted) return;
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}