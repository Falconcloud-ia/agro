/// Callback que se ejecuta desde un `AlarmManager` en Android.
///
/// Cada vez que el `AlarmManager` dispara (una vez por minuto) se invoca este
/// código, incluso cuando la aplicación no está en primer plano. Aquí se
/// delega la sincronización completa de Firestore hacia Hive.
import 'package:controlgestionagro/services/firestore_hive_sync_service.dart';

void backgroundCallbackDispatcher() {
  print('⏰ Ejecutando proceso batch');
  syncFirestoreToHive();
}


