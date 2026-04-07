import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import 'dart:ui';

// ─── Modèle local ───────────────────────────────────────────
class _Task {
  final String id;
  String title;
  String description;
  bool done;
  String priority; // high | medium | low
  String dueDate;
  String category;

  _Task({
    required this.id,
    required this.title,
    required this.description,
    this.done = false,
    required this.priority,
    required this.dueDate,
    required this.category,
  });
}

// ─── Page ───────────────────────────────────────────────────
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<_Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTask(_Task task) {
    setState(() => task.done = !task.done);
  }

  void _deleteTask(_Task task) {
    setState(() => _tasks.remove(task));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tâche "${task.title}" supprimée'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String selectedPriority = 'medium';
    String selectedCategory = 'Irrigation';
    DateTime selectedDate = DateTime.now();

    final categories = [
      'Irrigation', 'Traitement', 'Maintenance',
      'Récolte', 'Semis', 'Approvisionnement', 'Autre'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poignée
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Nouvelle tâche',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),

                  // Titre
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Description
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Priorité
                  const Text('Priorité',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PriorityChip(
                        label: 'Haute',
                        value: 'high',
                        color: Colors.red,
                        selected: selectedPriority == 'high',
                        onTap: () =>
                            setModalState(() => selectedPriority = 'high'),
                      ),
                      const SizedBox(width: 8),
                      _PriorityChip(
                        label: 'Moyenne',
                        value: 'medium',
                        color: Colors.orange,
                        selected: selectedPriority == 'medium',
                        onTap: () =>
                            setModalState(() => selectedPriority = 'medium'),
                      ),
                      const SizedBox(width: 8),
                      _PriorityChip(
                        label: 'Basse',
                        value: 'low',
                        color: Colors.green,
                        selected: selectedPriority == 'low',
                        onTap: () =>
                            setModalState(() => selectedPriority = 'low'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Catégorie
                  const Text('Catégorie',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 16),

                  // Date
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded,
                        color: AppTheme.greenPrimary),
                    title: Text(
                      'Date : ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setModalState(() => selectedDate = picked);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Bouton créer
                  FilledButton(
                    onPressed: () {
                      if (titleCtrl.text.trim().isEmpty) return;
                      final now = DateTime.now();
                      final isToday = selectedDate.day == now.day &&
                          selectedDate.month == now.month &&
                          selectedDate.year == now.year;
                      final isTomorrow = selectedDate.day == now.day + 1 &&
                          selectedDate.month == now.month;

                      setState(() {
                        _tasks.add(_Task(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? 'Aucune description'
                              : descCtrl.text.trim(),
                          priority: selectedPriority,
                          dueDate: isToday
                              ? "Aujourd'hui"
                              : isTomorrow
                                  ? 'Demain'
                                  : '${selectedDate.day}/${selectedDate.month}',
                          category: selectedCategory,
                        ));
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('✅ Tâche ajoutée !'),
                          backgroundColor: AppTheme.greenPrimary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54)),
                    child: const Text('Créer la tâche',
                        style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _tasks.where((t) => !t.done).toList();
    final completed = _tasks.where((t) => t.done).toList();
    final total = _tasks.length;
    final progress = total > 0 ? completed.length / total : 0.0;

    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Header stats
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildStatsHeader(
                      pending.length, completed.length, progress),
                ),
              ),

              // Section À faire
              if (pending.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: _SectionTitle(
                        label: 'À faire', count: pending.length),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final task = pending[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(
                            task: task,
                            onToggle: () => _toggleTask(task),
                            onDelete: () => _deleteTask(task),
                          ),
                        );
                      },
                      childCount: pending.length,
                    ),
                  ),
                ),
              ],

              // Section Terminées
              if (completed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: _SectionTitle(
                        label: 'Terminées', count: completed.length,
                        muted: true),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final task = completed[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(
                            task: task,
                            onToggle: () => _toggleTask(task),
                            onDelete: () => _deleteTask(task),
                          ),
                        );
                      },
                      childCount: completed.length,
                    ),
                  ),
                ),
              ],

              // État vide
              if (_tasks.isEmpty)
                SliverFillRemaining(
                  child: _buildEmptyState(),
                ),
            ],
          ),

          // FAB ajout
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton.extended(
              onPressed: _showAddTaskDialog,
              backgroundColor: AppTheme.greenPrimary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Ajouter',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int pending, int completed, double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF11998E).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Progression',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withValues(alpha: 0.9))),
                        const SizedBox(height: 8),
                        Text('${(progress * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -1.0)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text('$completed/${pending + completed}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Text('tâches',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
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
          Icon(Icons.task_alt_rounded,
              size: 80,
              color: AppTheme.greenPrimary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Aucune tâche',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Appuyez sur "Ajouter" pour créer votre première tâche',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Widgets internes ────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String label;
  final int count;
  final bool muted;
  const _SectionTitle(
      {required this.label, required this.count, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: muted
                    ? AppTheme.greenDark.withValues(alpha: 0.5)
                    : AppTheme.greenDark)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: muted
                ? Colors.black.withValues(alpha: 0.05)
                : AppTheme.greenPrimary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text('$count',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: muted
                      ? Colors.black.withValues(alpha: 0.4)
                      : AppTheme.greenPrimary)),
        ),
      ],
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _PriorityChip(
      {required this.label,
      required this.value,
      required this.color,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color)),
      ),
    );
  }
}

LinearGradient _gradientForPriority(String priority) {
  switch (priority) {
    case 'high':
      return const LinearGradient(
          colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    case 'medium':
      return const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFEE140)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
    default:
      return const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF30D158)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight);
  }
}

IconData _iconForCategory(String category) {
  switch (category) {
    case 'Irrigation': return Icons.water_drop_rounded;
    case 'Traitement': return Icons.pest_control_rounded;
    case 'Maintenance': return Icons.build_rounded;
    case 'Récolte': return Icons.agriculture_rounded;
    case 'Semis': return Icons.grass_rounded;
    case 'Approvisionnement': return Icons.shopping_cart_rounded;
    default: return Icons.task_rounded;
  }
}

class _TaskCard extends StatelessWidget {
  final _Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard(
      {required this.task,
      required this.onToggle,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForPriority(task.priority);
    final icon = _iconForCategory(task.category);

    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: AnimatedOpacity(
        opacity: task.done ? 0.55 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: task.done
                ? null
                : [
                    BoxShadow(
                        color: gradient.colors.first.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 6))
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                // Bande colorée + icône
                Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    gradient: task.done ? null : gradient,
                    color: task.done
                        ? Colors.grey.shade200
                        : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: onToggle,
                    child: Icon(
                      task.done
                          ? Icons.check_circle_rounded
                          : icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                // Contenu
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1C1C1E),
                            decoration: task.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(task.description,
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _InfoTag(
                                icon: Icons.calendar_today_rounded,
                                label: task.dueDate,
                                color: gradient.colors.first),
                            const SizedBox(width: 8),
                            _InfoTag(
                                label: task.category,
                                color: Colors.grey.shade600),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Checkbox à droite
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: onToggle,
                    child: Icon(
                      task.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: task.done
                          ? AppTheme.greenPrimary
                          : Colors.grey.shade400,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color color;
  const _InfoTag({this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}