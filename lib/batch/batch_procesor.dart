import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:workmanager/workmanager.dart';
import 'package:network_info_plus/network_info_plus.dart';

import '../../config/hive_config.dart';
import '../../firebase_options.dart';
import '../../services/firestore_hive_sync_service.dart';
import '../../services/hive_firestore_sync_service.dart';

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
      // Inicializar Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // 🔹 Inicializar Hive con path manual
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
