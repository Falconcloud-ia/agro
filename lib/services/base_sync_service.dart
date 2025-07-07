import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import '../data/hive_repository.dart';

abstract class BaseSyncService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final HiveRepository hive = HiveRepository();

  Box get ciudadesBox => hive.box('offline_ciudades');
  Box get seriesBox => hive.box('offline_series');
  Box get bloquesBox => hive.box('offline_bloques');
  Box get parcelasBox => hive.box('offline_parcelas');
  Box get tratamientosBox => hive.box('offline_tratamientos');
  Box get usuarioBox => hive.box('offline_data');

  Map<String, dynamic> convertTimestamps(Map<String, dynamic> data) {
    return data.map((key, value) =>
    value is Timestamp ? MapEntry(key, value.toDate()) : MapEntry(key, value));
  }
}