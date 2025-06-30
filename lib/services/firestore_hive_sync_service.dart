import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../data/hive_repository.dart';

final FirebaseFirestore _firestore = FirebaseFirestore.instance;
final HiveRepository _hive = HiveRepository();

final Box _ciudadesBox = _hive.box('offline_ciudades');
final Box _seriesBox = _hive.box('offline_series');
final Box _bloquesBox = _hive.box('offline_bloques');
final Box _parcelasBox = _hive.box('offline_parcelas');
final Box _tratamientosBox = _hive.box('offline_tratamientos');
final Box _usuarioBox = _hive.box('offline_user');

/// 🔄 Inicia la sincronización completa de Firestore hacia Hive.
Future<void> syncFirestoreToHive() async {
  try {
    print('📡 Iniciando sincronización Firestore → Hive...');
    final ciudades = await _firestore.collection('ciudades').get();

    for (final ciudad in ciudades.docs) {
      await _resguardarCiudad(ciudad);
    }

    print('✅ Sincronización completa');
  } catch (e) {
    print('❌ Error general en syncFirestoreToHive: $e');
  }
}

Future<void> _resguardarCiudad(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
  final ciudadId = doc.id;
  final data = _convertTimestampsToDateTime(doc.data());

  await _ciudadesBox.put(ciudadId, data);
  print('🌆 data from firestore Ciudad: $ciudadId → ${data['nombre']}');

  try {
    final series = await doc.reference.collection('series').get();
    for (final serie in series.docs) {
      await _resguardarSerie(ciudadId, serie);
    }
  } catch (e) {
    print('❌ Error obteniendo series de $ciudadId: $e');
  }
}

Future<void> _resguardarSerie(
    String ciudadId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) async {
  final serieId = doc.id;
  final data = {
    ..._convertTimestampsToDateTime(doc.data()),
    'ciudadId': ciudadId,
    'serieId': serieId,
    'flag_sync': false,
  };

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

Future<void> _resguardarBloque(
    String ciudadId,
    String serieId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) async {
  final bloqueId = doc.id;
  final data = {
    ..._convertTimestampsToDateTime(doc.data()),
    'ciudadId': ciudadId,
    'serieId': serieId,
    'bloqueId': bloqueId,
    'flag_sync': false,
  };

  await _bloquesBox.put('${ciudadId}_${serieId}_$bloqueId', data);

  try {
    final parcelas = await doc.reference.collection('parcelas').get();
    for (final parcela in parcelas.docs) {
      await _resguardarParcela(ciudadId, serieId, bloqueId, parcela);
    }
  } catch (e) {
    print('❌ Error obteniendo parcelas de $bloqueId: $e');
  }
}

Future<void> _resguardarParcela(
    String ciudadId,
    String serieId,
    String bloqueId,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) async {
  final parcelaId = doc.id;
  final data = {
    ...doc.data(),
    'ciudadId': ciudadId,
    'serieId': serieId,
    'bloqueId': bloqueId,
    'flag_sync': false,
  };

  await _parcelasBox.put('${ciudadId}_${serieId}_${bloqueId}_$parcelaId', data);

  try {
    final tratamientos = await doc.reference.collection('tratamientos').get();
    for (final tr in tratamientos.docs) {
      final tratamientoData = {
        ..._convertTimestampsToDateTime(tr.data()),
        'ciudadId': ciudadId,
        'serieId': serieId,
        'bloqueId': bloqueId,
        'parcelaId': parcelaId,
        'flag_sync': false,
      };
      await _tratamientosBox.put(
        '${ciudadId}_${serieId}_${bloqueId}_$parcelaId',
        tratamientoData,
      );
    }
  } catch (e) {
    print('❌ Error obteniendo tratamientos de $parcelaId: $e');
  }
}

Map<String, dynamic> _convertTimestampsToDateTime(Map<String, dynamic> data) {
  return data.map((key, value) {
    if (value is Timestamp) {
      return MapEntry(key, value.toDate());
    }
    return MapEntry(key, value);
  });
}
