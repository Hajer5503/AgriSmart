import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/app_theme.dart';
import '../services/field_service.dart';
import '../services/auth_service.dart';
import 'dart:ui';

class ParcelsPage extends StatefulWidget {
  const ParcelsPage({super.key});

  @override
  State<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends State<ParcelsPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  final FieldService _service = FieldService();

  List<Farm> _farms = [];
  List<Field> _fields = [];
  bool _isLoading = true;
  String? _error;

  // Onglet actif : fermes ou parcelles
  bool _showFarms = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        duration: const Duration(milliseconds: 600), vsync: this);
    _animCtrl.forward();
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final farms = await _service.getFarms();
      final fields = await _service.getFields();
      if (mounted) setState(() { _farms = farms; _fields = fields; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  // ── Couleurs selon la culture ──────────────────────────
  LinearGradient _gradientForCrop(String? crop) {
    switch ((crop ?? '').toLowerCase()) {
      case 'tomate': return const LinearGradient(colors: [Color(0xFFFA709A), Color(0xFFFEE140)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'blé': case 'ble': return const LinearGradient(colors: [Color(0xFFFEAC5E), Color(0xFFFFC371)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'olive': return const LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      case 'maïs': case 'mais': return const LinearGradient(colors: [Color(0xFF4FACFE), Color(0xFF00F2FE)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      default: return const LinearGradient(colors: [Color(0xFF667EEA), Color(0xFF764BA2)], begin: Alignment.topLeft, end: Alignment.bottomRight);
    }
  }

  // ── Dialog ajouter une ferme ──────────────────────────
  void _showAddFarmDialog() {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    String selectedType = 'Polyculture';
    final types = ['Polyculture', 'Maraîchage', 'Céréales', 'Élevage', 'Arboriculture', 'Autre'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheet(
            title: 'Nouvelle Ferme',
            onConfirm: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _service.createFarm(
                  name: nameCtrl.text.trim(),
                  location: locationCtrl.text.trim(),
                  areaHectares: double.tryParse(areaCtrl.text),
                  farmType: selectedType,
                );
                _load();
              } catch (e) {
                if (mounted) _showError('Erreur création ferme');
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(ctrl: nameCtrl, label: 'Nom de la ferme *', icon: Icons.agriculture_rounded),
                const SizedBox(height: 12),
                _Field(ctrl: locationCtrl, label: 'Localisation', icon: Icons.location_on_rounded),
                const SizedBox(height: 12),
                _Field(ctrl: areaCtrl, label: 'Surface totale (ha)', icon: Icons.straighten_rounded, numeric: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Type de ferme',
                    prefixIcon: const Icon(Icons.category_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (v) => setModal(() => selectedType = v!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Dialog ajouter une parcelle ───────────────────────
  void _showAddFieldDialog() {
    if (_farms.isEmpty) {
      _showError('Créez d\'abord une ferme');
      return;
    }

    final nameCtrl = TextEditingController();
    final areaCtrl = TextEditingController();
    final cropCtrl = TextEditingController();
    int selectedFarmId = _farms.first.id;
    String selectedSoil = 'Argileux';
    final soils = ['Argileux', 'Sableux', 'Limoneux', 'Calcaire', 'Humifère', 'Autre'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: _BottomSheet(
            title: 'Nouvelle Parcelle',
            onConfirm: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                await _service.createField(
                  farmId: selectedFarmId,
                  name: nameCtrl.text.trim(),
                  areaHectares: double.tryParse(areaCtrl.text),
                  soilType: selectedSoil,
                  currentCrop: cropCtrl.text.trim().isEmpty ? null : cropCtrl.text.trim(),
                );
                _load();
              } catch (e) {
                if (mounted) _showError('Erreur création parcelle');
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sélection de la ferme
                DropdownButtonFormField<int>(
                  value: selectedFarmId,
                  decoration: InputDecoration(
                    labelText: 'Ferme *',
                    prefixIcon: const Icon(Icons.agriculture_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: _farms.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name))).toList(),
                  onChanged: (v) => setModal(() => selectedFarmId = v!),
                ),
                const SizedBox(height: 12),
                _Field(ctrl: nameCtrl, label: 'Nom de la parcelle *', icon: Icons.grass_rounded),
                const SizedBox(height: 12),
                _Field(ctrl: areaCtrl, label: 'Surface (ha)', icon: Icons.straighten_rounded, numeric: true),
                const SizedBox(height: 12),
                _Field(ctrl: cropCtrl, label: 'Culture actuelle (ex: Tomate)', icon: Icons.eco_rounded),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedSoil,
                  decoration: InputDecoration(
                    labelText: 'Type de sol',
                    prefixIcon: const Icon(Icons.layers_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: soils.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setModal(() => selectedSoil = v!),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Toggle Fermes / Parcelles
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                _TabChip(label: 'Parcelles 🌾', selected: !_showFarms, onTap: () => setState(() => _showFarms = false)),
                const SizedBox(width: 10),
                _TabChip(label: 'Fermes 🏡', selected: _showFarms, onTap: () => setState(() => _showFarms = true)),
                const Spacer(),
                // Compteur
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.greenPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _showFarms ? '${_farms.length} ferme(s)' : '${_fields.length} parcelle(s)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.greenPrimary),
                  ),
                ),
              ],
            ),
          ),

          // Corps
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _showFarms ? _buildFarmsList() : _buildFieldsList(),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldsList() {
    if (_fields.isEmpty) {
      return _buildEmpty(
        icon: Icons.grass_rounded,
        title: 'Aucune parcelle',
        subtitle: 'Appuyez sur + pour ajouter votre première parcelle',
        onAdd: _showAddFieldDialog,
      );
    }
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: _fields.length,
          itemBuilder: (context, i) {
            final field = _fields[i];
            final gradient = _gradientForCrop(field.currentCrop);
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (i * 80)),
              tween: Tween(begin: 0.0, end: 1.0),
              curve: Curves.easeOutBack,
              builder: (ctx, v, _) => Transform.translate(
                offset: Offset(0, 40 * (1 - v)),
                child: Opacity(
                  opacity: v.clamp(0.0, 1.0),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _FieldCard(
                      field: field,
                      gradient: gradient,
                      onDelete: () async {
                        await _service.deleteField(field.id);
                        _load();
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        Positioned(
          right: 20, bottom: 20,
          child: _FAB(onPressed: _showAddFieldDialog),
        ),
      ],
    );
  }

  Widget _buildFarmsList() {
    if (_farms.isEmpty) {
      return _buildEmpty(
        icon: Icons.agriculture_rounded,
        title: 'Aucune ferme',
        subtitle: 'Appuyez sur + pour ajouter votre première ferme',
        onAdd: _showAddFarmDialog,
      );
    }
    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          itemCount: _farms.length,
          itemBuilder: (context, i) {
            final farm = _farms[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _FarmCard(
                farm: farm,
                fieldCount: _fields.where((f) => f.farmId == farm.id).length,
                onDelete: () async {
                  await _service.deleteFarm(farm.id);
                  _load();
                },
              ),
            );
          },
        ),
        Positioned(
          right: 20, bottom: 20,
          child: _FAB(onPressed: _showAddFarmDialog),
        ),
      ],
    );
  }

  Widget _buildEmpty({required IconData icon, required String title, required String subtitle, required VoidCallback onAdd}) {
    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 80, color: AppTheme.greenPrimary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
            ],
          ),
        ),
        Positioned(right: 20, bottom: 20, child: _FAB(onPressed: onAdd)),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.red.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('Erreur de chargement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Réessayer')),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
// Widgets internes
// ════════════════════════════════════════════════════════════

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? const LinearGradient(colors: [Color(0xFF34C759), Color(0xFF30D158)]) : null,
          color: selected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : Colors.grey.shade600,
        )),
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  final Field field;
  final LinearGradient gradient;
  final VoidCallback onDelete;
  const _FieldCard({required this.field, required this.gradient, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('field_${field.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: gradient.colors.first.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 8))],
        ),
        child: Column(
          children: [
            // Header gradient
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.grass_rounded, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(field.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      if (field.farmName != null)
                        Text(field.farmName!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(10)),
                    child: Text(field.status, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _Pill(icon: Icons.eco_rounded, label: 'Culture', value: field.currentCrop ?? 'Aucune')),
                      const SizedBox(width: 10),
                      Expanded(child: _Pill(icon: Icons.straighten_rounded, label: 'Surface', value: field.areaHectares != null ? '${field.areaHectares} ha' : '-')),
                    ],
                  ),
                  if (field.soilType != null) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _Pill(icon: Icons.layers_rounded, label: 'Sol', value: field.soilType!)),
                    ]),
                  ],
                  const SizedBox(height: 12),
                  // Barre de santé
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('État général', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                        Text('${(field.healthScore * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.greenPrimary)),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: field.healthScore, minHeight: 7,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(gradient.colors.first),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final Farm farm;
  final int fieldCount;
  final VoidCallback onDelete;
  const _FarmCard({required this.farm, required this.fieldCount, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.agriculture_rounded, color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(farm.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    if (farm.location != null && farm.location!.isNotEmpty)
                      Text(farm.location!, style: const TextStyle(fontSize: 12, color: Colors.white70)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white70),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: _Pill(icon: Icons.grass_rounded, label: 'Parcelles', value: '$fieldCount')),
                const SizedBox(width: 10),
                Expanded(child: _Pill(icon: Icons.straighten_rounded, label: 'Surface', value: farm.areaHectares != null ? '${farm.areaHectares} ha' : '-')),
                if (farm.farmType != null) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _Pill(icon: Icons.category_rounded, label: 'Type', value: farm.farmType!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Pill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.glassSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.greenPrimary),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1C1C1E)), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ],
      ),
    );
  }
}

class _FAB extends StatelessWidget {
  final VoidCallback onPressed;
  const _FAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: AppTheme.greenPrimary,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: const Text('Ajouter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final VoidCallback onConfirm;
  const _BottomSheet({required this.title, required this.child, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: const Text('Créer', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool numeric;
  const _Field({required this.ctrl, required this.label, required this.icon, this.numeric = false});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}