import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'config/hive_config.dart';
import 'firebase_options.dart';
import 'services/firestore_hive_sync_service.dart';

/// Callback que se ejecuta desde un `AlarmManager` en Android.
///
/// Al iniciarse cada minuto, inicializa Firebase y Hive en segundo plano
/// para luego sincronizar los datos de Firestore hacia Hive.
void backgroundCallbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();

  print('Ejecutando proceso batch');

  // Ejecutamos la sincronización de forma asíncrona para no bloquear
  // la inicialización del isolate de Flutter.
  Future(() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await HiveConfig.init();
    await syncFirestoreToHive();
  });
}

