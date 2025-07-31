/* import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:workmanager/workmanager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../config/hive_config.dart';
import '../../firebase_options.dart';
import '../../services/firestore_hive_sync_service.dart';
import '../../services/hive_firestore_sync_service.dart';

/// Verifica si hay conexión real a internet y si es de tipo aceptable (Wi-Fi o al menos 4G)
Future<bool> conexionAceptable() async {
  final resultado = await Connectivity().checkConnectivity();

  // Rechaza si no hay conexión
  if (resultado == ConnectivityResult.none) return false;

  // Acepta Wi-Fi sin más validaciones
  if (resultado == ConnectivityResult.wifi) return true;

  // Si es móvil, verificamos si hay acceso real a internet
  if (resultado == ConnectivityResult.mobile) {
    try {
      final lookup = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));

      if (lookup.isEmpty || lookup[0].rawAddress.isEmpty) return false;

      // Si respondió google.com, asumimos conexión decente (4G+).
      return true;
    } catch (_) {
      return false;
    }
  }

  // Para cualquier otro caso, asumimos que no es aceptable
  return false;
}

@pragma('vm:entry-point')
void backgroundCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('''
      ============================
      📦 INICIO PROCESO BACKGROUND
      🔧 Tarea: $task
      🕒 Fecha/Hora: ${DateTime.now()}
      ============================
    ''');

    try {
      final redBuena = await conexionAceptable();
      if (!redBuena) {
        print('⛔ Sincronización cancelada: conexión no aceptable');
        return false;
      }

      // Inicializar Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Inicializar Hive
      final dir = await path_provider.getApplicationDocumentsDirectory();
      Hive.init(dir.path);
      await HiveConfig.openBoxes();

      final configBox = Hive.box('sync_local');
      final hiveToCloud = HiveToFirestoreSyncService();
      final cloudToHive = FirestoreToHiveSyncService();

      await hiveToCloud.sync(); // SYNC2

      final huboErrores = configBox.get('sync2_failed', defaultValue: true);
      if (!huboErrores) {
        print('🚿 Ejecutando SYNC1: Firestore → Hive');
        await cloudToHive.sync(); // SYNC1
      } else {
        print('⛔ SYNC1 omitido por errores en SYNC2');
      }

      return true;
    } catch (e, stack) {
      print('❌ Error en backgroundCallbackDispatcher: $e\n$stack');
      return false;
    }
  });
}
*/