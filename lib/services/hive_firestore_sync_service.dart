import 'package:cloud_firestore/cloud_firestore.dart';

import 'base_sync_service.dart';

class HiveToFirestoreSyncService extends BaseSyncService {
  Future<void> sync() async {
    try {
      print('☁️ Iniciando subida Hive → Firestore...');

      await _syncSeries();
      await _syncBloques();
      await _syncParcelas();
      await _syncTratamientos();

      print('✅ Subida de datos completa');
    } catch (e) {
      print('❌ Error en syncHiveToFirestore: $e');
    }
  }

  Future<void> _syncSeries() async {
    for (final key in seriesBox.keys) {
      final data = Map<String, dynamic>.from(seriesBox.get(key));
      if (data['flag_sync'] != true) continue;

      final ciudadId = data['ciudadId'];
      final serieId = data['serieId'];
      if (ciudadId == null || serieId == null) continue;

      final filtered = {...data}..remove('flag_sync');

      try {
        final docRef = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadId)
            .collection('series')
            .doc(serieId);

        await docRef.set(filtered, SetOptions(merge: true));
        print('✅ series/$serieId sincronizado');
      } catch (e) {
        print('❌ Error subiendo series/$serieId → $e');
      }
    }
  }

  Future<void> _syncBloques() async {
    for (final key in bloquesBox.keys) {
      final data = Map<String, dynamic>.from(bloquesBox.get(key));
      if (data['flag_sync'] != true) continue;

      final ciudadId = data['ciudadId'];
      final serieId = data['serieId'];
      final bloqueId = data['bloqueId'];
      if (ciudadId == null || serieId == null || bloqueId == null) continue;

      final filtered = {...data}..remove('flag_sync');

      try {
        final docRef = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadId)
            .collection('series')
            .doc(serieId)
            .collection('bloques')
            .doc(bloqueId);

        await docRef.set(filtered, SetOptions(merge: true));
        print('✅ bloques/$bloqueId sincronizado');
      } catch (e) {
        print('❌ Error subiendo bloques/$bloqueId → $e');
      }
    }
  }

  Future<void> _syncParcelas() async {
    for (final key in parcelasBox.keys) {
      final data = Map<String, dynamic>.from(parcelasBox.get(key));
      if (data['flag_sync'] != true) continue;

      final ciudadId = data['ciudadId'];
      final serieId = data['serieId'];
      final bloqueId = data['bloqueId'];
      final parcelaId = data['parcelaId'];
      if ([ciudadId, serieId, bloqueId, parcelaId].contains(null)) continue;

      final filtered = {...data}..remove('flag_sync');

      try {
        final docRef = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadId)
            .collection('series')
            .doc(serieId)
            .collection('bloques')
            .doc(bloqueId)
            .collection('parcelas')
            .doc(parcelaId);

        await docRef.set(filtered, SetOptions(merge: true));
        print('✅ parcelas/$parcelaId sincronizado');
      } catch (e) {
        print('❌ Error subiendo parcelas/$parcelaId → $e');
      }
    }
  }

  Future<void> _syncTratamientos() async {
    for (final key in tratamientosBox.keys) {
      final data = Map<String, dynamic>.from(tratamientosBox.get(key));
      if (data['flag_sync'] != true) continue;

      final ciudadId = data['ciudadId'];
      final serieId = data['serieId'];
      final bloqueId = data['bloqueId'];
      final parcelaId = data['parcelaId'];
      final tratamientoId = data['id'];
      if ([
        ciudadId,
        serieId,
        bloqueId,
        parcelaId,
        tratamientoId,
      ].contains(null))
        continue;

      final filtered = {...data}..remove('flag_sync');

      try {
        final docRef = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadId)
            .collection('series')
            .doc(serieId)
            .collection('bloques')
            .doc(bloqueId)
            .collection('parcelas')
            .doc(parcelaId)
            .collection('tratamientos')
            .doc(tratamientoId);

        await docRef.set(filtered, SetOptions(merge: true));
        print('✅ tratamientos/$tratamientoId sincronizado');
      } catch (e) {
        print('❌ Error subiendo tratamientos/$tratamientoId → $e');
      }
    }
  }
}
