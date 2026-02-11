// lib/verification_donnees_page.dart
import 'package:flutter/material.dart';
import '../../data/local/database_helper.dart';
import '../../data/local/piste_chaussee_db_helper.dart';
import '../../models/piste_model.dart';
import '../../models/chaussee_model.dart';
import 'dart:convert';

class VerificationDonneesPage extends StatefulWidget {
  const VerificationDonneesPage({super.key});

  @override
  State<VerificationDonneesPage> createState() => _VerificationDonneesPageState();
}

class _VerificationDonneesPageState extends State<VerificationDonneesPage> {
  bool _isLoading = false;
  Map<String, int> _stats = {};
  List<PisteModel> _pistes = [];
  List<ChausseeModel> _chaussees = [];

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    setState(() => _isLoading = true);

    try {
      final helper = SimpleStorageHelper();

      // Charger les statistiques
      _stats = await helper.getCount();

      // Charger toutes les pistes
      _pistes = await helper.getAllPistes();

      // Charger toutes les chaussées
      _chaussees = await helper.getAllChaussees();
    } catch (e) {
      _showErrorMessage('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSuccessMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      appBar: AppBar(
        title: const Text(
          '📊 Vérification Données',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF2196F3),
        actions: [
          IconButton(
            onPressed: _chargerDonnees,
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Actualiser',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _chargerDonnees,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 16),
                  _buildPistesSection(),
                  const SizedBox(height: 16),
                  _buildChausseesSection(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2196F3),
              Color(0xFF1976D2)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text(
              '📈 Résumé des Données',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    '🛤️',
                    'Pistes',
                    '${_stats['pistes'] ?? 0}',
                    Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatItem(
                    '🛣️',
                    'Chaussées',
                    '${_stats['chaussees'] ?? 0}',
                    Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Total: ${_stats['total'] ?? 0} enregistrements',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String icon, String label, String value, Color color) {
    return Column(
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildPistesSection() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF1976D2),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.route, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Pistes Enregistrées',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_pistes.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_pistes.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '❌ Aucune piste enregistrée',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pistes.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final piste = _pistes[index];
                return _buildPisteItem(piste);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPisteItem(PisteModel piste) {
    // Parser les points GPS
    final points = jsonDecode(piste.pointsJson) as List;
    final hasGPS = points.isNotEmpty;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: hasGPS ? Colors.green : Colors.red,
        child: Text(
          '${piste.id}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        piste.codePiste,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '👤 ${piste.userLogin}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '📍 ${piste.nomOriginePiste} → ${piste.nomDestinationPiste}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '🕐 ${_formatDate(piste.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasGPS ? Icons.gps_fixed : Icons.gps_off,
            color: hasGPS ? Colors.green : Colors.red,
            size: 16,
          ),
          Text(
            '${points.length}',
            style: TextStyle(
              fontSize: 12,
              color: hasGPS ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChausseesSection() {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFF9800),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.construction, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Chaussées Enregistrées',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_chaussees.length}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          if (_chaussees.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  '❌ Aucune chaussée enregistrée',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _chaussees.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final chaussee = _chaussees[index];
                return _buildChausseeItem(chaussee);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChausseeItem(ChausseeModel chaussee) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFFFF9800),
        child: Text(
          '${chaussee.id}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text(
        chaussee.codePiste,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🏷️ GPS: ${chaussee.codeGps}',
            style: const TextStyle(fontSize: 12),
          ),
          Text(
            '📍 ${chaussee.endroit}',
            style: const TextStyle(fontSize: 12),
          ),
          if (chaussee.typeChaussee != null)
            Text(
              '🛣️ ${chaussee.typeChaussee}',
              style: const TextStyle(fontSize: 12),
            ),
          Text(
            '🕐 ${_formatDate(chaussee.createdAt)}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.straighten,
            color: Color(0xFFFF9800),
            size: 16,
          ),
          Text(
            '${(chaussee.distanceTotaleM / 1000).toStringAsFixed(1)}km',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFFF9800),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateString;
    }
  }
}
