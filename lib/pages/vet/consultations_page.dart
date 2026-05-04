import 'package:flutter/material.dart';

class ConsultationsPage extends StatefulWidget {
  const ConsultationsPage({super.key});

  @override
  State<ConsultationsPage> createState() => _ConsultationsPageState();
}

class _ConsultationsPageState extends State<ConsultationsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  final List<Map<String, dynamic>> _consultations = [
    {
      'id': 'C-001',
      'animal': 'Vache #002',
      'species': 'Bovin',
      'farm': 'Ferme Ben Ali',
      'owner': 'Karim Ben Ali',
      'date': '2026-05-01',
      'type': 'Urgence',
      'diagnosis': 'Mammite aiguë',
      'treatment': 'Antibiotiques + anti-inflammatoires',
      'status': 'en_cours',
      'followUp': '2026-05-05',
    },
    {
      'id': 'C-002',
      'animal': 'Brebis #015',
      'species': 'Ovin',
      'farm': 'Ferme Maatoug',
      'owner': 'Sami Maatoug',
      'date': '2026-04-28',
      'type': 'Vaccination',
      'diagnosis': 'Vaccination annuelle (Charbon)',
      'treatment': 'Vaccin administré',
      'status': 'terminé',
      'followUp': '-',
    },
    {
      'id': 'C-003',
      'animal': 'Taureau #003',
      'species': 'Bovin',
      'farm': 'Ferme Chaouachi',
      'owner': 'Ali Chaouachi',
      'date': '2026-04-30',
      'type': 'Urgence',
      'diagnosis': 'Fièvre aphteuse suspectée',
      'treatment': 'Isolement + prélèvements en cours',
      'status': 'en_cours',
      'followUp': '2026-05-03',
    },
    {
      'id': 'C-004',
      'animal': 'Cheval #007',
      'species': 'Équin',
      'farm': 'Haras El Hana',
      'owner': 'Nour El Hana',
      'date': '2026-04-25',
      'type': 'Chirurgie',
      'diagnosis': 'Colique — opération intestinale',
      'treatment': 'Chirurgie réussie, convalescence',
      'status': 'suivi',
      'followUp': '2026-05-10',
    },
    {
      'id': 'C-005',
      'animal': 'Chèvre #030',
      'species': 'Caprin',
      'farm': 'Ferme Ben Ali',
      'owner': 'Karim Ben Ali',
      'date': '2026-04-20',
      'type': 'Contrôle',
      'diagnosis': 'RAS — bonne santé',
      'treatment': 'Aucun',
      'status': 'terminé',
      'followUp': '-',
    },
  ];

  List<Map<String, dynamic>> get _filtered {
    return _consultations.where((c) {
      final q = _searchQuery.toLowerCase();
      return q.isEmpty ||
          (c['animal'] as String).toLowerCase().contains(q) ||
          (c['farm'] as String).toLowerCase().contains(q) ||
          (c['diagnosis'] as String).toLowerCase().contains(q);
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
                _buildConsultationsList(_filtered),
                _buildConsultationsList(
                    _filtered.where((c) => c['status'] == 'en_cours').toList()),
                _buildConsultationsList(
                    _filtered.where((c) => c['status'] == 'terminé').toList()),
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
              const Text('Consultations',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A2E))),
              ElevatedButton.icon(
                onPressed: () => _showNewConsultationSheet(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nouvelle'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
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
            labelColor: Colors.blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.blue,
            tabs: [
              Tab(text: 'Toutes (${_filtered.length})'),
              Tab(
                  text:
                      'En cours (${_filtered.where((c) => c['status'] == 'en_cours').length})'),
              Tab(
                  text:
                      'Terminées (${_filtered.where((c) => c['status'] == 'terminé').length})'),
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
          hintText: 'Rechercher animal, ferme, diagnostic...',
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

  Widget _buildConsultationsList(List<Map<String, dynamic>> list) {
    if (list.isEmpty) {
      return const Center(
        child: Text('Aucune consultation trouvée',
            style: TextStyle(color: Colors.grey, fontSize: 14)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) => _buildConsultationCard(list[i]),
    );
  }

  Widget _buildConsultationCard(Map<String, dynamic> c) {
    final statusData = _getStatusData(c['status'] as String);
    final typeColor = _getTypeColor(c['type'] as String);

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
        onTap: () => _showConsultationDetail(c),
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
                    child: Text(c['type'] as String,
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
                      color: (statusData['color'] as Color)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusData['label'] as String,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusData['color'] as Color)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.pets_rounded,
                      size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(c['animal'] as String,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(width: 8),
                  Text('(${c['species']})',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('${c['farm']} — ${c['owner']}',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.assignment_rounded,
                          size: 14, color: Colors.blue),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(c['diagnosis'] as String,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600))),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.medication_rounded,
                          size: 14, color: Colors.green),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(c['treatment'] as String,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade700))),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Consultation : ${c['date']}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  if (c['followUp'] != '-') ...[
                    const SizedBox(width: 12),
                    const Icon(Icons.event_rounded,
                        size: 13, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text('Suivi : ${c['followUp']}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.blue)),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getStatusData(String status) {
    switch (status) {
      case 'en_cours':
        return {'label': '🔄 En cours', 'color': Colors.orange};
      case 'terminé':
        return {'label': '✅ Terminé', 'color': Colors.green};
      case 'suivi':
        return {'label': '👁 Suivi', 'color': Colors.blue};
      default:
        return {'label': status, 'color': Colors.grey};
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Urgence': return Colors.red;
      case 'Vaccination': return Colors.purple;
      case 'Chirurgie': return Colors.orange;
      case 'Contrôle': return Colors.teal;
      default: return Colors.blue;
    }
  }

  void _showConsultationDetail(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text('Dossier ${c['id']}',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _detailSection('Patient', [
              _detailRow(Icons.pets_rounded, 'Animal', c['animal'] as String),
              _detailRow(Icons.category_rounded, 'Espèce', c['species'] as String),
              _detailRow(Icons.location_on_rounded, 'Ferme', c['farm'] as String),
              _detailRow(Icons.person_rounded, 'Propriétaire', c['owner'] as String),
            ]),
            const SizedBox(height: 12),
            _detailSection('Diagnostic & Traitement', [
              _detailRow(Icons.assignment_rounded, 'Diagnostic', c['diagnosis'] as String),
              _detailRow(Icons.medication_rounded, 'Traitement', c['treatment'] as String),
            ]),
            const SizedBox(height: 12),
            _detailSection('Suivi', [
              _detailRow(Icons.calendar_today_rounded, 'Date consultation', c['date'] as String),
              _detailRow(Icons.event_rounded, 'Prochain suivi', c['followUp'] as String),
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
                      backgroundColor: Colors.blue,
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
                color: Colors.blue)),
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
          Icon(icon, size: 16, color: Colors.blue),
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

  void _showNewConsultationSheet() {
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
            const Text('Nouvelle consultation',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Animal (ex: Vache #010)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const TextField(
                decoration: InputDecoration(
                    labelText: 'Ferme / Propriétaire',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const TextField(
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: 'Diagnostic',
                    border: OutlineInputBorder())),
            const SizedBox(height: 10),
            const TextField(
                maxLines: 2,
                decoration: InputDecoration(
                    labelText: 'Traitement prescrit',
                    border: OutlineInputBorder())),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Enregistrer la consultation'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
