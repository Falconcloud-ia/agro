import 'package:hive_flutter/hive_flutter.dart';

/// Configuración centralizada de Hive.
class HiveConfig {
  /// Inicializa Hive y abre las cajas necesarias.
  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('offline_data'),
      Hive.openBox('user_data'),
      Hive.openBox('offline_user'),
      Hive.openBox('offline_ciudades'),
      Hive.openBox('offline_series'),
      Hive.openBox('offline_bloques'),
      Hive.openBox('offline_parcelas'),
      Hive.openBox('offline_tratamientos'),
    ]);
  }
}
