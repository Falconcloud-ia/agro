class TratamientoLocal {
  final String id;
  final String ciudadId;
  final String serieId;
  final String bloqueId;
  final String parcelaId;
  final int numeroRaices;
  final DateTime fecha;

  TratamientoLocal({
    required this.id,
    required this.ciudadId,
    required this.serieId,
    required this.bloqueId,
    required this.parcelaId,
    required this.numeroRaices,
    required this.fecha,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'ciudadId': ciudadId,
    'serieId': serieId,
    'bloqueId': bloqueId,
    'parcelaId': parcelaId,
    'numeroRaices': numeroRaices,
    'fecha': fecha.toIso8601String(),
  };

  static TratamientoLocal fromMap(Map<String, dynamic> map) => TratamientoLocal(
    id: map['id'],
    ciudadId: map['ciudadId'],
    serieId: map['serieId'],
    bloqueId: map['bloqueId'],
    parcelaId: map['parcelaId'],
    numeroRaices: map['numeroRaices'],
    fecha: DateTime.parse(map['fecha']),
  );
}
