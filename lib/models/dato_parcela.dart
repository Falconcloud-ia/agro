class DatoParcela {
  final int numeroFicha;
  final DateTime? fechaCosecha;
  final String nombreSerie;
  final String nombreCiudad;
  final num superficie;

  final String nombreBloque;
  final int numeroTratamiento;
  final double pesoRaices;
  final String pesoHojas;
  final String ndvi;
  final String observaciones;
  final List<int> frecuenciaNotas;

  final int raicesA;
  final int raicesB;

  DatoParcela({
    required this.numeroFicha,
    required this.fechaCosecha,
    required this.nombreSerie,
    required this.nombreCiudad,
    required this.superficie,
    required this.nombreBloque,
    required this.numeroTratamiento,
    required this.pesoRaices,
    required this.pesoHojas,
    required this.ndvi,
    required this.observaciones,
    required this.frecuenciaNotas,
    required this.raicesA,
    required this.raicesB,
  });

  int get totalRaices => raicesA + raicesB;
}
