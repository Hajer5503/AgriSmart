import 'package:flutter/material.dart';

class LivestockPage extends StatefulWidget {
  const LivestockPage({super.key});

  @override
  State<LivestockPage> createState() => _LivestockPageState();
}

class _LivestockPageState extends State<LivestockPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterSpecies = 'Tous';

  final List<Map<String, dynamic>> _animals = [
    {'id': '#001', 'name': 'Vache #001', 'species': 'Bovin', 'gender': 'F', 'age': '4 ans', 'weight': '520 kg', 'status': 'sain', 'production': '22L/j', 'vaccine': '2025-06-01'},
    {'id': '#002', 'name': 'Vache #002', 'species': 'Bovin', 'gender': 'F', 'age': '3 ans', 'weight': '480 kg', 'status': 'alerte', 'production': '15L/j', 'vaccine': '2025-03-10'},
    {'id': '#003', 'name': 'Taureau #003', 'species': 'Bovin', 'gender': 'M', 'age': '5 ans', 'weight': '820 kg', 'status': 'traitement', 'production': '-', 'vaccine': '2025-07-20'},
    {'id': '#015', 'name': 'Brebis #015', 'species': 'Ovin', 'gender': 'F', 'age': '2 ans', 'weight': '65 kg', 'status': 'sain', 'production': '1.5L/j', 'vaccine': '2025-05-15'},
    {'id': '#016', 'name': 'Brebis #016', 'species': 'Ovin', 'gender': 'F', 'age': '3 ans', 'weight': '72 kg', 'status': 'sain', 'production': '1.8L/j', 'vaccine': '2025-05-15'},
    {'id': '#030', 'name': 'Chèvre #030', 'species': 'Caprin', 'gender': 'F', 'age': '2 ans', 'weight': '48 kg', 'status': 'sain', 'production': '2L/j', 'vaccine': '2025-04-01'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterSpecies == 'Tous') return _animals;
    return _animals.where((a) => a['species'] == _filterSpecies).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildSpeciesFilter(),
          _buildSummaryBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnimalsList(),
                _buildHealthView(),
                _buildProductionView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Mon Troupeau',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
              ElevatedButton.icon(
                onPressed: () => _showAddAnimalSheet(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.orange,
            tabs: const [
              Tab(text: 'Liste'),
              Tab(text: 'Santé'),
              Tab(text: 'Production'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpeciesFilter() {
    final species = ['Tous', 'Bovin', 'Ovin', 'Caprin'];
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: species
            .map((s) => GestureDetector(
                  onTap: () => setState(() => _filterSpecies = s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: _filterSpecies == s
                          ? Colors.orange
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(s,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _filterSpecies == s
                                ? Colors.white
                                : Colors.orange)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSummaryBar() {
    final total = _filtered.length;
    final sains = _filtered.where((a) => a['status'] == 'sain').length;
    final alertes = _filtered.where((a) => a['status'] == 'alerte').length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('$total', 'Total', Colors.orange),
          _summaryItem('$sains', 'Sains', Colors.green),
          _summaryItem('$alertes', 'Alertes', Colors.red),
        ],
      ),
    );
  }

  Widget _summaryItem(String val, String label, Color color) {
    return Column(
      children: [
        Text(val,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildAnimalsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _buildAnimalCard(_filtered[i]),
    );
  }

  Widget _buildAnimalCard(Map<String, dynamic> a) {
    final statusColor = a['status'] == 'sain'
        ? Colors.green
        : a['status'] == 'alerte'
            ? Colors.red
            : Colors.orange;
    final statusLabel = a['status'] == 'sain'
        ? 'Sain'
        : a['status'] == 'alerte'
            ? '⚠️ Alerte'
            : '💊 Traitement';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withValues(alpha: 0.15),
          child: Text(a['id'] as String,
              style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: Colors.orange)),
        ),
        title: Text(a['name'] as String,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(
            '${a['species']} • ${a['gender']} • ${a['age']} • ${a['weight']}',
            style:
                TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(statusLabel,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: statusColor)),
            ),
            const SizedBox(height: 4),
            Text('Vaccin: ${a['vaccine']}',
                style: TextStyle(
                    fontSize: 9, color: Colors.grey.shade500)),
          ],
        ),
        onTap: () => _showAnimalDetail(a),
      ),
    );
  }

  Widget _buildHealthView() {
    final alertAnimals =
        _filtered.where((a) => a['status'] != 'sain').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (alertAnimals.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('✅ Tous les animaux sont en bonne santé',
                  style: TextStyle(
                      fontSize: 16, color: Colors.green),
                  textAlign: TextAlign.center),
            ),
          )
        else ...[
          Text('${alertAnimals.length} animaux nécessitent attention',
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.red)),
          const SizedBox(height: 12),
          ...alertAnimals.map((a) => _buildHealthAlert(a)),
        ],
        const SizedBox(height: 16),
        _buildVaccinationSchedule(),
      ],
    );
  }

  Widget _buildHealthAlert(Map<String, dynamic> a) {
    final color = a['status'] == 'alerte' ? Colors.red : Colors.orange;
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
          Icon(Icons.medical_services_rounded, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(a['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    a['status'] == 'alerte'
                        ? 'Symptômes détectés — consultation vétérinaire requise'
                        : 'En cours de traitement médical',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            child:
                Text('Détails', style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildVaccinationSchedule() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('📅 Vaccinations à venir',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        ..._filtered
            .where((a) => a['vaccine'] != null)
            .take(3)
            .map((a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.vaccines_rounded,
                      color: Colors.blue, size: 20),
                  title: Text(a['name'] as String,
                      style: const TextStyle(fontSize: 13)),
                  trailing: Text(a['vaccine'] as String,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blue)),
                )),
      ],
    );
  }

  Widget _buildProductionView() {
    final producers =
        _filtered.where((a) => a['production'] != '-').toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildProductionSummary(),
        const SizedBox(height: 16),
        const Text('Détail par animal',
            style:
                TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        const SizedBox(height: 10),
        ...producers.map((a) => _buildProductionCard(a)),
      ],
    );
  }

  Widget _buildProductionSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Color(0xFFFF8C00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Production journalière',
              style: TextStyle(
                  color: Colors.white70, fontSize: 12)),
          const Text('320 Litres',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.trending_up_rounded,
                  color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text('+12% vs hier',
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductionCard(Map<String, dynamic> a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.water_drop_rounded,
              color: Colors.blue, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(a['name'] as String,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text(a['production'] as String,
              style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.blue,
                  fontSize: 15)),
        ],
      ),
    );
  }

  void _showAnimalDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a['name'] as String,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailRow(Icons.category_rounded, 'Espèce', a['species'] as String),
            _detailRow(Icons.cake_rounded, 'Âge', a['age'] as String),
            _detailRow(Icons.monitor_weight_rounded, 'Poids', a['weight'] as String),
            _detailRow(Icons.water_drop_rounded, 'Production', a['production'] as String),
            _detailRow(Icons.vaccines_rounded, 'Prochain vaccin', a['vaccine'] as String),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.orange),
          const SizedBox(width: 10),
          Text('$label : ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  void _showAddAnimalSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Nouvel animal',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Identifiant (ex: #143)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Espèce',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Poids (kg)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Enregistrer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
