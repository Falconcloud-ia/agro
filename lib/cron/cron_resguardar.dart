import 'package:workmanager/workmanager.dart';
import 'package:firebase_core/firebase_core.dart';
import '../services/firestore_hive_sync_service.dart';
import '../firebase_options.dart';

const String cronTaskName = 'resguardarCiudadCron';

Future<void> initializeCron() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true,
  );

  await Workmanager().registerPeriodicTask(
    cronTaskName,
    cronTaskName,
    frequency: const Duration(hours: 1),
  );
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('Ejecutando tarea cron: $task');

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirestoreHiveSyncService().syncFirestoreToHive();

    print('Tarea cron finalizada: $task');
    return Future.value(true);
  });
}
