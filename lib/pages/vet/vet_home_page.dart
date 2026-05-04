import 'package:flutter/material.dart';
import 'dart:ui';
import '../../app/app_theme.dart';

class VetHomePage extends StatefulWidget {
  final Function(int)? onNavigate;
  const VetHomePage({super.key, this.onNavigate});

  @override
  State<VetHomePage> createState() => _VetHomePageState();
}

class _VetHomePageState extends State<VetHomePage>
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
            _buildSectionTitle('Agenda du jour'),
            const SizedBox(height: 14),
            _buildTodayAgenda(),
            const SizedBox(height: 28),
            _buildSectionTitle('Urgences actives'),
            const SizedBox(height: 14),
            _buildUrgencies(),
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
        Text('$greeting, Dr. 🩺',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w800,
                )),
        const SizedBox(height: 4),
        Text('Tableau de bord vétérinaire',
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
        'label': 'Consultations aujourd\'hui',
        'value': '8',
        'icon': Icons.medical_services_rounded,
        'color': Colors.blue,
        'sub': '3 restantes'
      },
      {
        'label': 'Animaux traités',
        'value': '24',
        'icon': Icons.healing_rounded,
        'color': Colors.green,
        'sub': 'Ce mois'
      },
      {
        'label': 'Vaccinations prévues',
        'value': '12',
        'icon': Icons.vaccines_rounded,
        'color': Colors.purple,
        'sub': 'Cette semaine'
      },
      {
        'label': 'Urgences',
        'value': '2',
        'icon': Icons.emergency_rounded,
        'color': Colors.red,
        'sub': 'En attente'
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
        'label': 'Nouvelle consultation',
        'icon': Icons.add_circle_rounded,
        'color': Colors.blue,
        'onTap': () => widget.onNavigate?.call(1),
      },
      {
        'label': 'Rédiger ordonnance',
        'icon': Icons.description_rounded,
        'color': Colors.purple,
        'onTap': () => _showPrescriptionDialog(),
      },
      {
        'label': 'Vaccination',
        'icon': Icons.vaccines_rounded,
        'color': Colors.green,
        'onTap': () => _showVaccinationDialog(),
      },
      {
        'label': 'Alertes santé',
        'icon': Icons.health_and_safety_rounded,
        'color': Colors.red,
        'onTap': () => widget.onNavigate?.call(1),
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

  Widget _buildTodayAgenda() {
    final appointments = [
      {'time': '08:30', 'animal': 'Vache #002', 'owner': 'Ferme Ben Ali', 'type': 'Contrôle', 'done': true},
      {'time': '10:00', 'animal': 'Troupeau ovin', 'owner': 'Ferme Maatoug', 'type': 'Vaccination', 'done': true},
      {'time': '14:00', 'animal': 'Cheval #007', 'owner': 'Haras El Hana', 'type': 'Chirurgie', 'done': false},
      {'time': '16:30', 'animal': 'Brebis #015', 'owner': 'Ferme Ben Ali', 'type': 'Suivi', 'done': false},
    ];

    return Column(
      children: appointments.map((apt) {
        final done = apt['done'] as bool;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: done
                ? Colors.grey.withValues(alpha: 0.05)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: done
                    ? Colors.grey.withValues(alpha: 0.2)
                    : Colors.blue.withValues(alpha: 0.2)),
            boxShadow: done
                ? null
                : [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3))
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: done
                      ? Colors.grey.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(apt['time'] as String,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: done ? Colors.grey : Colors.blue)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(apt['animal'] as String,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: done ? Colors.grey : Colors.black87)),
                    Text('${apt['owner']} • ${apt['type']}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              if (done)
                const Icon(Icons.check_circle_rounded,
                    color: Colors.green, size: 20)
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('À venir',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildUrgencies() {
    final urgencies = [
      {
        'animal': 'Taureau #003',
        'farm': 'Ferme Chaouachi',
        'symptom': 'Fièvre élevée + refus d\'alimentation',
        'since': 'Il y a 2h',
        'level': 'urgent',
      },
      {
        'animal': 'Vache #018',
        'farm': 'Ferme Ben Salem',
        'symptom': 'Difficulté respiratoire',
        'since': 'Il y a 4h',
        'level': 'warning',
      },
    ];

    return Column(
      children: urgencies.map((u) {
        final isUrgent = u['level'] == 'urgent';
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
                      ? Icons.emergency_rounded
                      : Icons.warning_amber_rounded,
                  color: color,
                  size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${u['animal']} — ${u['farm']}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13)),
                    Text(u['symptom'] as String,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700)),
                    Text(u['since'] as String,
                        style: TextStyle(
                            fontSize: 10, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => widget.onNavigate?.call(1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Intervenir', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showPrescriptionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rédiger une ordonnance'),
        content:
            const Text('Module ordonnance disponible dans la prochaine version.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
        ],
      ),
    );
  }

  void _showVaccinationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planifier une vaccination'),
        content: const Text(
            'Module vaccination disponible dans la prochaine version.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer')),
        ],
      ),
    );
  }
}
