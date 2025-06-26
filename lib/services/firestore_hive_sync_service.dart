import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../data/hive_repository.dart';

/// Servicio encargado de respaldar en Hive toda la informacion de Firestore.
class FirestoreHiveSyncService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final HiveRepository _hive = HiveRepository();

  Box get _ciudadesBox => _hive.box('offline_ciudades');
  Box get _seriesBox => _hive.box('offline_series');
  Box get _bloquesBox => _hive.box('offline_bloques');
  Box get _parcelasBox => _hive.box('offline_parcelas');
  Box get _tratamientosBox => _hive.box('offline_tratamientos');

  /// Inicia la sincronizacion completa de Firestore hacia Hive.
  Future<void> syncFirestoreToHive() async {
    try {
      final ciudades = await _firestore.collection('ciudades').get();

      for (final ciudad in ciudades.docs) {
        await _resguardarCiudad(ciudad);
      }
    } catch (e) {
      // Error de conexion o permisos
      print('❌ Error general en syncFirestoreToHive: $e');
    }
  }

  Future<void> _resguardarCiudad(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ciudadId = doc.id;
    final data = doc.data();
    await _ciudadesBox.put(ciudadId, data);

    try {
      final series = await doc.reference.collection('series').get();
      for (final serie in series.docs) {
        await _resguardarSerie(ciudadId, serie);
      }
    } catch (e) {
      print('❌ Error obteniendo series de $ciudadId: $e');
    }
  }

  Future<void> _resguardarSerie(String ciudadId, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final serieId = doc.id;
    final data = {...doc.data(), 'ciudadId': ciudadId};
    await _seriesBox.put('${ciudadId}_$serieId', data);

    try {
      final bloques = await doc.reference.collection('bloques').get();
      for (final bloque in bloques.docs) {
        await _resguardarBloque(ciudadId, serieId, bloque);
      }
    } catch (e) {
      print('❌ Error obteniendo bloques de $serieId: $e');
    }
  }

  Future<void> _resguardarBloque(String ciudadId, String serieId, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final bloqueId = doc.id;
    final data = {...doc.data(), 'ciudadId': ciudadId, 'serieId': serieId};
    await _bloquesBox.put('${ciudadId}_$serieId_$bloqueId', data);

    try {
      final parcelas = await doc.reference.collection('parcelas').get();
      for (final parcela in parcelas.docs) {
        await _resguardarParcela(ciudadId, serieId, bloqueId, parcela);
      }
    } catch (e) {
      print('❌ Error obteniendo parcelas de $bloqueId: $e');
    }
  }

  Future<void> _resguardarParcela(String ciudadId, String serieId, String bloqueId, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final parcelaId = doc.id;
    final data = {
      ...doc.data(),
      'ciudadId': ciudadId,
      'serieId': serieId,
      'bloqueId': bloqueId,
    };
    await _parcelasBox.put('${ciudadId}_${serieId}_${bloqueId}_$parcelaId', data);

    try {
      final tratamiento = await doc.reference.collection('tratamientos').doc('actual').get();
      if (tratamiento.exists) {
        final tData = {
          ...?tratamiento.data(),
          'ciudadId': ciudadId,
          'serieId': serieId,
          'bloqueId': bloqueId,
          'parcelaId': parcelaId,
        };
        await _tratamientosBox.put('${ciudadId}_${serieId}_${bloqueId}_$parcelaId', tData);
      }
    } catch (e) {
      print('❌ Error obteniendo tratamiento de $parcelaId: $e');
    }
  }
}

/// Función de conveniencia para iniciar la sincronización.
Future<void> syncFirestoreToHive() {
  return FirestoreHiveSyncService().syncFirestoreToHive();
}
