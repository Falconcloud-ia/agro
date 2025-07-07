import 'package:hive/hive.dart';

class HiveSyncUtils {
  static Future<void> marcarComoModificadoSoloOffline(Box box, dynamic key, Map<String, dynamic> data) async {
    final newData = {...data, 'flag_sync': true};
    await box.put(key, newData);
    await _activarFlagGlobal();
  }

  static Future<void> _activarFlagGlobal() async {//TODO: si y solo si, intentó subir a firestore, la acción no fue posible y se guardo en hive
    final syncBox = Hive.box('sync_local');
    await syncBox.put('hasDataToSync', true);
  }

  static Future<void> desactivarFlagGlobal() async {
    final syncBox = Hive.box('sync_local');
    await syncBox.put('hasDataToSync', false);
  }

  static bool hayDatosParaSincronizar() {
    final syncBox = Hive.box('sync_local');
    return syncBox.get('hasDataToSync', defaultValue: false) == true;
  }
}

//TODO: Calcula tiempo sync > 20 nim
