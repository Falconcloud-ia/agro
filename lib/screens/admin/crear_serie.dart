import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CrearSerie extends StatefulWidget {
  const CrearSerie({super.key});

  @override
  State<CrearSerie> createState() => _CrearSerieState();
}

class _CrearSerieState extends State<CrearSerie> {
  bool isLoading = false;
  String mensajeTemporal = '';

  bool get sePuedeCrear =>
      !isLoading &&
      nombreSerieController.text.trim().isNotEmpty &&
      ciudadSeleccionada != null &&
      (usarSerieExistente
          ? ciudadReferencia != null && serieReferencia != null
          : cantidadParcelasController.text.trim().isNotEmpty &&
              cantidadBloquesController.text.trim().isNotEmpty);

  final TextEditingController nombreSerieController = TextEditingController();
  final TextEditingController cantidadParcelasController =
      TextEditingController();
  final TextEditingController cantidadBloquesController =
      TextEditingController();

  String mensaje = '';
  String? ciudadSeleccionada;
  List<QueryDocumentSnapshot> ciudades = [];

  DocumentSnapshot? serieSeleccionada;
  List<DocumentSnapshot> seriesEnCiudad = [];

  bool usarSerieExistente = false;
  String? ciudadReferencia;
  String? serieReferencia;
  List<DocumentSnapshot> seriesReferenciaDisponibles = [];

  @override
  void initState() {
    super.initState();
    cargarCiudades();

    // 🔄 Escuchar los controladores
    nombreSerieController.addListener(() => setState(() {}));
    cantidadBloquesController.addListener(() => setState(() {}));
    cantidadParcelasController.addListener(() => setState(() {}));
  }

  Future<void> cargarCiudades() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('ciudades').get();
    setState(() {
      ciudades = snapshot.docs;
    });
  }

  void mostrarModalEliminarSerie() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Eliminar Ensayo"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Selecciona un ensayo para eliminar:"),
                const SizedBox(height: 10),
                DropdownButton<DocumentSnapshot>(
                  isExpanded: true,
                  value: serieSeleccionada,
                  hint: const Text("Seleccionar..."),
                  items:
                      seriesEnCiudad.map((doc) {
                        return DropdownMenuItem(
                          value: doc,
                          child: Text(doc['nombre']),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() {
                      serieSeleccionada = value;
                    });
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (ciudadSeleccionada != null && serieSeleccionada != null) {
                    await FirebaseFirestore.instance
                        .collection('ciudades')
                        .doc(ciudadSeleccionada!)
                        .collection('series')
                        .doc(serieSeleccionada!.id)
                        .delete();

                    setState(() {
                      mensaje =
                          "✅ Ensayo '${serieSeleccionada!['nombre']}' eliminado.";
                      serieSeleccionada = null;
                    });

                    Navigator.pop(context);

                    // Recargar lista de series
                    final snap =
                        await FirebaseFirestore.instance
                            .collection('ciudades')
                            .doc(ciudadSeleccionada!)
                            .collection('series')
                            .get();

                    setState(() {
                      seriesEnCiudad = snap.docs;
                    });
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text("Eliminar"),
              ),
            ],
          ),
    );
  }

  Future<void> copiarNumeroTratamientoDesdeSerie(
    String ciudadBaseId,
    String serieBaseId,
    DocumentReference nuevaSerieRef,
  ) async {
    final bloquesRef = FirebaseFirestore.instance
        .collection('ciudades')
        .doc(ciudadBaseId)
        .collection('series')
        .doc(serieBaseId)
        .collection('bloques');

    final nuevaRef = nuevaSerieRef.collection('bloques');

    final bloquesSnapshot = await bloquesRef.get();
    for (final bloqueDoc in bloquesSnapshot.docs) {
      final parcelasSnap =
          await bloqueDoc.reference
              .collection('parcelas')
              .orderBy('numero')
              .get();

      for (final parcelaDoc in parcelasSnap.docs) {
        final data = parcelaDoc.data();
        final numero = data['numero'];
        final tratamiento = data['numero_tratamiento'];

        final destinoSnap =
            await nuevaRef
                .doc(bloqueDoc.id)
                .collection('parcelas')
                .where('numero', isEqualTo: numero)
                .get();

        if (destinoSnap.docs.isNotEmpty && tratamiento != null) {
          await destinoSnap.docs.first.reference.update({
            'numero_tratamiento': tratamiento,
          });
        }
      }
    }
  }

  Future<void> copiarNumerosDesdeSerieReferencia(
    String ciudadId,
    String serieId,
    DocumentReference nuevaSerieRef,
  ) async {
    final bloquesRef = FirebaseFirestore.instance
        .collection('ciudades')
        .doc(ciudadId)
        .collection('series')
        .doc(serieId)
        .collection('bloques');

    final nuevaRef = nuevaSerieRef.collection('bloques');

    final bloquesSnapshot = await bloquesRef.get();
    for (final bloqueDoc in bloquesSnapshot.docs) {
      final parcelasSnap =
          await bloqueDoc.reference
              .collection('parcelas')
              .orderBy('numero')
              .get();

      for (final parcelaDoc in parcelasSnap.docs) {
        final data = parcelaDoc.data();
        final numero = data['numero'];
        final tratamiento = data['numero_tratamiento'];

        final destino =
            await nuevaRef
                .doc(bloqueDoc.id)
                .collection('parcelas')
                .where('numero', isEqualTo: numero)
                .get();

        if (destino.docs.isNotEmpty) {
          await destino.docs.first.reference.update({
            'numero_tratamiento': tratamiento,
          });
        }
      }
    }
  }

  Widget crearMatrizButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed:
            sePuedeCrear
                ? () async {
                  setState(() => isLoading = true);
                  await crearSerie(); // este método ya está definido en tu clase
                  setState(() => isLoading = false);
                }
                : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B140),
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child:
            isLoading
                ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "CARGANDO MATRIZ...",
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                )
                : const Text("Crear Matriz"),
      ),
    );
  }

  Future<void> crearSerie() async {
    final nombreSerie = nombreSerieController.text.trim();
    final cantidadParcelas = int.tryParse(
      cantidadParcelasController.text.trim(),
    );
    final cantidadBloques = int.tryParse(cantidadBloquesController.text.trim());

    if (nombreSerie.isEmpty || ciudadSeleccionada == null) {
      setState(() {
        mensaje = '⚠️ Completa todos los campos.';
      });
      return;
    }

    // ⚠️ Solo validar bloques y parcelas si NO se usa serie existente
    if (!usarSerieExistente &&
        (cantidadParcelas == null || cantidadBloques == null)) {
      setState(() {
        mensaje = '⚠️ Completa todos los campos.';
      });
      return;
    }

    try {
      final ciudadRef = FirebaseFirestore.instance
          .collection('ciudades')
          .doc(ciudadSeleccionada);

      int bloques = cantidadBloques ?? 0;
      int parcelas = cantidadParcelas ?? 0;

      // Si se basa en otra serie, obtener dimensiones desde esa serie
      if (usarSerieExistente &&
          ciudadReferencia != null &&
          serieReferencia != null) {
        final refBase = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadReferencia)
            .collection('series')
            .doc(serieReferencia!);

        final baseData = await refBase.get();
        bloques = baseData.data()?['matriz_alto'] ?? 0;
        parcelas = baseData.data()?['matriz_largo'] ?? 0;
      }

      // Crear la nueva serie
      final serieRef = await ciudadRef.collection('series').add({
        "nombre": nombreSerie,
        "matriz_largo": parcelas,
        "matriz_alto": bloques,
        "fecha_creacion": FieldValue.serverTimestamp(),
      });

      // 🔁 Crear bloques y parcelas
      for (int i = 0; i < bloques; i++) {
        String bloque = String.fromCharCode(65 + i); // A, B, C...
        final bloqueRef = serieRef.collection('bloques').doc(bloque);
        await bloqueRef.set({"nombre": bloque});

        for (int j = 1; j <= parcelas; j++) {
          await bloqueRef.collection('parcelas').add({
            "numero": j,
            "tratamiento": true,
            "trabajador_id": null,
            "total_raices": null,
            "evaluacion": null,
            "frecuencia_relativa": null,
          });
        }
      }

      // ✅ Copiar numero_tratamiento si corresponde
      if (usarSerieExistente &&
          ciudadReferencia != null &&
          serieReferencia != null) {
        await copiarNumeroTratamientoDesdeSerie(
          ciudadReferencia!,
          serieReferencia!,
          serieRef,
        );
      }

      setState(() {
        mensaje =
            "✅ Ensayo '$nombreSerie' creado con $bloques bloques y $parcelas parcelas por bloque.";
        nombreSerieController.clear();
        cantidadParcelasController.clear();
        cantidadBloquesController.clear();
      });
    } catch (e) {
      setState(() {
        mensaje = "❌ Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF005A56),
        centerTitle: true,
        elevation: 0,
        title: const Text(
          "Crear Ensayo",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  value: ciudadSeleccionada,
                  onChanged: (value) async {
                    setState(() {
                      ciudadSeleccionada = value;
                      serieSeleccionada = null;
                      seriesEnCiudad = [];
                    });

                    if (value != null) {
                      final snap =
                          await FirebaseFirestore.instance
                              .collection('ciudades')
                              .doc(value)
                              .collection('series')
                              .get();

                      setState(() {
                        seriesEnCiudad = snap.docs;
                      });
                    }
                  },

                  items:
                      ciudades.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['nombre']),
                        );
                      }).toList(),
                  decoration: _dropdownDecoration("Seleccionar localidad"),
                  dropdownColor: Colors.white,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: nombreSerieController,
                  label: "Nombre del ensayo",
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: cantidadBloquesController,
                  label: "Cantidad de bloques en el ensayo",
                  keyboardType: TextInputType.number,
                  enabled: !usarSerieExistente,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: cantidadParcelasController,
                  label: "Cantidad de parcelas por bloque",
                  keyboardType: TextInputType.number,
                  enabled: !usarSerieExistente,
                ),

                const SizedBox(height: 24),

                // 🔄 Nuevo Switch
                Row(
                  children: [
                    const Text(
                      "¿Basar en otro ensayo?",
                      style: TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    Switch(
                      value: usarSerieExistente,
                      onChanged: (val) {
                        setState(() {
                          usarSerieExistente = val;
                          ciudadReferencia = null;
                          serieReferencia = null;
                        });
                      },
                    ),
                  ],
                ),

                if (usarSerieExistente) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: ciudadReferencia,
                    onChanged: (val) async {
                      setState(() {
                        ciudadReferencia = val;
                        serieReferencia = null;
                        seriesReferenciaDisponibles = [];
                      });

                      if (val != null) {
                        final snap =
                            await FirebaseFirestore.instance
                                .collection('ciudades')
                                .doc(val)
                                .collection('series')
                                .get();

                        setState(() {
                          seriesReferenciaDisponibles = snap.docs;
                        });
                      }
                    },
                    items:
                        ciudades.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['nombre']),
                          );
                        }).toList(),
                    decoration: _dropdownDecoration("Localidad base"),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: serieReferencia,
                    onChanged: (val) => setState(() => serieReferencia = val),
                    items:
                        seriesReferenciaDisponibles.map((doc) {
                          return DropdownMenuItem<String>(
                            value: doc.id,
                            child: Text(doc['nombre']),
                          );
                        }).toList(),
                    decoration: _dropdownDecoration("Ensayo base"),
                  ),
                ],

                const SizedBox(height: 24),
                crearMatrizButton(),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed:
                      ciudadSeleccionada == null
                          ? null
                          : mostrarModalEliminarSerie,
                  icon: const Icon(Icons.delete),
                  label: const Text("Eliminar Ensayo"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),

                if (mensaje.isNotEmpty)
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
              ],
            ),
          ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: const TextStyle(fontSize: 18, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black87),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade200,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.black),
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF005A56), width: 2),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
