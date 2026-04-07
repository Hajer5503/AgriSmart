import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app/app_theme.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';

import 'pages/home_page.dart';
import 'pages/parcels_page.dart';
import 'pages/alerts_page.dart';
import 'pages/tasks_page.dart';

import 'widgets/chatbot_widget.dart';
import 'widgets/plant_camera_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AgrismartApp());
}

class AgrismartApp extends StatelessWidget {
  const AgrismartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [Provider<AuthService>(create: (_) => AuthService())],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Agrismart',
        theme: AppTheme.light(),
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthCheckScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const MainShell(),
        },
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
Map<String, dynamic> _navConfigForRole(String role) {
  switch (role) {
    case 'admin':
      return {
        'pages': const [HomePage(), ParcelsPage(), AlertsPage(), TasksPage()],
        'titles': const ['Dashboard', 'Fermes', 'Alertes', 'Tâches'],
        'icons': const [
          Icons.dashboard_rounded,
          Icons.map_rounded,
          Icons.notifications_rounded,
          Icons.check_circle_rounded,
        ],
      };
    case 'vet':
      return {
        'pages': const [HomePage(), AlertsPage(), TasksPage()],
        'titles': const ['Accueil', 'Alertes Santé', 'Tâches'],
        'icons': const [
          Icons.home_rounded,
          Icons.health_and_safety_rounded,
          Icons.check_circle_rounded,
        ],
      };
    case 'agronomist':
      return {
        'pages': const [HomePage(), ParcelsPage(), AlertsPage(), TasksPage()],
        'titles': const ['Accueil', 'Parcelles', 'Alertes', 'Tâches'],
        'icons': const [
          Icons.home_rounded,
          Icons.grass_rounded,
          Icons.notifications_rounded,
          Icons.check_circle_rounded,
        ],
      };
    case 'breeder':
      return {
        'pages': const [HomePage(), AlertsPage(), TasksPage()],
        'titles': const ['Accueil', 'Alertes Bétail', 'Tâches'],
        'icons': const [
          Icons.home_rounded,
          Icons.pets_rounded,
          Icons.check_circle_rounded,
        ],
      };
    default: // farmer
      return {
        'pages': const [HomePage(), ParcelsPage(), AlertsPage(), TasksPage()],
        'titles': const ['Agrismart', 'Parcelles', 'Alertes', 'Tâches'],
        'icons': const [
          Icons.home_rounded,
          Icons.map_rounded,
          Icons.notifications_rounded,
          Icons.check_circle_rounded,
        ],
      };
  }
}

String _roleBadgeLabel(String role) {
  switch (role) {
    case 'admin': return '⚙️ Administrateur';
    case 'vet': return '🩺 Vétérinaire';
    case 'agronomist': return '🌿 Agronome';
    case 'breeder': return '🐄 Éleveur';
    default: return '🌾 Agriculteur';
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
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final role = currentUser?.role ?? 'farmer';

    final config = _navConfigForRole(role);
    final pages = config['pages'] as List<Widget>;
    final titles = config['titles'] as List<String>;
    final icons = config['icons'] as List<IconData>;

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
                    _roleBadgeLabel(role),
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
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.person_rounded),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currentUser?.name ?? 'Utilisateur',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(currentUser?.email ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  onTap: () async {
                    await authService.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushReplacementNamed('/login');
                    }
                  },
                  child: const Row(children: [
                    Icon(Icons.logout_rounded, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Déconnexion',
                        style: TextStyle(color: Colors.red)),
                  ]),
                ),
              ],
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