import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:excel/excel.dart';

class GraficoFrecuencia extends StatefulWidget {
  const GraficoFrecuencia({super.key});

  @override
  State<GraficoFrecuencia> createState() => _GraficoFrecuenciaState();
}

class _GraficoFrecuenciaState extends State<GraficoFrecuencia> {
  String? ciudadSeleccionada;
  String? serieSeleccionada;
  String? bloqueSeleccionado;
  int? parcelaSeleccionada;

  List<QueryDocumentSnapshot> ciudades = [];
  List<QueryDocumentSnapshot> series = [];
  List<QueryDocumentSnapshot> bloques = [];
  List<int> parcelasUnicas = [];

  List<_DatoParcela> datosParcela = [];
  List<_DatoParcela> todasLasParcelas = [];
  Map<int, int> frecuenciaNotas = {};

  @override
  void initState() {
    super.initState();
    cargarCiudades();
  }

  Future<void> cargarCiudades() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('ciudades').get();
    setState(() {
      ciudades = snapshot.docs;
    });
  }

  Future<void> cargarSeries() async {
    if (ciudadSeleccionada == null) return;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada)
            .collection('series')
            .get();
    setState(() {
      series = snapshot.docs;
    });
  }

  Future<void> cargarBloques() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;
    final snapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada)
            .collection('series')
            .doc(serieSeleccionada)
            .collection('bloques')
            .get();
    setState(() {
      bloques = snapshot.docs;
    });
  }

  Future<void> cargarFrecuencias() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    todasLasParcelas.clear();
    frecuenciaNotas.clear();

    final ciudadDoc =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada)
            .get();
    final serieDoc =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada)
            .collection('series')
            .doc(serieSeleccionada)
            .get();

    final nombreCiudad = ciudadDoc.data()?['nombre'] ?? 'Ciudad';
    final nombreSerie = serieDoc.data()?['nombre'] ?? 'Serie';
    final rawSuperficie = serieDoc.data()?['superficie'];
    final superficie = num.tryParse(rawSuperficie.toString()) ?? 0;

    final fechaCosecha = serieDoc.data()?['fecha_cosecha']?.toDate();
    final fechaCreacion = serieDoc.data()?['fecha_creacion']?.toDate();

    final bloquesSnapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada!)
            .collection('series')
            .doc(serieSeleccionada!)
            .collection('bloques')
            .get();

    final bloquesAFiltrar = bloquesSnapshot.docs.map((b) => b.id).toList();

    for (String bloqueId in bloquesAFiltrar) {
      final bloqueDoc =
          await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadSeleccionada!)
              .collection('series')
              .doc(serieSeleccionada!)
              .collection('bloques')
              .doc(bloqueId)
              .get();
      final nombreBloque = bloqueDoc.data()?['nombre'] ?? bloqueId;

      final parcelasSnap =
          await bloqueDoc.reference
              .collection('parcelas')
              .orderBy('numero')
              .get();

      for (var parcelaDoc in parcelasSnap.docs) {
        final data = parcelaDoc.data();

        // 🔵 Primero extraemos número de ficha y número de tratamiento
        final numeroFicha =
            data.containsKey('numero_ficha') ? data['numero_ficha'] : 0;
        final numeroTratamiento =
            data.containsKey('numero_tratamiento')
                ? data['numero_tratamiento']
                : 0;

        final tratamientoSnap =
            await parcelaDoc.reference
                .collection('tratamientos')
                .doc('actual')
                .get();
        if (!tratamientoSnap.exists) continue;
        final tratamiento = tratamientoSnap.data() ?? {};

        final raicesA = int.tryParse(tratamiento['raicesA'] ?? '0') ?? 0;
        final raicesB = int.tryParse(tratamiento['raicesB'] ?? '0') ?? 0;
        final pesoA = double.tryParse(tratamiento['pesoA'] ?? '0') ?? 0;
        final pesoB = double.tryParse(tratamiento['pesoB'] ?? '0') ?? 0;
        final pesoRaices = pesoA + pesoB;
        final pesoHojas = tratamiento['pesoHojas'] ?? '';
        final ndvi = tratamiento['ndvi'] ?? '';
        final observaciones = tratamiento['observaciones'] ?? '';

        final evaluacionMap = data['evaluacion'] ?? {};
        final frecNotas = List<int>.generate(
          8,
          (i) => (evaluacionMap['$i'] ?? 0) as int,
        );

        todasLasParcelas.add(
          _DatoParcela(
            numeroFicha: numeroFicha,
            fechaCosecha: fechaCosecha ?? fechaCreacion,
            nombreSerie: nombreSerie,
            nombreCiudad: nombreCiudad,
            superficie: superficie,
            nombreBloque: nombreBloque,
            numeroTratamiento: numeroTratamiento,
            pesoRaices: pesoRaices,
            pesoHojas: pesoHojas,
            ndvi: ndvi,
            observaciones: observaciones,
            frecuenciaNotas: frecNotas,
            raicesA: raicesA,
            raicesB: raicesB,
          ),
        );
      }
    }

    setState(() {});
  }

  Future<void> mostrarRutaExportacion(String ruta) async {
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("✅ Archivo exportado"),
            content: Text("Se ha guardado en:\n$ruta"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Entendido"),
              ),
            ],
          ),
    );
  }

  Future<void> exportarExcelConTratamientos({
    required String ciudadId,
    required String serieId,
    required String nombreCiudad,
    required String nombreSerie,
    required DateTime? fechaCosecha,
    required BuildContext context,
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['DatosTratamiento'];

      // Cabecera
      sheet.appendRow([
        'N° Ficha',
        'Fecha Cosecha',
        'Nombre Ensayo',
        'Localidad',
        'Sup. Cosechada (m²)',
        'Bloque',
        'N° Tratamiento',
        'Suma N° raíces',
        'Peso Raíces (kg)',
        'Peso Hojas (kg)',
        'NDVI',
        'Observaciones',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        'Total',
      ]);

      final bloquesSnapshot =
          await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadId)
              .collection('series')
              .doc(serieId)
              .collection('bloques')
              .get();

      for (final bloque in bloquesSnapshot.docs) {
        final bloqueNombre = bloque['nombre'];

        final parcelasSnapshot =
            await bloque.reference
                .collection('parcelas')
                .orderBy('numero')
                .get();

        for (final parcela in parcelasSnapshot.docs) {
          final docData = Map<String, dynamic>.from(parcela.data());

          // ✅ Corrige campos que pueden estar ausentes
          final numeroFicha =
              docData.containsKey('numero_ficha') &&
                      docData['numero_ficha'] != null
                  ? docData['numero_ficha']
                  : 0;

          final numeroTratamiento =
              docData.containsKey('numero_tratamiento') &&
                      docData['numero_tratamiento'] != null
                  ? docData['numero_tratamiento']
                  : 0;

          final tratamientosSnap =
              await parcela.reference
                  .collection('tratamientos')
                  .doc('actual')
                  .get();

          if (!tratamientosSnap.exists) continue;
          final data = tratamientosSnap.data() ?? {};

          final raicesA = int.tryParse(data['raicesA'] ?? '0') ?? 0;
          final raicesB = int.tryParse(data['raicesB'] ?? '0') ?? 0;
          final totalRaices = raicesA + raicesB;

          final pesoRaices =
              (double.tryParse(data['pesoA'] ?? '0') ?? 0) +
              (double.tryParse(data['pesoB'] ?? '0') ?? 0);

          final pesoHojas = data['pesoHojas'] ?? '';
          final ndvi = data['ndvi'] ?? '';
          final observaciones = data['observaciones'] ?? '';

          final frecuencias =
              docData.containsKey('evaluacion') && docData['evaluacion'] != null
                  ? Map<String, dynamic>.from(docData['evaluacion'])
                  : {};

          List<int> quinlei = List.generate(8, (i) => frecuencias['$i'] ?? 0);
          final totalEvaluadas = quinlei.fold(0, (sum, val) => sum + val);

          sheet.appendRow([
            numeroFicha,
            fechaCosecha != null
                ? DateFormat('yyyy-MM-dd').format(fechaCosecha)
                : '',
            nombreSerie,
            nombreCiudad,
            "10", // Puedes reemplazar por valor real si lo necesitas
            bloqueNombre,
            numeroTratamiento,
            totalRaices,
            pesoRaices,
            pesoHojas,
            ndvi,
            observaciones,
            ...quinlei,
            totalEvaluadas,
          ]);
        }
      }

      final nombreArchivo =
          "${nombreCiudad}_${nombreSerie}_${DateFormat('yyyyMMdd').format(fechaCosecha ?? DateTime.now())}"
              .replaceAll(" ", "_")
              .replaceAll("/", "-") +
          ".xlsx";

      final directory = await getExternalStorageDirectory(); // ✅ Ruta segura

      if (directory == null) {
        throw Exception("No se pudo acceder al almacenamiento externo");
      }

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final filePath = "${directory.path}/$nombreArchivo";
      final file = File(filePath);
      final bytes = excel.encode();
      await file.writeAsBytes(bytes!);

      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("✅ Exportación exitosa"),
                content: SelectableText(
                  "El archivo fue guardado en:\n$filePath",
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Share.shareFiles([
                        filePath,
                      ], text: "📄 Tratamiento exportado");
                    },
                    child: const Text("Compartir"),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Aceptar"),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: const Text("❌ Error en la exportación"),
                content: Text("Error:\n$e"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cerrar"),
                  ),
                ],
              ),
        );
      }
    }
  }

  Future<void> exportarPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build:
            (pw.Context context) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  "Frecuencia por Nota",
                  style: pw.TextStyle(fontSize: 20),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Center(child: pw.Text('Nota')),
                        pw.Center(child: pw.Text('Frecuencia')),
                      ],
                    ),
                    for (int i = 0; i <= 7; i++)
                      pw.TableRow(
                        children: [
                          pw.Center(child: pw.Text("$i")),
                          pw.Center(
                            child: pw.Text("${frecuenciaNotas[i] ?? 0}"),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/frecuencia_export.pdf";
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    await mostrarRutaExportacion(path);
    Share.shareFiles([file.path], text: "Exportación de Frecuencia (PDF)");
  }

  Future<void> exportarCSV() async {
    final csv = StringBuffer();
    csv.writeln("Nota,Frecuencia");
    for (var i = 0; i <= 7; i++) {
      csv.writeln("$i,${frecuenciaNotas[i] ?? 0}");
    }
    final dir = await getApplicationDocumentsDirectory();
    final path = "${dir.path}/frecuencia_export.csv";
    final file = File(path);
    await file.writeAsString(csv.toString());
    await mostrarRutaExportacion(path);
    Share.shareFiles([path], text: "Exportación de Frecuencia (CSV)");
  }

  @override
  Widget _buildDropdown<T>(
    String label,
    T? value,
    List<DropdownMenuItem<T>> items,
    void Function(T?) onChanged,
  ) {
    return DropdownButtonFormField<T>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.black, // <-- aquí el color del texto
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.black),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      iconEnabledColor: Colors.black,
      dropdownColor: Colors.white,
      style: const TextStyle(color: Colors.black),
      items: items,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    double promedio =
        datosParcela.isEmpty
            ? 0
            : datosParcela
                    .map((e) => double.tryParse(e.ndvi) ?? 0)
                    .reduce((a, b) => a + b) /
                datosParcela.length;

    double maximo =
        datosParcela.isEmpty
            ? 0
            : datosParcela
                .map((e) => double.tryParse(e.ndvi) ?? 0)
                .reduce((a, b) => a > b ? a : b);

    double minimo =
        datosParcela.isEmpty
            ? 0
            : datosParcela
                .map((e) => double.tryParse(e.ndvi) ?? 0)
                .reduce((a, b) => a < b ? a : b);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Panel de datos"),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDropdown(
              "Localidad",
              ciudadSeleccionada,
              ciudades.map((doc) {
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(doc['nombre']),
                );
              }).toList(),
              (value) {
                setState(() {
                  ciudadSeleccionada = value;
                  serieSeleccionada = null;
                  datosParcela = [];
                  todasLasParcelas.clear();
                  frecuenciaNotas.clear();
                });
                cargarSeries();
              },
            ),
            const SizedBox(height: 10),
            _buildDropdown(
              "Ensayo",
              serieSeleccionada,
              series.map((doc) {
                return DropdownMenuItem(
                  value: doc.id,
                  child: Text(doc['nombre']),
                );
              }).toList(),
              (value) {
                setState(() {
                  serieSeleccionada = value;
                  datosParcela = [];
                  todasLasParcelas.clear();
                  frecuenciaNotas.clear();
                });
                cargarFrecuencias(); // 👈 Carga directamente todas las parcelas de todos los bloques
              },
            ),

            const SizedBox(height: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),

                  if (todasLasParcelas.isEmpty)
                    const Center(
                      child: Text(
                        "No hay datos para mostrar.",
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  else
                    Expanded(
                      child: Scrollbar(
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.vertical,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 16,
                              headingRowColor: MaterialStateProperty.all(
                                const Color(0xFFE0E0E0),
                              ),
                              columns: const [
                                DataColumn(label: Text("N° Ficha")),
                                DataColumn(label: Text("Fecha Creación")),
                                DataColumn(label: Text("Nombre Ensayo")),
                                DataColumn(label: Text("Localidad")),
                                DataColumn(label: Text("Superficie")),
                                DataColumn(label: Text("Bloque")),
                                DataColumn(label: Text("N° Tratamiento")),
                                DataColumn(label: Text("Peso Raíces (kg)")),
                                DataColumn(label: Text("Peso Hojas (kg)")),
                                DataColumn(label: Text("NDVI")),
                                DataColumn(label: Text("Observaciones")),
                                DataColumn(label: Text("0")),
                                DataColumn(label: Text("1")),
                                DataColumn(label: Text("2")),
                                DataColumn(label: Text("3")),
                                DataColumn(label: Text("4")),
                                DataColumn(label: Text("5")),
                                DataColumn(label: Text("6")),
                                DataColumn(label: Text("7")),
                                DataColumn(label: Text("Total")),
                              ],
                              rows:
                                  todasLasParcelas.map((p) {
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text(p.numeroFicha.toString()),
                                        ),
                                        DataCell(
                                          Text(
                                            p.fechaCosecha != null
                                                ? DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(p.fechaCosecha!)
                                                : '',
                                          ),
                                        ),
                                        DataCell(Text(p.nombreSerie)),
                                        DataCell(Text(p.nombreCiudad)),
                                        DataCell(
                                          Text("${p.superficie.toString()} m²"),
                                        ),

                                        DataCell(Text(p.nombreBloque)),
                                        DataCell(
                                          Text(p.numeroTratamiento.toString()),
                                        ),
                                        DataCell(
                                          Text(p.pesoRaices.toStringAsFixed(2)),
                                        ),
                                        DataCell(Text(p.pesoHojas)),
                                        DataCell(Text(p.ndvi)),
                                        DataCell(Text(p.observaciones)),
                                        for (int i = 0; i <= 7; i++)
                                          DataCell(
                                            Text(
                                              p.frecuenciaNotas[i].toString(),
                                            ),
                                          ),
                                        DataCell(
                                          Text(p.totalRaices.toString()),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.table_chart),
                        label: const Text("Exportar Excel"),
                        onPressed: () async {
                          if (ciudadSeleccionada == null ||
                              serieSeleccionada == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "⚠️ Debes seleccionar ciudad y serie",
                                ),
                              ),
                            );
                            return;
                          }

                          final ciudadId = ciudadSeleccionada!;
                          final serieId = serieSeleccionada!;

                          final ciudadDoc =
                              await FirebaseFirestore.instance
                                  .collection('ciudades')
                                  .doc(ciudadId)
                                  .get();
                          final nombreCiudad =
                              ciudadDoc.data()?['nombre'] ?? 'Ciudad';

                          final serieDoc =
                              await FirebaseFirestore.instance
                                  .collection('ciudades')
                                  .doc(ciudadId)
                                  .collection('series')
                                  .doc(serieId)
                                  .get();
                          final nombreSerie =
                              serieDoc.data()?['nombre'] ?? 'Serie';
                          final fechaCosecha =
                              serieDoc.data()?['fecha_cosecha']?.toDate();

                          await exportarExcelConTratamientos(
                            ciudadId: ciudadId,
                            serieId: serieId,
                            nombreCiudad: nombreCiudad,
                            nombreSerie: nombreSerie,
                            fechaCosecha: fechaCosecha,
                            context: context,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatoParcela {
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

  final int raicesA; // ⬅️ nuevo
  final int raicesB; // ⬅️ nuevo

  _DatoParcela({
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

  int get totalRaices => raicesA + raicesB; // ⬅️ NUEVO getter
}
