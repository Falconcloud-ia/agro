import 'package:hive/hive.dart';

/// Capa de acceso a datos basada en Hive.
class HiveRepository {
  static final HiveRepository _instance = HiveRepository._internal();
  factory HiveRepository() => _instance;
  HiveRepository._internal();

  Box _box(String name) => Hive.box(name);

  /// Devuelve la caja para usos avanzados.
  Box box(String name) => _box(name);

  /// Obtiene un valor tal cual está almacenado.
  dynamic get(String box, dynamic key) => _box(box).get(key);

  /// Persiste un valor en la caja indicada.
  Future<void> put(String box, dynamic key, dynamic value) async {
    await _box(box).put(key, value);
  }

  /// Devuelve una lista o una lista vacía si la clave no existe.
  List<dynamic> getList(String box, String key) {
    final value = _box(box).get(key);
    return value != null ? List<dynamic>.from(value as List) : <dynamic>[];
  }

  /// Devuelve un mapa o null si no existe.
  Map<String, dynamic>? getMap(String box, String key) {
    final value = _box(box).get(key);
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return null;
  }
}
