import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/app_theme.dart';
import '../services/alert_service.dart';
import '../services/auth_service.dart';
import 'dart:ui';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> with TickerProviderStateMixin {
  late AnimationController _animationController;
  String _selectedFilter = 'Toutes';

  final AlertService _alertService = AlertService();
  List<Alert> _alerts = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
    _loadAlerts();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAlerts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isLoading = false;
          _error = 'Utilisateur non connecté';
        });
        return;
      }
      final alerts = await _alertService.getAlerts(userId);
      setState(() {
        _alerts = alerts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Erreur de chargement des alertes';
      });
    }
  }

  Future<void> _markAsRead(Alert alert) async {
    try {
      await _alertService.markAsRead(alert.id);
      await _loadAlerts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la mise à jour')),
      );
    }
  }

  // Convertit la sévérité BD → niveau affiché
  String _severityToLevel(String severity) {
    switch (severity) {
      case 'critical':
        return 'urgent';
      case 'high':
        return 'warning';
      case 'medium':
        return 'warning';
      default:
        return 'info';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'water_stress':
        return Icons.water_drop_rounded;
      case 'disease':
        return Icons.coronavirus_rounded;
      case 'temperature':
        return Icons.thermostat_rounded;
      case 'livestock':
        return Icons.pets_rounded;
      case 'weather':
        return Icons.cloud_rounded;
      case 'reservoir':
        return Icons.water_rounded;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  LinearGradient _gradientForSeverity(String severity) {
    switch (severity) {
      case 'critical':
        return const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'high':
        return const LinearGradient(
          colors: [Color(0xFFFA709A), Color(0xFFFEE140)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'medium':
        return const LinearGradient(
          colors: [Color(0xFFFEAC5E), Color(0xFFC779D0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      default:
        return const LinearGradient(
          colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'À l\'instant';
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
    return 'Il y a ${diff.inDays} jour(s)';
  }

  List<Alert> get _filteredAlerts {
    if (_selectedFilter == 'Toutes') return _alerts;
    return _alerts.where((a) {
      final level = _severityToLevel(a.severity);
      return level == _selectedFilter.toLowerCase();
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.all(20),
            child: _buildFilterChips(),
          ),

          // Stats summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStatsSummary(),
          ),

          const SizedBox(height: 20),

          // Corps principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildErrorState()
                    : _filteredAlerts.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadAlerts,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              itemCount: _filteredAlerts.length,
                              itemBuilder: (context, index) {
                                final alert = _filteredAlerts[index];

                                return TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 400 + (index * 80)),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  curve: Curves.easeOutBack,
                                  builder: (context, value, child) {
                                    return Transform.translate(
                                      offset: Offset(30 * (1 - value), 0),
                                      child: Opacity(
                                        opacity: value.clamp(0.0, 1.0),
                                        child: Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _AlertGlassCard(
                                            title: alert.type,
                                            description: alert.message,
                                            level: _severityToLevel(alert.severity),
                                            time: _formatTime(alert.createdAt),
                                            icon: _iconForType(alert.type),
                                            gradient: _gradientForSeverity(alert.severity),
                                            isRead: alert.isRead,
                                            onTap: () {
                                              _showAlertDetails(context, alert);
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['Toutes', 'Urgent', 'Warning', 'Info'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = filter),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF34C759), Color(0xFF30D158)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.5)
                        : AppTheme.glassBorder,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.greenPrimary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppTheme.greenDark,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsSummary() {
    final urgentCount =
        _alerts.where((a) => _severityToLevel(a.severity) == 'urgent').length;
    final warningCount =
        _alerts.where((a) => _severityToLevel(a.severity) == 'warning').length;
    final infoCount =
        _alerts.where((a) => _severityToLevel(a.severity) == 'info').length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            children: [
              Expanded(
                child: _StatItem(
                  label: 'Urgent',
                  count: urgentCount,
                  color: const Color(0xFFFF3B30),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Attention',
                  count: warningCount,
                  color: const Color(0xFFFF9500),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _StatItem(
                  label: 'Info',
                  count: infoCount,
                  color: const Color(0xFF4FACFE),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.greenPrimary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_rounded,
              size: 64,
              color: AppTheme.greenPrimary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Aucune alerte',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.greenDark,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'Toutes'
                ? 'Tout va bien, aucune alerte active'
                : 'Aucune alerte pour ce filtre',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.greenDark.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            label: const Text('Rafraîchir'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64,
              color: Colors.red.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(_error ?? 'Erreur inconnue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _loadAlerts,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showAlertDetails(BuildContext context, Alert alert) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AlertDetailsSheet(
        alert: alert,
        gradient: _gradientForSeverity(alert.severity),
        icon: _iconForType(alert.type),
        onMarkRead: alert.isRead ? null : () => _markAsRead(alert),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Widgets internes
// ─────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.9),
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _AlertGlassCard extends StatefulWidget {
  final String title;
  final String description;
  final String level;
  final String time;
  final IconData icon;
  final LinearGradient gradient;
  final bool isRead;
  final VoidCallback onTap;

  const _AlertGlassCard({
    required this.title,
    required this.description,
    required this.level,
    required this.time,
    required this.icon,
    required this.gradient,
    required this.isRead,
    required this.onTap,
  });

  @override
  State<_AlertGlassCard> createState() => _AlertGlassCardState();
}

class _AlertGlassCardState extends State<_AlertGlassCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Opacity(
          opacity: widget.isRead ? 0.6 : 1.0,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.gradient.colors.first.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      // Bande icône avec gradient
                      Container(
                        width: 70,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: widget.gradient,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          ),
                        ),
                        child: Icon(widget.icon, color: Colors.white, size: 32),
                      ),

                      // Contenu
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.title,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF1C1C1E),
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ),
                                  // Badge niveau
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      gradient: widget.gradient,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.level.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: const Color(0xFF3C3C43)
                                      .withValues(alpha: 0.7),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 14,
                                      color: const Color(0xFF3C3C43)
                                          .withValues(alpha: 0.5)),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.time,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: const Color(0xFF3C3C43)
                                          .withValues(alpha: 0.5),
                                    ),
                                  ),
                                  if (widget.isRead) ...[
                                    const Spacer(),
                                    Icon(Icons.check_circle_rounded,
                                        size: 16,
                                        color: AppTheme.greenPrimary
                                            .withValues(alpha: 0.6)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertDetailsSheet extends StatelessWidget {
  final Alert alert;
  final LinearGradient gradient;
  final IconData icon;
  final VoidCallback? onMarkRead;

  const _AlertDetailsSheet({
    required this.alert,
    required this.gradient,
    required this.icon,
    this.onMarkRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Icône
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: gradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Titre
              Text(
                alert.type,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Message
              Text(
                alert.message,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black.withValues(alpha: 0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Date
              Text(
                alert.createdAt.toLocal().toString().substring(0, 16),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 24),

              // Bouton marquer comme lue (seulement si pas encore lue)
              if (onMarkRead != null)
                FilledButton.icon(
                  onPressed: () {
                    onMarkRead!();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Marquer comme lue'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text('Déjà lue'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 54),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}