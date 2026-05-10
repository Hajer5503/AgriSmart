import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import '../services/task_service.dart';
import '../services/api_service.dart';

// ─── Page ───────────────────────────────────────────────────
class TasksPage extends StatefulWidget {
  const TasksPage({super.key});

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final TaskService _service = TaskService();
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animationController.forward();
    _loadTasks();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);
    try {
      final tasks = await _service.getTasks();
      if (mounted) {
        setState(() { _tasks = tasks; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleTask(Task task) async {
    try {
      final updated = await _service.toggleTask(task.id);
      if (mounted) {
        setState(() {
        final idx = _tasks.indexWhere((t) => t.id == updated.id);
        if (idx >= 0) _tasks[idx] = updated;
      });
      }
    } catch (_) {}
  }

  Future<void> _deleteTask(Task task) async {
    setState(() => _tasks.remove(task));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Tâche "${task.title}" supprimée'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
    try {
      await _service.deleteTask(task.id);
    } catch (_) {
      if (mounted) _loadTasks();
    }
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
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
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Titre *',
                      prefixIcon: const Icon(Icons.title_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      prefixIcon: const Icon(Icons.description_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Priorité',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _PriorityChip(label: 'Haute', value: 'high', color: Colors.red,
                          selected: selectedPriority == 'high',
                          onTap: () => setModalState(() => selectedPriority = 'high')),
                      const SizedBox(width: 8),
                      _PriorityChip(label: 'Moyenne', value: 'medium', color: Colors.orange,
                          selected: selectedPriority == 'medium',
                          onTap: () => setModalState(() => selectedPriority = 'medium')),
                      const SizedBox(width: 8),
                      _PriorityChip(label: 'Basse', value: 'low', color: Colors.green,
                          selected: selectedPriority == 'low',
                          onTap: () => setModalState(() => selectedPriority = 'low')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Catégorie',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setModalState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today_rounded, color: AppTheme.greenPrimary),
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
                  FilledButton(
                    onPressed: () async {
                      if (titleCtrl.text.trim().isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        final due = '${selectedDate.year}-'
                            '${selectedDate.month.toString().padLeft(2, '0')}-'
                            '${selectedDate.day.toString().padLeft(2, '0')}';
                        await _service.createTask(
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          priority: selectedPriority,
                          category: selectedCategory,
                          dueDate: due,
                        );
                        if (mounted) {
                          _loadTasks();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text('Tâche ajoutée !'),
                            backgroundColor: AppTheme.greenPrimary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ApiService.extractError(e)),
                          backgroundColor: Colors.red,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ));
                        }
                      }
                    },
                    style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                    child: const Text('Créer la tâche', style: TextStyle(fontSize: 16)),
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
          RefreshIndicator(
            onRefresh: _loadTasks,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: _buildStatsHeader(pending.length, completed.length, progress),
                        ),
                      ),
                      if (pending.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: _SectionTitle(label: 'À faire', count: pending.length),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final task = pending[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
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
                      if (completed.isNotEmpty) ...[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                            child: _SectionTitle(label: 'Terminées', count: completed.length, muted: true),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) {
                                final task = completed[i];
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
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
                      if (_tasks.isEmpty)
                        SliverFillRemaining(child: _buildEmptyState()),
                    ],
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: FloatingActionButton(
                heroTag: 'tasks_fab_add',
                tooltip: 'Nouvelle tâche',
                onPressed: _showAddTaskDialog,
                backgroundColor: AppTheme.greenPrimary,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int pending, int completed, double progress) {
    final total = pending + completed;
    final pct = total > 0 ? (progress * 100).round() : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11998E).withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                color: Colors.white.withValues(alpha: 0.9),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Progression',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const Spacer(),
              Text(
                total == 0 ? '—' : '$pct%',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              if (total > 0) ...[
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$completed / $total',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.95),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : progress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.28),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.task_alt_rounded, size: 80, color: AppTheme.greenPrimary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Aucune tâche', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Touchez le bouton + pour créer une tâche',
              style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ─── Widgets internes ────────────────────────────────────────

String _formatDueDate(String? dueDate) {
  if (dueDate == null || dueDate.isEmpty) return 'Sans date';
  try {
    final dt = DateTime.parse(dueDate);
    final today = DateTime.now();
    final diff = DateTime(dt.year, dt.month, dt.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    if (diff == 0) return "Aujourd'hui";
    if (diff == 1) return 'Demain';
    return '${dt.day}/${dt.month}';
  } catch (_) {
    return dueDate;
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final int count;
  final bool muted;
  const _SectionTitle({required this.label, required this.count, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: muted ? AppTheme.greenDark.withValues(alpha: 0.45) : AppTheme.greenDark,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: muted
                ? Colors.black.withValues(alpha: 0.05)
                : AppTheme.greenPrimary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: muted ? Colors.black.withValues(alpha: 0.38) : AppTheme.greenPrimary,
            ),
          ),
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
      {required this.label, required this.value, required this.color,
       required this.selected, required this.onTap});

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
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    case 'medium':
      return const LinearGradient(
          colors: [Color(0xFFFF9500), Color(0xFFFEE140)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
    default:
      return const LinearGradient(
          colors: [Color(0xFF34C759), Color(0xFF30D158)],
          begin: Alignment.topLeft, end: Alignment.bottomRight);
  }
}

IconData _iconForCategory(String? category) {
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
  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _TaskCard({required this.task, required this.onToggle, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final gradient = _gradientForPriority(task.priority);
    final icon = _iconForCategory(task.category);
    final accent = gradient.colors.first;

    return Dismissible(
      key: Key(task.id.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 26),
      ),
      onDismissed: (_) => onDelete(),
      child: AnimatedOpacity(
        opacity: task.done ? 0.52 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          elevation: task.done ? 0 : 1.5,
          shadowColor: accent.withValues(alpha: 0.12),
          child: InkWell(
            onTap: onToggle,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  constraints: const BoxConstraints(minHeight: 72),
                  color: task.done ? Colors.grey.shade300 : accent,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              icon,
                              size: 22,
                              color: task.done ? Colors.grey.shade500 : accent,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                task.title,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  color: const Color(0xFF1C1C1E),
                                  decoration: task.done ? TextDecoration.lineThrough : null,
                                  decorationColor: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 32),
                            child: Text(
                              task.description,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 32),
                          child: Text(
                            '${_formatDueDate(task.dueDate)} · ${task.category ?? 'Autre'}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: task.done ? Colors.grey.shade500 : Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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
    );
  }
}
