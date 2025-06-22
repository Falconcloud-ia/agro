import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'ver_matriz.dart';
import 'editar_parcela.dart';

class CrearParcelas extends StatefulWidget {
  const CrearParcelas({super.key});

  @override
  State<CrearParcelas> createState() => _CrearParcelasState();
}

class _CrearParcelasState extends State<CrearParcelas> {
  String? ciudadSeleccionada;
  String? serieSeleccionada;
  int cantidadParcelas = 0;
  int cantidadBloques = 0;
  bool copiarDesdeOtraSerie = false;
  String? ciudadOrigen;
  String? serieOrigen;

  Map<String, List<DocumentSnapshot>> parcelasPorBloque = {};
  bool cargandoParcelas = false;
  List<QueryDocumentSnapshot> ciudades = [];
  List<QueryDocumentSnapshot> series = [];

  String mensaje = '';

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

  Future<void> cargarMatrizCompleta() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    setState(() {
      cargandoParcelas = true;
      parcelasPorBloque.clear();
    });

    final serieRef = FirebaseFirestore.instance
        .collection('ciudades')
        .doc(ciudadSeleccionada!)
        .collection('series')
        .doc(serieSeleccionada!);

    final bloquesSnapshot = await serieRef.collection('bloques').get();

    // Convertir y ordenar los bloques por ID en orden descendente
    final bloquesOrdenados =
        bloquesSnapshot.docs.toList()
          ..sort((a, b) => b.id.compareTo(a.id)); // D, C, B, A

    for (final bloqueDoc in bloquesOrdenados) {
      final String bloque = bloqueDoc.id;
      final parcelasSnap =
          await bloqueDoc.reference
              .collection('parcelas')
              .orderBy('numero')
              .get();

      parcelasPorBloque[bloque] = parcelasSnap.docs;
    }

    setState(() => cargandoParcelas = false);
  }

  Future<void> generarNumerosAleatorios() async {
    if (parcelasPorBloque.isEmpty) {
      setState(() => mensaje = "⚠️ No hay parcelas para procesar.");
      return;
    }

    try {
      for (final entry in parcelasPorBloque.entries) {
        final bloqueId = entry.key;
        final parcelas = entry.value;

        final total = parcelas.length;
        final List<int> numeros = List.generate(total, (index) => index + 1)
          ..shuffle();

        for (int i = 0; i < total; i++) {
          final parcela = parcelas[i];
          final ref = parcela.reference;

          await ref.update({'numero_tratamiento': numeros[i]});
        }
      }

      setState(
        () => mensaje = "✅ Números de tratamiento generados aleatoriamente.",
      );
      await cargarMatrizCompleta();
    } catch (e) {
      setState(() => mensaje = "❌ Error al generar números: $e");
    }
  }

  Future<void> cargarNumerosDesdeSerieAnterior(
    String ciudadId,
    String serieId,
  ) async {
    final bloquesSnapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadId)
            .collection('series')
            .doc(serieId)
            .collection('bloques')
            .get();

    for (final bloqueDoc in bloquesSnapshot.docs) {
      final parcelasSnapshot =
          await bloqueDoc.reference
              .collection('parcelas')
              .orderBy('numero')
              .get();

      for (final parcelaDoc in parcelasSnapshot.docs) {
        final numero = parcelaDoc['numero'];
        final numeroFicha = parcelaDoc['numero_ficha'];
        final numeroTratamiento = parcelaDoc['numero_tratamiento'];

        final bloqueDestino = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada)
            .collection('series')
            .doc(serieSeleccionada)
            .collection('bloques')
            .doc(bloqueDoc.id)
            .collection('parcelas')
            .where('numero', isEqualTo: numero);

        final result = await bloqueDestino.get();
        if (result.docs.isNotEmpty) {
          final ref = result.docs.first.reference;
          await ref.update({
            'numero_ficha': numeroFicha,
            'numero_tratamiento': numeroTratamiento,
          });
        }
      }
    }

    setState(() {
      mensaje = "✅ Datos cargados correctamente desde la serie anterior.";
    });
    cargarMatrizCompleta();
  }

  void mostrarModalCompararSeries(BuildContext context) {
    String? ciudadComparar;
    String? serieComparar;
    List<DocumentSnapshot> ciudadesDisponibles = ciudades;
    List<DocumentSnapshot> seriesDisponibles = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("Seleccionar ciudad y serie"),
          content: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Ciudad"),
                    value: ciudadComparar,
                    items:
                        ciudadesDisponibles.map((doc) {
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc['nombre']),
                          );
                        }).toList(),
                    onChanged: (value) async {
                      setModalState(() {
                        ciudadComparar = value;
                        serieComparar = null;
                        seriesDisponibles = [];
                      });

                      if (value != null) {
                        final snapshot =
                            await FirebaseFirestore.instance
                                .collection('ciudades')
                                .doc(value)
                                .collection('series')
                                .get();
                        setModalState(() {
                          seriesDisponibles = snapshot.docs;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Serie"),
                    value: serieComparar,
                    items:
                        seriesDisponibles.map((doc) {
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(doc['nombre']),
                          );
                        }).toList(),
                    onChanged: (value) {
                      setModalState(() => serieComparar = value);
                    },
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancelar"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (ciudadComparar == null || serieComparar == null) return;

                final serieDoc =
                    await FirebaseFirestore.instance
                        .collection('ciudades')
                        .doc(ciudadComparar)
                        .collection('series')
                        .doc(serieComparar)
                        .get();

                final actual =
                    await FirebaseFirestore.instance
                        .collection('ciudades')
                        .doc(ciudadSeleccionada)
                        .collection('series')
                        .doc(serieSeleccionada)
                        .get();

                final int altoNuevo = serieDoc['matriz_alto'] ?? 0;
                final int largoNuevo = serieDoc['matriz_largo'] ?? 0;
                final int altoActual = actual['matriz_alto'] ?? 0;
                final int largoActual = actual['matriz_largo'] ?? 0;

                if (altoNuevo == altoActual && largoNuevo == largoActual) {
                  Navigator.pop(context);
                  // 🔄 Aquí puedes llamar una función para cargar automáticamente
                  cargarNumerosDesdeSerieAnterior(
                    ciudadComparar!,
                    serieComparar!,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "⚠️ Las dimensiones de la serie no coinciden.",
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text("Comparar y cargar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF005A56),
        title: const Text(
          "Crear Parcelas en Ensayo",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: ciudadSeleccionada,
              decoration: _dropdownDecoration("Seleccionar localidad"),
              items:
                  ciudades.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['nombre']),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() {
                  ciudadSeleccionada = value;
                  serieSeleccionada = null;
                  series = [];
                  parcelasPorBloque.clear();
                });
                cargarSeries();
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: serieSeleccionada,
              decoration: _dropdownDecoration("Seleccionar ensayo"),
              items:
                  series.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['nombre']),
                    );
                  }).toList(),
              onChanged: (value) {
                setState(() => serieSeleccionada = value);
                cargarMatrizCompleta();
              },
            ),
            const SizedBox(height: 20),
            const SizedBox(height: 20),
            Row(
              children: [
                const SizedBox(width: 10),

                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text("¿Generar números aleatorios?"),
                            content: const Text(
                              "Se asignarán números de tratamiento aleatorios a todas las parcelas de cada bloque. Esta acción sobrescribirá los valores actuales.",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancelar"),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  generarNumerosAleatorios();
                                },
                                child: const Text("Confirmar"),
                              ),
                            ],
                          ),
                    );
                  },
                  icon: const Icon(Icons.shuffle),
                  label: const Text("Generar número de tratamiento aleatorio"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(
              mensaje,
              style: TextStyle(
                fontSize: 16,
                color:
                    mensaje.startsWith("✅")
                        ? Colors.green
                        : mensaje.startsWith("⚠️")
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 20),
            if (parcelasPorBloque.isNotEmpty)
              ...parcelasPorBloque.entries
                  .toList()
                  .reversed
                  .map((entry) {
                    final bloque = entry.key;
                    final List<DocumentSnapshot> listaParcelas = entry.value;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "BLOQUE $bloque",
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          height: 160,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: listaParcelas.length,
                            itemBuilder: (context, index) {
                              final parcela = listaParcelas[index];
                              final idDoc = parcela.id;

                              // Usamos `data()` en vez de acceso directo para evitar errores con campos inexistentes
                              final data =
                                  parcela.data() as Map<String, dynamic>? ?? {};

                              final numeroFicha =
                                  data.containsKey('numero_ficha') &&
                                          data['numero_ficha'] != null
                                      ? data['numero_ficha'].toString().padLeft(
                                        4,
                                        '0',
                                      )
                                      : "-";

                              final numeroTratamiento =
                                  data.containsKey('numero_tratamiento') &&
                                          data['numero_tratamiento'] != null
                                      ? data['numero_tratamiento'].toString()
                                      : "-";

                              return Container(
                                width: 90,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green[100],
                                  border: Border.all(
                                    color: Colors.green.shade800,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      numeroTratamiento,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      numeroFicha,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) => EditarParcela(
                                                  ciudadId: ciudadSeleccionada!,
                                                  serieId: serieSeleccionada!,
                                                  bloqueId: bloque,
                                                  parcelaId: idDoc,
                                                ),
                                          ),
                                        ).then((_) => cargarMatrizCompleta());
                                      },
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                      ),
                                      child: const Text(
                                        "Editar",
                                        style: TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  })
                  .toList()
                  .reversed
            else if (serieSeleccionada != null && !cargandoParcelas)
              const Text("⚠️ Serie vacía. No hay parcelas registradas."),
          ],
        ),
      ),
    );
  }

  InputDecoration _dropdownDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.black),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF005A56), width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
