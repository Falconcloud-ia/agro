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

      //Inicia proceso sync
      //valida fecha-hora ultima actualización
          //if(now() - lastSyncDate(tabla config hive) > 30 min){
              //if( box.sync_local.hasDataToSync == true){
                  //comienza proceso subida datos hive a cloud
              //}

              //siempre ->  Ejecuta sync1
              final syncService = FirestoreHiveSyncService();
              await syncService.syncFirestoreToHive();

    } catch (e) {
      print('❌ Error en background task: $e');
    }
  });
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
