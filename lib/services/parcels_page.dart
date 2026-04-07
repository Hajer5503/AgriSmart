import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app/app_theme.dart';
import '../services/farm_service.dart';
import '../services/auth_service.dart';
import 'dart:ui';

class ParcelsPage extends StatefulWidget {
  const ParcelsPage({super.key});

  @override
  State<ParcelsPage> createState() => _ParcelsPageState();
}

class _ParcelsPageState extends State<ParcelsPage> {
  final FarmService _farmService = FarmService();
  List<Farm> _farms = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<void> _loadFarms() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.id;
      if (userId == null) return;

      final farms = await _farmService.getFarms(userId);
      setState(() {
        _farms = farms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement';
        _isLoading = false;
      });
    }
  }

  void _showAddFarmDialog() {
    final nameCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final areaCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('Nouvelle Ferme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: 'Nom de la ferme', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationCtrl,
                decoration: InputDecoration(labelText: 'Localisation', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: areaCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Surface (hectares)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final userId = authService.currentUser?.id;
                  if (userId == null || nameCtrl.text.isEmpty) return;
                  try {
                    await _farmService.createFarm(
                      userId: userId,
                      name: nameCtrl.text,
                      location: locationCtrl.text,
                      areaHectares: double.tryParse(areaCtrl.text),
                    );
                    Navigator.pop(context);
                    _loadFarms(); // Rafraîchir
                  } catch (e) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Erreur lors de la création')),
                    );
                  }
                },
                style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 54)),
                child: const Text('Créer la ferme'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : _farms.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadFarms,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _farms.length,
                            itemBuilder: (context, index) {
                              final farm = _farms[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _FarmCard(
                                  farm: farm,
                                  onDelete: () async {
                                    await _farmService.deleteFarm(farm.id);
                                    _loadFarms();
                                  },
                                ),
                              );
                            },
                          ),
                        ),
          Positioned(
            right: 20,
            bottom: 20,
            child: FloatingActionButton(
              onPressed: _showAddFarmDialog,
              backgroundColor: AppTheme.greenPrimary,
              child: const Icon(Icons.add, color: Colors.white),
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
          Icon(Icons.agriculture_rounded, size: 80, color: AppTheme.greenPrimary.withOpacity(0.4)),
          const SizedBox(height: 16),
          const Text('Aucune ferme', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('Appuyez sur + pour ajouter votre première ferme'),
        ],
      ),
    );
  }
}

class _FarmCard extends StatelessWidget {
  final Farm farm;
  final VoidCallback onDelete;

  const _FarmCard({required this.farm, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF11998E), Color(0xFF38EF7D)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.agriculture_rounded, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(farm.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      if (farm.location != null)
                        Text(farm.location!, style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.straighten, size: 16, color: AppTheme.greenPrimary),
                const SizedBox(width: 8),
                Text(farm.areaHectares != null ? '${farm.areaHectares} ha' : 'Surface non définie'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}