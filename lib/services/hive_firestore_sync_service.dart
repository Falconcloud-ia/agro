import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'base_sync_service.dart';

class HiveToFirestoreSyncService extends BaseSyncService {

  Future<bool> hasConectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  Future<void> sync() async {
    bool huboFallaEnSubida = false;

    try {
      print('☁️ Iniciando subida Hive → Firestore...');

      if (await hasConectivity()) {
        final exito = await _syncSeries();
        if (!exito) huboFallaEnSubida = true;
      } else {
        print('⚠️ Sin conexión para sincronizar SERIES');
        huboFallaEnSubida = true;
      }

      if (await hasConectivity()) {
        final exito = await _syncBloques();
        if (!exito) huboFallaEnSubida = true;
      } else {
        print('⚠️ Sin conexión para sincronizar BLOQUES');
        huboFallaEnSubida = true;
      }

      if (await hasConectivity()) {
        final exito = await _syncParcelas();
        if (!exito) huboFallaEnSubida = true;
      } else {
        print('⚠️ Sin conexión para sincronizar PARCELAS - TRATAMIENTOS');
        huboFallaEnSubida = true;
      }

      final configBox = Hive.box('sync_local');
      await configBox.put('sync2_failed', huboFallaEnSubida);

      if (huboFallaEnSubida) {
        print('❌ Finalizó SYNC2 con errores.');
      } else {
        print('✅ SYNC2 completado exitosamente.');
      }

    } catch (e) {
      print('❌ Error general en sync Hive → Firestore: $e');
      final configBox = Hive.box('sync_local');
      await configBox.put('sync2_failed', true);
    }
  }

  Future<bool> _syncSeries() async {
  bool huboError = false;

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
      huboError = true;
    }
  }

  return !huboError;
}

  Future<bool> _syncBloques() async {
    bool huboError = false;
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
        huboError = true;
      }
    }
    return !huboError;
  }

  Future<bool> _syncParcelas() async {
  bool huboError = false;

   for (final key in parcelasBox.keys) {
      final data = Map<String, dynamic>.from(parcelasBox.get(key));


      final ciudadId = data['ciudadId'];
      final serieId = data['serieId'];
      final bloqueId = data['bloqueId'];
      final parcelaId = data['parcelaId'];
      if ([ciudadId, serieId, bloqueId, parcelaId].contains(null)) continue;

      bool flagSync = data['flag_sync'] == true;

      if (flagSync) {
        var filtered =
        {...data,
          'numero_ficha': data['numero_ficha'],
          'evaluacion': data['evaluacion'],
          'frecuencia_relativa': data['frecuencia_relativa']
        };
        filtered = {...data}..remove('flag_sync');

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
            print('❌ Error subiendo parcela $parcelaId → $e');
            huboError = true;
           }
      }

      final String trKey = '${ciudadId}_${serieId}_${bloqueId}_$parcelaId';
      final tratamientoHive = tratamientosBox.get(trKey);

      if (tratamientoHive != null) {
        final tratamientoMap = Map<String, dynamic>.from(tratamientoHive);
        if ((tratamientoMap['flag_sync'] ?? false) != true) continue;

        final filteredTratamiento = {...tratamientoMap}..remove('flag_sync');

        try {
          final docTrRef = FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadId)
              .collection('series')
              .doc(serieId)
              .collection('bloques')
              .doc(bloqueId)
              .collection('parcelas')
              .doc(parcelaId)
              .collection('tratamientos')
              .doc('actual');
          await docTrRef.set(filteredTratamiento, SetOptions(merge: true));

          final idTratamiento= tratamientoMap['tratamientoId'];
          print('✅ parcelas/$parcelaId con tratamiento $idTratamiento tratamiento sincronizado');
        } catch (e) {
          print('❌ Error subiendo parcelas/$parcelaId → $e');
          huboError = true;
        }
      }
    }
    return !huboError;
  }
}
