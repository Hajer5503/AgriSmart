import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/app_settings.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final settings = context.watch<AppSettings>();
    final user = authService.currentUser;
    final isDark = settings.isDark;

    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF5FFF7);
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFD0F0D8);
    final textColor = isDark ? const Color(0xFFE6EDF3) : const Color(0xFF1C1C1E);
    final subColor = isDark ? const Color(0xFF8B949E) : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF161B22) : const Color(0xFFFAFFFB),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded, color: textColor, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(settings.tr('profile_title'),
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700, color: textColor)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(user, isDark, textColor, settings),
            const SizedBox(height: 28),
            _buildSection(
              context,
              title: settings.tr('profile_info'),
              icon: Icons.person_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              subColor: subColor,
              children: [
                _infoRow(Icons.badge_rounded, settings.tr('profile_name'), user?.name ?? '—', textColor, subColor, borderColor, isDark),
                _infoRow(Icons.email_rounded, settings.tr('profile_email'), user?.email ?? '—', textColor, subColor, borderColor, isDark),
                _infoRow(Icons.phone_rounded, settings.tr('profile_phone'), user?.phone?.isNotEmpty == true ? user!.phone! : '—', textColor, subColor, borderColor, isDark),
                _infoRow(Icons.verified_user_rounded, settings.tr('profile_role'), _roleLabel(user?.role ?? 'farmer', settings), textColor, subColor, borderColor, isDark, isLast: true),
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              title: settings.tr('profile_language'),
              icon: Icons.language_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              subColor: subColor,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      _langChip(context, settings, 'fr', '🇫🇷', 'Français'),
                      const SizedBox(width: 10),
                      _langChip(context, settings, 'ar', '🇸🇦', 'العربية'),
                      const SizedBox(width: 10),
                      _langChip(context, settings, 'en', '🇬🇧', 'English'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSection(
              context,
              title: settings.tr('profile_theme'),
              icon: Icons.palette_rounded,
              cardColor: cardColor,
              borderColor: borderColor,
              textColor: textColor,
              subColor: subColor,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      _themeOption(context, settings, ThemeMode.light,
                          Icons.wb_sunny_rounded, settings.tr('profile_light'), textColor, subColor, borderColor, isDark),
                      const SizedBox(width: 12),
                      _themeOption(context, settings, ThemeMode.dark,
                          Icons.nightlight_rounded, settings.tr('profile_dark'), textColor, subColor, borderColor, isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 36),
            _buildLogoutButton(context, authService, settings),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(dynamic user, bool isDark, Color textColor, AppSettings settings) {
    final name = user?.name ?? '?';
    final initials = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0].toUpperCase() : '').join();
    final role = user?.role ?? 'farmer';

    return Center(
      child: Column(
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_roleColor(role), _roleColor(role).withValues(alpha: 0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: _roleColor(role).withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 14),
          Text(name,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: textColor)),
          const SizedBox(height: 6),
          Text(user?.email ?? '',
              style: TextStyle(fontSize: 14, color: textColor.withValues(alpha: 0.6))),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: _roleColor(role).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _roleColor(role).withValues(alpha: 0.3)),
            ),
            child: Text(_roleLabel(role, settings),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _roleColor(role))),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color subColor,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(icon, size: 16, color: subColor),
          const SizedBox(width: 6),
          Text(title.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: subColor,
                  letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      Color textColor, Color subColor, Color borderColor, bool isDark,
      {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 18, color: subColor),
              const SizedBox(width: 12),
              Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor)),
              const Spacer(),
              Text(value,
                  style: TextStyle(fontSize: 14, color: subColor)),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: borderColor),
      ],
    );
  }

  Widget _langChip(BuildContext context, AppSettings settings,
      String code, String flag, String label) {
    final isSelected = settings.locale.languageCode == code;
    final color = isSelected ? const Color(0xFF34C759) : Colors.transparent;
    final isDark = settings.isDark;

    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setLocale(Locale(code)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF34C759).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1C2128) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? color
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0)),
                width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Text(flag, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF34C759)
                          : (isDark ? const Color(0xFF8B949E) : Colors.grey.shade700))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _themeOption(
      BuildContext context,
      AppSettings settings,
      ThemeMode mode,
      IconData icon,
      String label,
      Color textColor,
      Color subColor,
      Color borderColor,
      bool isDark) {
    final isSelected = settings.themeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => settings.setThemeMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF34C759).withValues(alpha: 0.15)
                : (isDark ? const Color(0xFF1C2128) : const Color(0xFFF5F5F5)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF34C759)
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE0E0E0)),
                width: isSelected ? 2 : 1),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 26,
                  color: isSelected
                      ? const Color(0xFF34C759)
                      : subColor),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? const Color(0xFF34C759)
                          : subColor)),
              if (isSelected) ...[
                const SizedBox(height: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFF34C759), shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, AuthService authService, AppSettings settings) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(settings.tr('profile_logout_title')),
              content: Text(settings.tr('profile_logout_confirm')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(settings.tr('profile_cancel'))),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.red),
                    child: Text(settings.tr('profile_confirm_logout'))),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await authService.logout();
            if (context.mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                  '/login', (route) => false);
            }
          }
        },
        icon: const Icon(Icons.logout_rounded, size: 22),
        label: Text(settings.tr('profile_logout'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF3B30),
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }

  String _roleLabel(String role, AppSettings settings) {
    switch (role) {
      case 'vet': return settings.tr('role_vet');
      case 'agronomist': return settings.tr('role_agronomist');
      case 'breeder': return settings.tr('role_breeder');
      case 'admin': return settings.tr('role_admin');
      default: return settings.tr('role_farmer');
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'vet': return Colors.blue;
      case 'agronomist': return Colors.teal;
      case 'breeder': return Colors.orange;
      case 'admin': return Colors.purple;
      default: return const Color(0xFF34C759);
    }
  }
}
