import 'package:controlgestionagro/services/firestore_hive_sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'config/hive_config.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Future.microtask(() async {
    print('⏰ Ejecutando tarea periódica...');
    try {
      // 🟢 Inicializa Firebase
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // 🟢 Inicializa Hive
      await HiveConfig.init();
      //await Hive.initFlutter(); // si ya usas HiveConfig puedes llamarlo también

      // Ejecuta sincronización
      final syncService = FirestoreHiveSyncService();
      await syncService.syncFirestoreToHive();
    } catch (e) {
      print('❌ Error en background task: $e');
    }
  });
}



//ANDROID NETWORKING VALIDATION ANV
/*
import 'package:mobile_network_type/mobile_network_type.dart';
Future<bool> esConexionMovilEstable() async {
  final networkType = await MobileNetworkType().getNetworkType();

  print('📶 Tipo de red detectada: $networkType');
  return networkType == 'LTE' || networkType == '4G' || networkType == '5G';

  -> sync_processor
}
 */


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
