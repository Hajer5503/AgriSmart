import 'package:flutter/material.dart';
import 'dart:ui';
import '../../app/app_theme.dart';

class AgronomistHomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  const AgronomistHomePage({super.key, this.onNavigate});

  @override
  State<AgronomistHomePage> createState() => _AgronomistHomePageState();
}

class _AgronomistHomePageState extends State<AgronomistHomePage>
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
    return SafeArea(
      child: FadeTransition(
        opacity: _fade,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildStatsGrid(),
            const SizedBox(height: 28),
            _buildSectionTitle('Actions rapides'),
            const SizedBox(height: 14),
            _buildQuickActions(),
            const SizedBox(height: 28),
            _buildSectionTitle('Dernières analyses'),
            const SizedBox(height: 14),
            _buildRecentAnalyses(),
            const SizedBox(height: 28),
            _buildSectionTitle('Alertes agronomiques'),
            const SizedBox(height: 14),
            _buildAgroAlerts(),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final now = DateTime.now();
    final greeting = now.hour < 12
        ? 'Bonjour'
        : now.hour < 18
            ? 'Bon après-midi'
            : 'Bonsoir';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$greeting, Agronome 🔬',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.teal.shade800,
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 4),
        Text('Tableau de bord agronomique',
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'label': 'Parcelles actives',
        'value': '18',
        'icon': Icons.grass_rounded,
        'color': Colors.teal,
        'sub': '3 en surveillance'
      },
      {
        'label': 'Analyses terrain',
        'value': '34',
        'icon': Icons.science_rounded,
        'color': Colors.indigo,
        'sub': 'Ce mois'
      },
      {
        'label': 'Maladies détectées',
        'value': '6',
        'icon': Icons.bug_report_rounded,
        'color': Colors.red,
        'sub': '2 actives'
      },
      {
        'label': 'Rendement prévu',
        'value': '+12%',
        'icon': Icons.trending_up_rounded,
        'color': Colors.green,
        'sub': 'vs saison passée'
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
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700),
                      maxLines: 2),
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

  Widget _buildQuickActions() {
    final actions = [
      {
        'label': 'Nouvelle analyse',
        'icon': Icons.science_rounded,
        'color': Colors.indigo,
        'onTap': () => widget.onNavigate?.call(2),
      },
      {
        'label': 'Voir parcelles',
        'icon': Icons.grass_rounded,
        'color': Colors.teal,
        'onTap': () => widget.onNavigate?.call(1),
      },
      {
        'label': 'Météo & irrigation',
        'icon': Icons.water_drop_rounded,
        'color': Colors.blue,
        'onTap': () => _showWeatherDialog(),
      },
      {
        'label': 'Rapport culture',
        'icon': Icons.bar_chart_rounded,
        'color': Colors.green,
        'onTap': () => _showReportDialog(),
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
                          color:
                              (a['color'] as Color).withValues(alpha: 0.25)),
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

  Widget _buildRecentAnalyses() {
    final analyses = [
      {
        'parcel': 'Parcelle A-03',
        'type': 'Sol',
        'result': 'pH 6.8 — Optimal',
        'date': '2026-04-30',
        'status': 'ok',
      },
      {
        'parcel': 'Parcelle B-07',
        'type': 'Feuillage',
        'result': 'Carence en azote détectée',
        'date': '2026-04-28',
        'status': 'warning',
      },
      {
        'parcel': 'Parcelle C-01',
        'type': 'Eau d\'irrigation',
        'result': 'Taux de salinité élevé',
        'date': '2026-04-25',
        'status': 'alert',
      },
    ];

    return Column(
      children: analyses.map((a) {
        final statusColor = a['status'] == 'ok'
            ? Colors.green
            : a['status'] == 'warning'
                ? Colors.orange
                : Colors.red;
        final statusIcon = a['status'] == 'ok'
            ? Icons.check_circle_rounded
            : a['status'] == 'warning'
                ? Icons.warning_amber_rounded
                : Icons.error_rounded;

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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.science_rounded,
                    color: Colors.teal, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['parcel']!,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                    Text('${a['type']} — ${a['result']}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                        maxLines: 2),
                    Text(a['date']!,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade400)),
                  ],
                ),
              ),
              Icon(statusIcon, color: statusColor, size: 22),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAgroAlerts() {
    final alerts = [
      {
        'title': 'Stress hydrique',
        'parcel': 'Parcelles B-07, B-08',
        'detail': 'Déficit pluviométrique de 30% sur 15 jours',
        'level': 'warning',
      },
      {
        'title': 'Risque mildiou',
        'parcel': 'Parcelle C-01',
        'detail': 'Conditions humides favorables aux champignons',
        'level': 'urgent',
      },
    ];

    return Column(
      children: alerts.map((alert) {
        final isUrgent = alert['level'] == 'urgent';
        final color = isUrgent ? Colors.red : Colors.orange;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(
                  isUrgent
                      ? Icons.warning_rounded
                      : Icons.info_outline_rounded,
                  color: color,
                  size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(alert['title']!,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: color)),
                    Text(alert['parcel']!,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600)),
                    Text(alert['detail']!,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => widget.onNavigate?.call(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Voir', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showWeatherDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Météo & Irrigation'),
        content:
            const Text('Module météo disponible dans la prochaine version.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rapport de culture'),
        content:
            const Text('Module rapport disponible dans la prochaine version.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
        ],
      ),
    );
  }
}
