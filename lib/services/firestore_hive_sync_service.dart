import 'package:cloud_firestore/cloud_firestore.dart';

import 'base_sync_service.dart';

class FirestoreToHiveSyncService extends BaseSyncService {
  Future<void> sync() async {
    try {
      print('📡 Iniciando sincronización Firestore → Hive...');
      final ciudades = await firestore.collection('ciudades').get();

      for (final ciudad in ciudades.docs) {
       if(ciudad.id == "cVV0Ei7c3iWli6SdTvqK") {
          await _resguardarCiudad(ciudad);
        }
      }

      print('✅ Sincronización completa');
    } catch (e) {
      print('❌ Error general en syncFirestoreToHive: $e');
    }
  }

  Future<void> _resguardarCiudad(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final ciudadId = doc.id;
    final data = convertTimestamps(doc.data());

    await ciudadesBox.put(ciudadId, {...data});
    print('🌆 Ciudad guardada: $ciudadId');

    final series = await doc.reference.collection('series').get();
    for (final serie in series.docs) {
      await _resguardarSerie(ciudadId, serie);
    }
  }

  Future<void> _resguardarSerie(String ciudadId, QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final serieId = doc.id;
    final data = {
      ...convertTimestamps(doc.data()),
      'ciudadId': ciudadId,
      'serieId': serieId,
      'flag_sync': false,
    };
    await seriesBox.put('${ciudadId}_$serieId', data);

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
    final data = {
      ...convertTimestamps(doc.data()),
      'ciudadId': ciudadId,
      'serieId': serieId,
      'bloqueId': bloqueId,
      'flag_sync': false,
    };
    await bloquesBox.put('${ciudadId}_${serieId}_$bloqueId', data);

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
      ...convertTimestamps(doc.data()),
      'ciudadId': ciudadId,
      'serieId': serieId,
      'bloqueId': bloqueId,
      'parcelaId': parcelaId,
      'flag_sync': false,
    };
    await parcelasBox.put('${ciudadId}_${serieId}_${bloqueId}_$parcelaId', data);

    final tratamientos = await doc.reference.collection('tratamientos').get();
    for (final tr in tratamientos.docs) {
      final trData = {
        ...convertTimestamps(tr.data()),
        'ciudadId': ciudadId,
        'serieId': serieId,
        'bloqueId': bloqueId,
        'parcelaId': parcelaId,
        'tratamientoId': tr.id,
        'flag_sync': false,
      };
      await tratamientosBox.put('${ciudadId}_${serieId}_${bloqueId}_$parcelaId', trData);
    }
  }
}