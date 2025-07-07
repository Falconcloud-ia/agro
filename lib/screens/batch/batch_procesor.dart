import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../config/hive_config.dart';
import '../../firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../config/hive_config.dart';
import '../../firebase_options.dart';
import '../../services/firestore_hive_sync_service.dart';
import '../../services/hive_firestore_sync_service.dart';
import '../helpers/hive_sync_utils.dart';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Future.microtask(() async {
    print('⏰ Ejecutando tarea periódica...');
    try {
      // Inicializar Firebase
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

      // Inicializar Hive
      await HiveConfig.init();

      // Acceder al box de configuración
      final configBox = Hive.box('sync_local');

      final hiveToCloud = HiveToFirestoreSyncService();
      final cloudToHive = FirestoreToHiveSyncService();

      if (esHoraDeSincronizar(configBox)) {
        if (HiveSyncUtils.hayDatosParaSincronizar()) {
          await hiveToCloud.sync(); // SYNC2
          await HiveSyncUtils.desactivarFlagGlobal(); // Reset
        }

        await cloudToHive.sync(); // SYNC1
        actualizarHoraSync(configBox);
      }

    } catch (e, stack) {
      print('❌ Error en backgroundCallbackDispatcher: $e\n$stack');
    }
  });
}

/// Verifica si han pasado al menos 30 minutos desde la última sincronización
bool esHoraDeSincronizar(Box configBox) {
  final lastSync = configBox.get('lastSync') as DateTime?;
  return lastSync == null || DateTime.now().difference(lastSync) > const Duration(minutes: 2);
}

/// Guarda el timestamp actual como último sync exitoso
void actualizarHoraSync(Box configBox) {
  configBox.put('lastSync', DateTime.now());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
