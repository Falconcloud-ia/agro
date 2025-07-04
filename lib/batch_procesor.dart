import 'package:controlgestionagro/services/firestore_hive_sync_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:network_type_reachability/network_type_reachability.dart';
import 'package:flutter/material.dart';

import 'config/hive_config.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Future.microtask(() async {
    print('⏰ Ejecutando tarea periódica...');

    final isStableConnection = await esConexionMovilEstable();
    if(isStableConnection) {
      try {
        // 🟢 Inicializa Firebase
        await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform);

        // 🟢 Inicializa Hive
        await HiveConfig.init();
        //await Hive.initFlutter(); // si ya usas HiveConfig puedes llamarlo también

        // Ejecuta sincronización
        final syncService = FirestoreHiveSyncService();
        await syncService.syncFirestoreToHive();
      } catch (e) {
        print('❌ Error en background task: $e');
      }
    }
  });
}



// ANDROID NETWORKING VALIDATION ANV
Future<bool> esConexionMovilEstable() async {
  final networkStatus = await NetworkTypeReachability;
  print('📶 Tipo de red detectada: $networkStatus');
  return networkStatus == NetworkStatus.moblie4G ||
      networkStatus == NetworkStatus.moblie5G ||
      networkStatus == NetworkStatus.wifi;

}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
