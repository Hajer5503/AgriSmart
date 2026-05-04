import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../app/app_theme.dart';
import '../../services/app_settings.dart';

class BreederHomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  const BreederHomePage({super.key, this.onNavigate});

  @override
  State<BreederHomePage> createState() => _BreederHomePageState();
}

class _BreederHomePageState extends State<BreederHomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return SafeArea(
      child: FadeTransition(
        opacity: _fade,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildHeader(s),
            const SizedBox(height: 24),
            _buildStatsGrid(s),
            const SizedBox(height: 28),
            _buildSectionTitle(s.tr('home_quick_actions')),
            const SizedBox(height: 14),
            _buildQuickActions(s),
            const SizedBox(height: 28),
            _buildSectionTitle(s.tr('breeder_herd_state')),
            const SizedBox(height: 14),
            _buildAnimalList(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppSettings s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s.tr('breeder_greeting'),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 4),
        Text(s.tr('breeder_subtitle'),
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStatsGrid(AppSettings s) {
    final stats = [
      {
        'label': s.tr('breeder_total_animals'),
        'value': '142',
        'icon': Icons.pets_rounded,
        'color': Colors.orange,
        'sub': '+3 ce mois'
      },
      {
        'label': s.tr('breeder_healthy'),
        'value': '96%',
        'icon': Icons.favorite_rounded,
        'color': Colors.green,
        'sub': '136 animaux'
      },
      {
        'label': s.tr('breeder_active_alerts'),
        'value': '4',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.red,
        'sub': '2 urgentes'
      },
      {
        'label': s.tr('breeder_milk'),
        'value': '320L',
        'icon': Icons.water_drop_rounded,
        'color': Colors.blue,
        'sub': 'Aujourd\'hui'
      },
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: stats.map((s) => _buildStatCard(s)).toList(),
    );
  }

  Widget _buildStatCard(Map<String, dynamic> s) {
    final color = s['color'] as Color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(s['icon'] as IconData, color: color, size: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s['value'] as String,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: color)),
                  Text(s['label'] as String,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700)),
                  Text(s['sub'] as String,
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade500)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700, color: AppTheme.greenDark));
  }

  Widget _buildQuickActions(AppSettings s) {
    final actions = [
      {
        'label': s.tr('breeder_add_animal'),
        'icon': Icons.add_circle_rounded,
        'color': Colors.orange,
        'onTap': () => _showAddAnimalDialog(s),
      },
      {
        'label': s.tr('breeder_declare_disease'),
        'icon': Icons.medical_services_rounded,
        'color': Colors.red,
        'onTap': () => widget.onNavigate?.call(1),
      },
      {
        'label': s.tr('breeder_see_herd'),
        'icon': Icons.list_alt_rounded,
        'color': Colors.teal,
        'onTap': () => widget.onNavigate?.call(1),
      },
      {
        'label': s.tr('breeder_plan_task'),
        'icon': Icons.task_alt_rounded,
        'color': Colors.purple,
        'onTap': () => widget.onNavigate?.call(2),
      },
    ];

    return Row(
      children: actions
          .map((a) => Expanded(
                child: GestureDetector(
                  onTap: a['onTap'] as VoidCallback,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: (a['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: (a['color'] as Color).withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      children: [
                        Icon(a['icon'] as IconData,
                            color: a['color'] as Color, size: 26),
                        const SizedBox(height: 6),
                        Text(a['label'] as String,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildAnimalList() {
    final animals = [
      {'name': 'Vache #001', 'species': 'Bovin', 'status': 'sain', 'age': '4 ans', 'weight': '520 kg'},
      {'name': 'Vache #002', 'species': 'Bovin', 'status': 'alerte', 'age': '3 ans', 'weight': '480 kg'},
      {'name': 'Brebis #015', 'species': 'Ovin', 'status': 'sain', 'age': '2 ans', 'weight': '65 kg'},
      {'name': 'Taureau #003', 'species': 'Bovin', 'status': 'traitement', 'age': '5 ans', 'weight': '820 kg'},
    ];

    return Column(
      children: animals.map((a) => _buildAnimalCard(a)).toList(),
    );
  }

  Widget _buildAnimalCard(Map<String, String> a) {
    final statusColor = a['status'] == 'sain'
        ? Colors.green
        : a['status'] == 'alerte'
            ? Colors.red
            : Colors.orange;
    final statusLabel = a['status'] == 'sain'
        ? 'Sain'
        : a['status'] == 'alerte'
            ? 'Alerte'
            : 'En traitement';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.pets_rounded,
                color: Colors.orange, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['name']!,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${a['species']} • ${a['age']} • ${a['weight']}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }

  void _showAddAnimalDialog(AppSettings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.tr('breeder_add_animal_title')),
        content: Text(s.tr('breeder_add_animal_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.tr('breeder_close'))),
        ],
      ),
    );
  }
}
