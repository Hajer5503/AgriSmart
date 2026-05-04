import 'package:flutter/material.dart';

class AnalysesPage extends StatefulWidget {
  const AnalysesPage({super.key});

  @override
  State<AnalysesPage> createState() => _AnalysesPageState();
}

class _AnalysesPageState extends State<AnalysesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _analyses = [
    {
      'id': 'A-001',
      'parcel': 'Parcelle A-03',
      'type': 'Sol',
      'date': '2026-04-30',
      'lab': 'CRDA Tunis',
      'ph': '6.8',
      'nitrogen': 'Normal (42 mg/kg)',
      'phosphorus': 'Élevé (18 mg/kg)',
      'potassium': 'Normal (210 mg/kg)',
      'moisture': '24%',
      'status': 'ok',
      'recommendation': 'Aucune correction nécessaire. Maintenir l\'apport en matière organique.',
    },
    {
      'id': 'A-002',
      'parcel': 'Parcelle B-07',
      'type': 'Feuillage',
      'date': '2026-04-28',
      'lab': 'Labo AgriTech',
      'ph': '-',
      'nitrogen': 'Faible (12 mg/kg)',
      'phosphorus': 'Normal',
      'potassium': 'Normal',
      'moisture': '-',
      'status': 'warning',
      'recommendation': 'Apporter un engrais azoté (urée 46%) à raison de 50 kg/ha. Traitement urgent recommandé.',
    },
    {
      'id': 'A-003',
      'parcel': 'Parcelle C-01',
      'type': 'Eau irrigation',
      'date': '2026-04-25',
      'lab': 'INRAT',
      'ph': '7.9',
      'nitrogen': '-',
      'phosphorus': '-',
      'potassium': '-',
      'moisture': '-',
      'status': 'alert',
      'recommendation': 'Réduire la fréquence d\'irrigation. Prévoir un traitement anti-calcaire pour les conduites.',
    },
    {
      'id': 'A-004',
      'parcel': 'Parcelle D-02',
      'type': 'Sol',
      'date': '2026-04-20',
      'lab': 'CRDA Tunis',
      'ph': '7.1',
      'nitrogen': 'Normal (38 mg/kg)',
      'phosphorus': 'Faible (6 mg/kg)',
      'potassium': 'Normal (195 mg/kg)',
      'moisture': '19%',
      'status': 'warning',
      'recommendation': 'Apporter du superphosphate 45% à 80 kg/ha avant le prochain semis.',
    },
    {
      'id': 'A-005',
      'parcel': 'Parcelle A-01',
      'type': 'Sol',
      'date': '2026-04-15',
      'lab': 'CRDA Tunis',
      'ph': '6.5',
      'nitrogen': 'Normal (45 mg/kg)',
      'phosphorus': 'Normal (14 mg/kg)',
      'potassium': 'Élevé (280 mg/kg)',
      'moisture': '27%',
      'status': 'ok',
      'recommendation': 'Sol en bon état. Réduire légèrement l\'apport en potasse lors du prochain cycle.',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    return _analyses.where((a) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          (a['parcel'] as String).toLowerCase().contains(q) ||
          (a['type'] as String).toLowerCase().contains(q) ||
          (a['lab'] as String).toLowerCase().contains(q);
    }).toList();
  }

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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildSearch(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAnalysesList(_filtered),
                _buildAnalysesList(
                    _filtered.where((a) => a['type'] == 'Sol').toList()),
                _buildAnalysesList(
                    _filtered.where((a) => a['type'] != 'Sol').toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Analyses',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
              ElevatedButton.icon(
                onPressed: () => _showNewAnalysisSheet(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TabBar(
            controller: _tabController,
            labelColor: Colors.teal,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.teal,
            tabs: [
              Tab(text: 'Toutes (${_filtered.length})'),
              Tab(
                  text:
                      'Sol (${_filtered.where((a) => a['type'] == 'Sol').length})'),
              Tab(
                  text:
                      'Autres (${_filtered.where((a) => a['type'] != 'Sol').length})'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        decoration: InputDecoration(
          hintText: 'Rechercher parcelle, type, laboratoire...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildAnalysesList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text('Aucune analyse trouvée',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildAnalysisCard(list[i]),
    );
  }

  Widget _buildAnalysisCard(Map<String, dynamic> a) {
    final statusColor = a['status'] == 'ok'
        ? Colors.green
        : a['status'] == 'warning'
            ? Colors.orange
            : Colors.red;
    final statusLabel = a['status'] == 'ok'
        ? '✅ Normal'
        : a['status'] == 'warning'
            ? '⚠️ Attention'
            : '🚨 Critique';
    final typeColor = a['type'] == 'Sol'
        ? Colors.brown
        : a['type'] == 'Feuillage'
            ? Colors.green
            : Colors.blue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: InkWell(
        onTap: () => _showAnalysisDetail(a),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(a['type'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: typeColor)),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.grass_rounded,
                      size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Text(a['parcel'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.science_rounded,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${a['lab']} — ${a['date']}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: Colors.teal.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        size: 14, color: Colors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(a['recommendation'] as String,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAnalysisDetail(Map<String, dynamic> a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.92,
        minChildSize: 0.45,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Rapport ${a['id']}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailSection('Informations', [
              _detailRow(Icons.grass_rounded, 'Parcelle', a['parcel'] as String),
              _detailRow(Icons.category_rounded, 'Type d\'analyse', a['type'] as String),
              _detailRow(Icons.science_rounded, 'Laboratoire', a['lab'] as String),
              _detailRow(Icons.calendar_today_rounded, 'Date', a['date'] as String),
            ]),
            if (a['ph'] != '-') ...[
              const SizedBox(height: 12),
              _detailSection('Résultats', [
                if (a['ph'] != '-')
                  _detailRow(Icons.water_drop_rounded, 'pH', a['ph'] as String),
                if (a['nitrogen'] != '-')
                  _detailRow(Icons.eco_rounded, 'Azote (N)', a['nitrogen'] as String),
                if (a['phosphorus'] != '-')
                  _detailRow(Icons.circle_rounded, 'Phosphore (P)', a['phosphorus'] as String),
                if (a['potassium'] != '-')
                  _detailRow(Icons.hexagon_rounded, 'Potassium (K)', a['potassium'] as String),
                if (a['moisture'] != '-')
                  _detailRow(Icons.opacity_rounded, 'Humidité', a['moisture'] as String),
              ]),
            ],
            const SizedBox(height: 12),
            _detailSection('Recommandation', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        size: 16, color: Colors.teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(a['recommendation'] as String,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade700)),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                  label: const Text('Fermer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.teal)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: rows),
        ),
      ],
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.teal),
          const SizedBox(width: 10),
          Text('$label : ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 12)),
          Expanded(
            child: Text(value,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  void _showNewAnalysisSheet() {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nouvelle analyse',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Parcelle (ex: Parcelle A-05)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                  labelText: 'Type d\'analyse',
                  border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'Sol', child: Text('Analyse de sol')),
                DropdownMenuItem(
                    value: 'Feuillage', child: Text('Analyse foliaire')),
                DropdownMenuItem(
                    value: 'Eau irrigation',
                    child: Text('Eau d\'irrigation')),
              ],
              onChanged: (_) {},
            ),
            const SizedBox(height: 10),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Laboratoire',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const TextField(
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: 'Observations préliminaires',
                    border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Enregistrer l\'analyse'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
