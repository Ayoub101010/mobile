import 'package:flutter/material.dart';
import '../../data/remote/api_service.dart';
import '../../data/local/database_helper.dart';

class DataListView extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final String entityType;
  final String dataFilter;
  final Function(Map<String, dynamic>) onEdit;
  final Function(int) onDelete;
  final void Function(Map<String, dynamic> item)? onView;

  const DataListView({
    super.key,
    required this.data,
    required this.entityType,
    required this.dataFilter,
    required this.onEdit,
    required this.onDelete,
    this.onView,
  });

  @override
  State<DataListView> createState() => _DataListViewState();
}

class _DataListViewState extends State<DataListView> {
  late List<Map<String, dynamic>> _filteredData;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String> _dateCache = {};

  late Future<_AdminNames> _adminFuture;

  @override
  void initState() {
    super.initState();
    _filteredData = widget.data;
    _searchController.addListener(_filterData);

    _adminFuture = _loadAdminNames(); // ✅ une seule fois, offline-friendly
  }

  @override
  void didUpdateWidget(DataListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _filterData();
    }
  }

  Future<_AdminNames> _loadAdminNames() async {
    // 1) si ApiService déjà rempli (ex: après login)
    final r1 = ApiService.regionNom?.toString().trim() ?? '';
    final p1 = ApiService.prefectureNom?.toString().trim() ?? '';
    final c1 = ApiService.communeNom?.toString().trim() ?? '';

    if (r1.isNotEmpty || p1.isNotEmpty || c1.isNotEmpty) {
      return _AdminNames(
        region: r1.isEmpty ? '----' : r1,
        prefecture: p1.isEmpty ? '----' : p1,
        commune: c1.isEmpty ? '----' : c1,
      );
    }

    // 2) sinon: lire depuis SQLite users (offline)
    final user = await DatabaseHelper().getCurrentUser();
    final r2 = (user?['region_nom'] ?? '').toString().trim();
    final p2 = (user?['prefecture_nom'] ?? '').toString().trim();
    final c2 = (user?['commune_nom'] ?? '').toString().trim();

    return _AdminNames(
      region: r2.isEmpty ? '----' : r2,
      prefecture: p2.isEmpty ? '----' : p2,
      commune: c2.isEmpty ? '----' : c2,
    );
  }

  void _filterData() {
    final query = _searchController.text.toLowerCase().trim();

    if (query.isEmpty) {
      setState(() => _filteredData = widget.data);
    } else {
      setState(() {
        _filteredData = widget.data.where((item) {
          final nom = item['nom']?.toString().toLowerCase() ?? '';
          final type = item['type']?.toString().toLowerCase() ?? '';
          final codePiste = item['code_piste']?.toString().toLowerCase() ?? '';
          return nom.contains(query) || type.contains(query) || codePiste.contains(query);
        }).toList();
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(child: _buildDataList()),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Rechercher par nom, type ou code piste...',
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
        onChanged: (_) => _filterData(),
      ),
    );
  }

  Widget _buildDataList() {
    if (_filteredData.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty ? 'Aucune donnée ${_getFilterText()}' : 'Aucun résultat pour "${_searchController.text}"',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredData.length,
      itemBuilder: (context, index) {
        final item = _filteredData[index];
        return _buildListItem(item, context);
      },
    );
  }

  String _getFilterText() {
    switch (widget.dataFilter) {
      case "unsynced":
        return "enregistrée localement";
      case "synced":
        return "synchronisée";
      case "saved":
        return "sauvegardée";
      default:
        return "";
    }
  }

  Widget _buildListItem(Map<String, dynamic> item, BuildContext context) {
    final hasModification = item['updated_at'] != null && item['updated_at'] != item['created_at'];
    final isChaussee = widget.entityType == "Chaussées";
    final titleText = isChaussee ? 'Chaussée – ${(item['type_chaussee'] ?? item['type'] ?? '—')} (#${item['id'] ?? '—'})' : (item['nom'] ?? item['code_piste'] ?? 'Sans nom').toString();
    return Card(
      elevation: 0.8, // au lieu de default / gros shadow
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item['code_piste'] != null) Text('Code: ${item['code_piste']}'),
            if (item['type'] != null) Text('Type: ${item['type']}'),

            if (item['created_at'] != null) Text('Créé: ${_formatDate(item['created_at'])}'),

            if (hasModification)
              Text(
                'Modifié: ${_formatDate(item['updated_at'])}',
                style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
              ),

            // (Optionnel) tu peux supprimer cette ligne si tu ne veux plus afficher l'id
            if (item['commune_id'] != null) Text('Commune ID: ${item['commune_id']}'),

            item['synced'] == 1
                ? const Text('Status: Synchronisé ✅', style: TextStyle(color: Colors.green))
                : item['downloaded'] == 1
                    ? const Text('Status: Téléchargé 📥', style: TextStyle(color: Colors.blue))
                    : const Text('Status: Non synchronisé ⏳', style: TextStyle(color: Colors.orange)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.onView != null)
              IconButton(
                tooltip: 'Voir sur la carte',
                icon: const Icon(Icons.remove_red_eye_outlined),
                onPressed: () {
                  final itemCopy = Map<String, dynamic>.from(item);
                  widget.onView?.call(itemCopy);
                },
              ),
            if (widget.dataFilter == "unsynced") ...[
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue),
                onPressed: () => widget.onEdit(item),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => _confirmDelete(item['id'], context),
              ),
            ],
          ],
        ),
        onTap: () => _showDetails(item, context),
      ),
    );
  }

  void _confirmDelete(int id, BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer cet élément ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete(id);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _showDetails(Map<String, dynamic> item, BuildContext context) {
    // ✅ Champs techniques à cacher (backend only)
    const hiddenKeys = {
      'points_json',
      'sqlite_id',
      'sync_status',
      'synced',
      'downloaded',
      'saved_by_user_id',
      'date_sync',
      'login_id',
      'created_by',
      'updated_by',
      'geom',
      'geometry',
      'wkt',

      // si jamais ils existent dans certains records
      'commune_nom',
      'prefecture_nom',
      'region_nom',
      'prefecture_id',
      'region_id',

      // ✅ on ne veut plus afficher commune_id dans Détails
      'commune_id',
      'commune_rurale_id',
      'communes_rurales',
      'communes_rurales_id',
    };

    bool isHidden(String key) {
      final k = key.toLowerCase();
      if (hiddenKeys.contains(key)) return true;
      if (k.contains('password') || k.contains('token')) return true;
      if (k.endsWith('_json')) return true;
      return false;
    }

    String groupOf(String key) {
      final k = key.toLowerCase();

      // Localisation (points)
      if (k.contains('lat') || k.contains('lon') || k == 'x' || k == 'y' || k.contains('coord') || k.contains('longitude') || k.contains('latitude')) {
        return 'Localisation';
      }

      // Administration / rattachements
      if (k.contains('commune') || k.contains('commune_rurale_id') || k.contains('code_piste') || k.contains('piste') || k.contains('region') || k.contains('prefecture')) {
        return 'Administration';
      }

      if (k.contains('origine') || k.contains('_origine')) return 'Origine';
      if (k.contains('destination') || k.contains('_destination')) return 'Destination';
      if (k.contains('intersection') || k.contains('_intersection')) return 'Intersection';

      if (k.contains('occupation') || k.contains('type_occupation') || k.contains('debut_occupation') || k.contains('fin_occupation')) {
        return 'Occupation';
      }

      if (k.contains('trafic') || k.contains('type_trafic') || k.contains('frequence_trafic')) {
        return 'Trafic';
      }

      if (k.contains('date') || k.endsWith('_at')) return 'Dates';

      return 'Général';
    }

    final entries = item.entries.where((e) => e.value != null && !isHidden(e.key)).toList();

    const order = {
      'Général': 0,
      'Administration': 1,
      'Localisation': 2,
      'Origine': 3,
      'Destination': 4,
      'Intersection': 5,
      'Occupation': 6,
      'Trafic': 7,
      'Dates': 8,
    };

    entries.sort((a, b) {
      final ga = groupOf(a.key);
      final gb = groupOf(b.key);
      final oa = order[ga] ?? 99;
      final ob = order[gb] ?? 99;
      if (oa != ob) return oa.compareTo(ob);
      return _getFieldLabel(a.key).compareTo(_getFieldLabel(b.key));
    });

    final Map<String, List<MapEntry<String, dynamic>>> grouped = {};
    for (final e in entries) {
      final g = groupOf(e.key);
      grouped.putIfAbsent(g, () => []);
      grouped[g]!.add(e);
    }

    // ✅ Injecter region/prefecture/commune (3 lignes) dans Administration
    grouped.putIfAbsent('Administration', () => []);
    grouped['Administration']!.insertAll(0, const [
      MapEntry('__region__', ''),
      MapEntry('__prefecture__', ''),
      MapEntry('__commune__', ''),
    ]);

    Widget rowItem(String label, String value) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(
                value.isEmpty ? '—' : value,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget section(String title, List<MapEntry<String, dynamic>> list) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: list.map((e) {
                // ✅ 3 lignes Administration (region/pref/commune) -> toutes les données
                if (e.key == '__region__' || e.key == '__prefecture__' || e.key == '__commune__') {
                  final label = e.key == '__region__'
                      ? 'Région'
                      : e.key == '__prefecture__'
                          ? 'Préfecture'
                          : 'Commune';

                  return FutureBuilder<_AdminNames>(
                    future: _adminFuture,
                    builder: (context, snap) {
                      final admin = snap.data ?? const _AdminNames(region: '----', prefecture: '----', commune: '----');

                      final value = e.key == '__region__'
                          ? admin.region
                          : e.key == '__prefecture__'
                              ? admin.prefecture
                              : admin.commune;

                      return Column(
                        children: [
                          rowItem(label, value),
                          Divider(height: 1, color: Colors.grey[300]),
                        ],
                      );
                    },
                  );
                }

                final label = _getFieldLabel(e.key);
                final value = _formatValue(e.value, e.key);

                return Column(
                  children: [
                    rowItem(label, value),
                    Divider(height: 1, color: Colors.grey[300]),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 520,
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('Détails', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: grouped.entries.map((g) => section(g.key, g.value)).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getFieldLabel(String key) {
    final labels = {
      'code_piste': 'Code Piste',
      'commune_rurale_id': 'Commune',
      'user_login': 'Utilisateur',
      'heure_debut': 'Heure Début',
      'heure_fin': 'Heure Fin',
      'created_at': 'Date Création',
      'updated_at': 'Date Modification',
      'nom_origine_piste': 'Origine',
      'nom_destination_piste': 'Destination',
      'type_occupation': 'Type Occupation',
      'enqueteur': 'Enquêteur',
      'id': 'ID',
      'nom': 'Nom',
      'type': 'Type',
      'x_localite': 'Longitude (X)',
      'y_localite': 'Latitude (Y)',
      // ajoute ici les autres si tu veux
    };

    return labels[key] ?? key;
  }

  String _formatValue(dynamic value, String key) {
    // ✅ Cas spécial enquêteur
    if (key == 'enqueteur') {
      if (value == null || value.toString().trim().isEmpty) return '----';
      final v = value.toString();
      if (v == '0' || v == '1' || v.toLowerCase().contains('sync')) return '----';
      return v;
    }

    if (value == null) return '----';

    if (key.contains('date') || key.contains('_at')) {
      return _formatDate(value.toString());
    }

    if (value is DateTime) {
      return _formatDate(value.toString());
    }
// ✅ Format coordonnées : limiter à 7 décimales
    final k = key.toLowerCase();
    final isCoord = k.startsWith('x_') || k.startsWith('y_') || k.contains('latitude') || k.contains('longitude') || k.contains('lat') || k.contains('lon');

    if (isCoord) {
      final d = double.tryParse(value.toString());
      if (d != null) return d.toStringAsFixed(7);
    }

    final s = value.toString().trim();
    return s.isEmpty ? '----' : s;
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '----';
    if (_dateCache.containsKey(dateString)) return _dateCache[dateString]!;

    String out;
    try {
      final date = DateTime.parse(dateString);
      out = '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      out = dateString;
    }

    _dateCache[dateString] = out;
    return out;
  }
}

class _AdminNames {
  final String region;
  final String prefecture;
  final String commune;

  const _AdminNames({
    required this.region,
    required this.prefecture,
    required this.commune,
  });
}
