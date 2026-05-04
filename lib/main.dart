import 'dart:ui';
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
  runApp(AgrismartApp(settings: settings));
}

class AgrismartApp extends StatelessWidget {
  final AppSettings settings;
  const AgrismartApp({super.key, required this.settings});

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
            '/home': (context) => const MainShell(),
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

String _roleBadgeLabel(String role, AppSettings s) {
  switch (role) {
    case 'admin': return s.tr('role_admin');
    case 'vet': return s.tr('role_vet');
    case 'agronomist': return s.tr('role_agronomist');
    case 'breeder': return s.tr('role_breeder');
    default: return s.tr('role_farmer');
  }
}

Color _roleColor(String role) {
  switch (role) {
    case 'admin': return Colors.purple;
    case 'vet': return Colors.blue;
    case 'agronomist': return Colors.teal;
    case 'breeder': return Colors.orange;
    default: return AppTheme.greenPrimary;
  }
}

// ─────────────────────────────────────────────────────────────
// MainShell
// ─────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

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

    return Scaffold(
      extendBody: true,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titles[_index],
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: _roleColor(role).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _roleBadgeLabel(role, settings),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _roleColor(role)),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
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

          // ✅ Assistant IA — bas DROITE
          const Positioned(
            right: 16,
            bottom: 100,
            child: ChatbotWidget(),
          ),

          // ✅ Caméra plante — bas GAUCHE (séparé de l'assistant)
          Positioned(
            left: 16,
            bottom: 100,
            child: PlantCameraWidget(userId: currentUser?.id ?? 1),
          ),
        ],
      ),
      bottomNavigationBar:
          _buildGlassNav(pages, titles, icons),
    );
  }

  Widget _buildGlassNav(
      List<Widget> pages, List<String> titles, List<IconData> icons) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5), width: 1.5),
            ),
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(
                    pages.length,
                    (i) => _buildNavItem(i, titles[i], icons[i]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int i, String title, IconData icon) {
    final isSelected = _index == i;
    return GestureDetector(
      onTap: () {
        setState(() => _index = i);
        _fabController.forward(from: 0);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 16 : 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF34C759), Color(0xFF30D158)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: AppTheme.greenPrimary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: isSelected
                    ? Colors.white
                    : AppTheme.greenDark.withValues(alpha: 0.5),
                size: 24),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(title,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: -0.3)),
            ],
          ],
        ),
      ),
    );
  }
}