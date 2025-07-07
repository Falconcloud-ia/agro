import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

import 'base_sync_service.dart';

class HiveToFirestoreSyncService extends BaseSyncService {
  /// Inicia la sincronización de subida desde Hive hacia Firestore
  Future<void> sync() async {
    try {
      print('☁️ Iniciando subida Hive → Firestore...');

      await _subirDatos(ciudadesBox, 'ciudades');
      await _subirDatos(seriesBox, 'series', ['ciudadId']);
      await _subirDatos(bloquesBox, 'bloques', ['ciudadId', 'serieId']);
      await _subirDatos(parcelasBox, 'parcelas', ['ciudadId', 'serieId', 'bloqueId']);
      await _subirDatos(tratamientosBox, 'tratamientos', ['ciudadId', 'serieId', 'bloqueId', 'parcelaId']);

      print('✅ Subida de datos completa');
    } catch (e) {
      print('❌ Error en syncHiveToFirestore: $e');
    }
  }

  /// Sube todos los documentos con flag_sync = true
  Future<void> _subirDatos(Box box, String collectionName, [List<String> parentKeys = const []]) async {
    for (final key in box.keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      final data = Map<String, dynamic>.from(raw);
      if (data['flag_sync'] != true) continue;

      try {
        // Referencia inicial
        DocumentReference ref = firestore.collection('ciudades').doc(data['ciudadId']);

        // Encadenamiento a subcolecciones si corresponde
        for (int i = 1; i < parentKeys.length; i++) {
          final parentKey = parentKeys[i];
          ref = ref.collection(parentKey).doc(data[parentKey]);
        }

        // Determina ID del documento (ej: ciudadId, serieId, etc.)
        final docIdKey = '${collectionName.substring(0, collectionName.length - 1)}Id';
        ref = ref.collection(collectionName).doc(data[docIdKey]);

        // Subida del documento sin el flag_sync
        final dataToUpload = Map<String, dynamic>.from(data)..remove('flag_sync');
        await ref.set(dataToUpload, SetOptions(merge: true));

        // Actualiza localmente como sincronizado
        await box.put(key, {...data, 'flag_sync': false});

        print('☁️ Subido $collectionName → $key');
      } catch (e) {
        print('⚠️ Error subiendo $collectionName → $key: $e');
      }
    }
  }
}
