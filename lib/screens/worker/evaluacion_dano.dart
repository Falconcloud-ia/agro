import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:audioplayers/audioplayers.dart';

class EvaluacionDanoScreen extends StatefulWidget {
  final DocumentReference parcelaRef;
  final int totalRaices;
  final String ciudadId;
  final String serieId;

  const EvaluacionDanoScreen({
    super.key,
    required this.parcelaRef,
    required this.totalRaices,
    required this.ciudadId,
    required this.serieId,
  });

  @override
  State<EvaluacionDanoScreen> createState() => _EvaluacionDanoScreenState();
}

class _EvaluacionDanoScreenState extends State<EvaluacionDanoScreen> {
  final AudioPlayer player = AudioPlayer();
  final TextEditingController cantidadController = TextEditingController();
  int evaluadas = 0;
  int faltan = 0;
  List<int> historialEvaluaciones = [];
  bool evaluacionGuardada = false;

  Map<String, dynamic>? ciudad;
  Map<String, dynamic>? serie;
  Map<String, dynamic>? parcelaData;
  Map<String, String> nombresBloques = {};

  Map<int, int> evaluaciones = {}; // nota -> cantidad
  String mensaje = '';

  @override
  void initState() {
    super.initState();
    cargarEvaluacionDesdeFirestore(); // <- aquí se carga la evaluación previa
    cargarCiudadYSerie();
    cargarNombresBloques();
    cargarParcela();
  }

  Widget _buildNotaButton(int nota) {
    return ElevatedButton(
      onPressed: faltan > 0 ? () => agregarEvaluacion(nota) : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color.fromARGB(255, 213, 182, 9),
        padding: const EdgeInsets.symmetric(horizontal: 150, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        "$nota",
        style: const TextStyle(
          fontSize: 40,
          color: Color.fromARGB(255, 0, 0, 0),
        ),
      ),
    );
  }

  Future<void> cargarCiudadYSerie() async {
    final ciudadSnap =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .get();

    final serieSnap =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .collection('series')
            .doc(widget.serieId)
            .get();

    setState(() {
      ciudad = ciudadSnap.data();
      serie = serieSnap.data();
    });
  }

  Future<void> cargarNombresBloques() async {
    final bloquesSnapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .collection('series')
            .doc(widget.serieId)
            .collection('bloques')
            .get();

    setState(() {
      for (final doc in bloquesSnapshot.docs) {
        nombresBloques[doc.id] = doc['nombre'];
      }
    });
  }

  Future<void> cargarParcela() async {
    final snap = await widget.parcelaRef.get();
    final data = snap.data() as Map<String, dynamic>?;

    if (data != null) {
      setState(() {
        parcelaData = data;

        // Aseguramos que totalRaices refleje el valor real de Firestore
        if (parcelaData!['raicesA'] != null) {
          final raicesGuardadas =
              int.tryParse(parcelaData!['raicesA'].toString()) ?? 0;
          if (raicesGuardadas > 0 && raicesGuardadas != widget.totalRaices) {
            // Aquí podrías lanzar un error o corregir
            debugPrint(
              'Advertencia: raíz ingresada ${widget.totalRaices}, en Firestore ${raicesGuardadas}',
            );
            // podrías actualizar widget.totalRaices o notificar al usuario
          }
        }
      });
    }
  }

  Future<void> agregarEvaluacion(int nota) async {
    final cantidad = int.tryParse(cantidadController.text.trim());
    if (cantidad == null || cantidad <= 0 || cantidad > faltan) {
      setState(() {
        mensaje = "⚠️ Ingresa una cantidad válida (restantes: $faltan).";
      });
      return;
    }

    setState(() {
      evaluaciones.update(
        nota,
        (value) => value + cantidad,
        ifAbsent: () => cantidad,
      );
      cantidadController.clear();
      mensaje = '';
    });

    // 🔊 Feedback sonoro
    await player.play(AssetSource('sounds/beep.mp3'));
  }

  void borrarUltimo() {
    if (historialEvaluaciones.isNotEmpty) {
      final ultimaNota = historialEvaluaciones.removeLast();

      setState(() {
        final cantidadActual = evaluaciones[ultimaNota] ?? 0;
        if (cantidadActual > 1) {
          evaluaciones[ultimaNota] = cantidadActual - 1;
        } else {
          evaluaciones.remove(ultimaNota);
        }
      });
    }
  }

  void reiniciarEvaluacion() {
    setState(() {
      evaluaciones.clear();
      mensaje = '';
    });
  }

  Future<void> guardarEvaluacion() async {
    try {
      int totalEvaluadas = evaluaciones.values.fold(0, (a, b) => a + b);

      if (totalEvaluadas != widget.totalRaices) {
        setState(() {
          mensaje =
              "❌ La cantidad evaluada ($totalEvaluadas) no coincide con raíces a evaluar (${widget.totalRaices}).";
        });
        return; // No permitas guardar si no coinciden
      }

      double frecuencia =
          widget.totalRaices == 0
              ? 0.0
              : totalEvaluadas / (widget.totalRaices * 7);

      await widget.parcelaRef.update({
        "evaluacion": evaluaciones.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
        "frecuencia_relativa": double.parse(frecuencia.toStringAsFixed(3)),
        // NO toques "raicesA" aquí
      });

      await player.play(AssetSource('sounds/done.mp3'));

      setState(() {
        evaluacionGuardada = true;
      });

      await cargarEvaluacionDesdeFirestore(); // Opcional
    } catch (e) {
      setState(() => mensaje = "❌ Error al guardar: $e");
    }
  }

  Future<void> cargarEvaluacionDesdeFirestore() async {
    try {
      final doc = await widget.parcelaRef.get();
      final data = doc.data() as Map<String, dynamic>?;

      if (data != null && data['evaluacion'] != null) {
        final mapa = Map<String, dynamic>.from(data['evaluacion']);
        setState(() {
          evaluaciones = mapa.map((k, v) => MapEntry(int.parse(k), v as int));
        });
      }
    } catch (e) {
      setState(() => mensaje = "❌ Error al cargar evaluación: $e");
    }
  }

  void _confirmarAvance() {
    final int totalEvaluadas = evaluaciones.values.fold(0, (a, b) => a + b);

    if (totalEvaluadas < widget.totalRaices) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text("Evaluación incompleta"),
              content: Text(
                "Has evaluado $totalEvaluadas de ${widget.totalRaices} raíces. Completa la evaluación antes de continuar.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Aceptar"),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("¿Avanzar a la siguiente parcela?"),
            content: const Text(
              "¿Deseas continuar? Esta acción no se puede deshacer.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context); // Cierra modal
                  await guardarEvaluacion(); // Guarda

                  if (mounted && mensaje.isEmpty) {
                    Navigator.pop(
                      context,
                      'siguiente',
                    ); // ⬅️ Devuelve señal a formulario_tratamiento
                  }
                },
                child: const Text("Sí, continuar"),
              ),
            ],
          ),
    );
  }

  void _confirmarReinicio() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("¿Reiniciar evaluación?"),
            content: const Text("Se eliminarán todos los datos actuales."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  reiniciarEvaluacion();
                },
                child: const Text("Sí, reiniciar"),
              ),
            ],
          ),
    );
  }

  Widget build(BuildContext context) {
    int totalRaices = evaluaciones.values.fold(0, (a, b) => a + b);
    final bool completado = totalRaices >= widget.totalRaices;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 0, 0, 0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () async {
            await guardarEvaluacion();
            if (context.mounted) Navigator.of(context).pop('guardado');
          },
        ),

        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "T ${parcelaData?['numero_tratamiento'] ?? ''} - BLOQUE ${nombresBloques[widget.parcelaRef.parent.parent!.id] ?? ''}",
              style: const TextStyle(fontSize: 20, color: Colors.white),
            ),
            if (ciudad != null && serie != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ciudad!['nombre'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                  Text(
                    serie!['nombre'] ?? '',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
          ],
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                "Raíces a evaluar: ${widget.totalRaices}",
                style: const TextStyle(color: Colors.white, fontSize: 25),
              ),

              if (completado)
                Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "✅ Evaluación completa",
                      style: TextStyle(color: Colors.white, fontSize: 8),
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                physics: const NeverScrollableScrollPhysics(),
                children: List.generate(9, (index) {
                  if (index < 8) {
                    final cantidad = evaluaciones[index] ?? 0;
                    return GestureDetector(
                      onTap:
                          completado
                              ? null
                              : () async {
                                setState(() {
                                  evaluaciones[index] =
                                      (evaluaciones[index] ?? 0) + 1;
                                  historialEvaluaciones.add(index);
                                });

                                await player.play(
                                  AssetSource('sounds/beep.mp3'),
                                );
                              },
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  completado
                                      ? Colors.grey.shade800
                                      : Colors.black,
                              border: Border.all(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.topCenter,
                            child: Text(
                              "$index",
                              style: const TextStyle(
                                fontSize: 48,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.yellow.shade700,
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(10),
                                  bottomRight: Radius.circular(10),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "$cantidad",
                                  style: const TextStyle(
                                    fontSize: 20,
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // 🔽 Botón GUARDAR en la última celda (posición 8)
                    return SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: guardarEvaluacion,
                        icon: const Icon(Icons.save),
                        label: const Text(
                          "Guardar",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF04bc04),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    );
                  }
                }),
              ),

              const SizedBox(height: 4),

              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 40,
                ),
                child: Text(
                  "N° Raíces: $totalRaices ",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              const Divider(color: Colors.white38),

              Text(
                "Frecuencia acumulada",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),

              if (evaluaciones.isNotEmpty)
                Center(
                  child: SizedBox(
                    height: 200,
                    width: 200,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 30,
                        sectionsSpace: 2,
                        sections:
                            evaluaciones.entries.map((entry) {
                              final nota = entry.key;
                              final cantidad = entry.value;
                              final porcentaje = cantidad / widget.totalRaices;

                              return PieChartSectionData(
                                value: porcentaje,
                                color:
                                    Colors.primaries[nota %
                                        Colors.primaries.length],
                                radius: 60,
                                title: "$nota",
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    "Sin datos aún.",
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  OutlinedButton.icon(
                    onPressed: borrarUltimo,
                    icon: const Icon(Icons.undo, color: Colors.red),
                    label: const Text(
                      "Borrar último",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 28,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _confirmarReinicio,
                    icon: const Icon(Icons.restart_alt, color: Colors.white),
                    label: const Text(
                      "Reiniciar",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 28,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (mensaje.isNotEmpty)
                Text(
                  mensaje,
                  style: TextStyle(
                    fontSize: 16,
                    color:
                        mensaje.startsWith("✅")
                            ? Colors.greenAccent
                            : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
