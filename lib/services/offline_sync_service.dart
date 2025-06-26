import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:controlgestionagro/models/tratamiento_local.dart';
import 'package:controlgestionagro/data/hive_repository.dart';
import 'package:hive/hive.dart';

class OfflineSyncService {
  final HiveRepository _hive = HiveRepository();
  final _firestore = FirebaseFirestore.instance;

  Box get _box => _hive.box('offline_data');

  Future<void> guardarLocal(TratamientoLocal data) async {
    await _box.add(data.toMap());
  }

  Future<void> sincronizar() async {
    final int length = _box.length;
    for (int i = 0; i < length; i++) {
      final map = _box.getAt(i);
      if (map == null) continue;

      try {
        await _firestore.collection('tratamientos').doc(map['id']).set(map);
        await _box.deleteAt(i);
      } catch (e) {
        print('❌ Error al sincronizar: $e');
      }
    }
  }

  List<TratamientoLocal> obtenerPendientes() {
    return _box.values
        .map((e) => TratamientoLocal.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }
}
