import 'inicio_tratamiento.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'evaluacion_dano.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AlwaysDisabledFocusNode extends FocusNode {
  @override
  bool get hasFocus => false;
}

class FormularioTratamiento extends StatefulWidget {
  final String ciudadId;
  final String serieId;
  final String bloqueId;
  final int parcelaDesde;
  final String numeroFicha;
  final String numeroTratamiento;

  const FormularioTratamiento({
    super.key,
    required this.ciudadId,
    required this.serieId,
    required this.bloqueId,
    required this.parcelaDesde,
    required this.numeroFicha,
    required this.numeroTratamiento,
  });

  @override
  State<FormularioTratamiento> createState() => _FormularioTratamientoState();
}

class _FormularioTratamientoState extends State<FormularioTratamiento> {
  bool guardado = false;
  late Box hiveBox;
  String? userId;
  List<dynamic> parcelas = [];
  int currentIndex = 0;
  TextEditingController? focusedController;

  final TextEditingController raicesAController = TextEditingController();
  final TextEditingController raicesBController = TextEditingController();
  final TextEditingController pesoAController = TextEditingController();
  final TextEditingController pesoBController = TextEditingController();
  final TextEditingController pesoHojasController = TextEditingController();
  final TextEditingController ndviController = TextEditingController();
  final TextEditingController observacionesController = TextEditingController();

  String mensaje = '';

  @override
  void initState() {
    super.initState();
    hiveBox = Hive.box('offline_tratamientos');
    userId = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    cargarCiudadYSerie();
    cargarTodasLasParcelas();
    raicesAController.addListener(() => setState(() {}));
    raicesBController.addListener(() => setState(() {}));
    pesoAController.addListener(() => setState(() {}));
    pesoBController.addListener(() => setState(() {}));
    monitorConexionParaSincronizar();
  }

  Map<String, dynamic>? ciudad;
  Map<String, dynamic>? serie;
  Map<String, String> nombresBloques =
      {}; // bloqueId -> nombre (ej: 'A' → 'Bloque 1')

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

  String obtenerCampoActual(String campo) {
    final current = parcelas[currentIndex];
    if (current is DocumentSnapshot) {
      final data = current.data() as Map<String, dynamic>?;
      return data?[campo]?.toString() ?? '-';
    } else if (current is Map<String, dynamic>) {
      return current[campo]?.toString() ?? '-';
    }
    return '-';
  }

  String obtenerNombreBloqueActual() {
    final current = parcelas[currentIndex];
    if (current is DocumentSnapshot) {
      final bloqueId = current.reference.parent.parent?.id;
      return nombresBloques[bloqueId] ?? '...';
    } else if (current is Map<String, dynamic>) {
      final bloqueId = current['bloqueId'];
      return nombresBloques[bloqueId] ?? '...';
    }
    return '...';
  }

  Future<void> guardarTratamientoActual() async {
    final parcela = parcelas[currentIndex];
    final id = (parcela is DocumentSnapshot) ? parcela.id : parcela['id'];
    final key =
        'tratamiento_${widget.ciudadId}_${widget.serieId}_${widget.bloqueId}_$id';

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity != ConnectivityResult.none;

    Map<String, dynamic> tratamientoPrevio = {};

    if (online && parcela is DocumentSnapshot) {
      final ref = parcela.reference.collection('tratamientos').doc('actual');
      final doc = await ref.get();
      if (doc.exists) {
        tratamientoPrevio = doc.data()!;
      }
    } else {
      final dataOffline = hiveBox.get(key);
      if (dataOffline != null) {
        tratamientoPrevio = Map<String, dynamic>.from(dataOffline);
      }
    }

    // Aquí construimos el nuevo Data respetando raíces actuales si están en los controllers
    final nuevoData = {
      ...tratamientoPrevio, // Copiamos todo lo anterior
      if (raicesAController.text.trim().isNotEmpty)
        'raicesA':
            raicesAController.text.trim(), // Solo si el usuario ingresó algo
      if (raicesBController.text.trim().isNotEmpty)
        'raicesB': raicesBController.text.trim(),
      'pesoA': pesoAController.text.trim(),
      'pesoB': pesoBController.text.trim(),
      'pesoHojas': pesoHojasController.text.trim(),
      'ndvi': ndviController.text.trim(),
      'observaciones': observacionesController.text.trim(),
      'fecha': DateTime.now().toIso8601String(),
      'sincronizado': false,
      'usuario': userId,
    };

    if (online && parcela is DocumentSnapshot) {
      final ref = parcela.reference.collection('tratamientos').doc('actual');
      await ref.set(nuevoData);
    } else {
      await hiveBox.put(key, nuevoData);
    }
  }

  Future<void> cargarTratamientoActual() async {
    if (parcelas.isEmpty) return;

    final parcela = parcelas[currentIndex];
    final id = (parcela is DocumentSnapshot) ? parcela.id : parcela['id'];
    final key =
        'tratamiento_${widget.ciudadId}_${widget.serieId}_${widget.bloqueId}_$id';

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity != ConnectivityResult.none;

    if (online && parcela is DocumentSnapshot) {
      final doc =
          await parcela.reference
              .collection('tratamientos')
              .doc('actual')
              .get();
      if (doc.exists) {
        final data = doc.data()!;
        cargarEnControladores(data);
        return;
      }
    }

    final data = hiveBox.get(key);
    if (data != null) {
      cargarEnControladores(data);
    } else {
      limpiarFormulario();
    }
  }

  void cargarEnControladores(Map<String, dynamic> data) {
    setState(() {
      raicesAController.text = data['raicesA'] ?? '';
      raicesBController.text = data['raicesB'] ?? '';
      pesoAController.text = data['pesoA'] ?? '';
      pesoBController.text = data['pesoB'] ?? '';
      pesoHojasController.text = data['pesoHojas'] ?? '';
      ndviController.text = data['ndvi'] ?? '';
      observacionesController.text = data['observaciones'] ?? '';
    });
  }

  Future<void> anteriorParcela() async {
    if (guardado) return; // 🚫 Evitar doble click mientras guarda

    setState(() {
      guardado = true;
    });

    try {
      await guardarTratamientoActual(); // 🛡️ Guarda primero

      if (currentIndex > 0) {
        await Future.delayed(
          const Duration(milliseconds: 800),
        ); // ⏳ Pequeño delay visual
        setState(() {
          currentIndex--;
        });
        await cargarTratamientoActual(); // 🔄 Carga la parcela anterior
      }
    } catch (e) {
      debugPrint('❌ Error en anteriorParcela: $e');
    } finally {
      setState(() {
        guardado = false;
      });
    }
  }

  Future<void> siguienteParcela() async {
    if (guardado) return; // 🚫 Previene doble click mientras guarda

    setState(() {
      guardado = true;
    });

    try {
      await guardarTratamientoActual(); // 🛡️ Guarda la parcela actual

      if (currentIndex < parcelas.length - 1) {
        await Future.delayed(
          const Duration(milliseconds: 800),
        ); // ⏳ Pequeño delay visual
        setState(() {
          currentIndex++;
        });
        await cargarTratamientoActual(); // 🔄 Carga nueva parcela
      } else {
        // 🚀 Última parcela
        await guardarTratamientoActual();

        final serieRef = FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .collection('series')
            .doc(widget.serieId);

        await serieRef.update({'fecha_cosecha': Timestamp.now()});

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder:
                (_) => AlertDialog(
                  title: const Text("¡Tratamiento Finalizado!"),
                  content: const Text(
                    "Has terminado todas las parcelas de todos los bloques.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (_) => const InicioTratamientoScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      child: const Text("Volver al inicio"),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error en siguienteParcela: $e');
    } finally {
      setState(() {
        guardado = false;
      });
    }
  }

  void monitorConexionParaSincronizar() {
    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        print("📶 Conexión detectada. Puedes sincronizar.");
        // Aquí luego llamas a sincronización real si lo deseas
      } else {
        print("⚠️ Sin conexión. Usando datos locales de Hive.");
      }
    });
  }

  Future<void> cargarTratamientoActualOffline() async {
    if (parcelas.isEmpty) return;

    final parcela = parcelas[currentIndex];
    final box = Hive.box('offline_tratamientos');
    final id =
        parcela['id']; // asegúrate de guardar esto al momento de persistir
    final data = box.get(id);

    if (data != null) {
      setState(() {
        raicesAController.text = data['raicesA'] ?? '';
        raicesBController.text = data['raicesB'] ?? '';
        pesoAController.text = data['pesoA'] ?? '';
        pesoBController.text = data['pesoB'] ?? '';
        pesoHojasController.text = data['pesoHojas'] ?? '';
        ndviController.text = data['ndvi'] ?? '';
        observacionesController.text = data['observaciones'] ?? '';
      });
    } else {
      limpiarFormulario();
    }
  }

  Future<void> sincronizarTratamientosPendientes() async {
    final keys = hiveBox.keys.where(
      (k) => k.toString().startsWith('tratamiento_'),
    );

    for (final key in keys) {
      final data = hiveBox.get(key);
      if (data != null && data['sincronizado'] == false) {
        try {
          final ref = FirebaseFirestore.instance
              .collection('ciudades')
              .doc(data['ciudadId'])
              .collection('series')
              .doc(data['serieId'])
              .collection('bloques')
              .doc(data['bloqueId'])
              .collection('parcelas')
              .doc(data['parcelaId'])
              .collection('tratamientos')
              .doc('actual');

          await ref.set(data);
          data['sincronizado'] = true;
          await hiveBox.put(key, data);
          print("✅ Sincronizado: $key");
        } catch (e) {
          print("❌ Error al sincronizar $key: $e");
        }
      }
    }
  }

  Future<void> cargarTodasLasParcelas() async {
    final box = Hive.box('offline_parcelas');
    final claveBloques = 'bloques_${widget.ciudadId}_${widget.serieId}';
    final claveParcelas = 'parcelas_${widget.ciudadId}_${widget.serieId}';

    final connectivity = await Connectivity().checkConnectivity();
    final online = connectivity != ConnectivityResult.none;

    List<dynamic> todasParcelas = [];

    if (online) {
      try {
        final bloquesSnap =
            await FirebaseFirestore.instance
                .collection('ciudades')
                .doc(widget.ciudadId)
                .collection('series')
                .doc(widget.serieId)
                .collection('bloques')
                .orderBy('nombre')
                .get();

        List<dynamic> bloquesParaHive = [];
        List<dynamic> parcelasParaHive = [];

        for (final bloque in bloquesSnap.docs) {
          final bloqueId = bloque.id;
          final bloqueData = bloque.data();
          final nombreBloque = bloqueData['nombre'] ?? '...';

          // 🔥 Guardamos el nombre del bloque
          nombresBloques[bloqueId] = nombreBloque;
          bloquesParaHive.add({'id': bloqueId, 'nombre': nombreBloque});

          final parcelasSnap =
              await bloque.reference
                  .collection('parcelas')
                  .orderBy('numero')
                  .get();

          for (final p in parcelasSnap.docs) {
            final data = p.data();
            data['id'] = p.id;
            data['bloque'] = bloqueId;
            parcelasParaHive.add(data);
            todasParcelas.add(
              p,
            ); // 🔥 Aquí agregamos TODAS las parcelas de TODOS los bloques
          }
        }

        // Guardamos respaldo en Hive
        await box.put(claveBloques, bloquesParaHive);
        await box.put(claveParcelas, parcelasParaHive);
      } catch (e) {
        print("❌ Error online al cargar parcelas: $e");
      }
    } else {
      // 📴 Modo offline
      final bloquesOffline = box.get(claveBloques) ?? [];
      final parcelasOffline = box.get(claveParcelas) ?? [];

      for (final bloque in bloquesOffline) {
        nombresBloques[bloque['id']] = bloque['nombre'];
      }

      todasParcelas = parcelasOffline;
    }

    // 🔥 Buscamos la posición exacta combinando bloque y número de parcela
    final index = todasParcelas.indexWhere((p) {
      final data =
          (p is DocumentSnapshot)
              ? p.data() as Map<String, dynamic>?
              : p as Map<String, dynamic>;

      final bloque =
          (p is DocumentSnapshot) ? p.reference.parent.parent?.id : p['bloque'];

      return bloque == widget.bloqueId &&
          int.tryParse(data?['numero']?.toString() ?? '') ==
              widget.parcelaDesde;
    });

    setState(() {
      parcelas = todasParcelas;
      currentIndex = (index != -1) ? index : 0;
    });

    await cargarTratamientoActual();
  }

  Widget _buildInput(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    bool isNumeric = false,
  }) {
    return GestureDetector(
      onTap: () {
        if (isNumeric) {
          setState(() => focusedController = controller);

          showModalBottomSheet(
            context: context,
            backgroundColor: Colors.black,
            isScrollControlled: true,
            builder: (_) {
              return Padding(
                padding: const EdgeInsets.all(4),
                child:
                    label == "NDVI"
                        ? CustomNDVIPad(
                          initialValue: controller.text,
                          onChanged: (val) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                controller.text = val;
                              });
                            });
                          },
                        )
                        : CustomNumPad(
                          initialValue: controller.text,
                          onChanged: (val) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                controller.text = val;
                              });
                            });
                          },
                        ),
              );
            },
          );
        }
      },
      child: AbsorbPointer(
        absorbing: isNumeric,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: isNumeric ? TextInputType.none : TextInputType.text,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(fontSize: 20, color: Colors.white),
              filled: true,
              fillColor: Colors.black,
              contentPadding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 25,
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white, width: 5),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.cyanAccent, width: 5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputPair(
    String label1,
    TextEditingController controller1,
    String label2,
    TextEditingController controller2, {
    bool isNumeric = false,
  }) {
    return Row(
      children: [
        Expanded(child: _buildInput(label1, controller1, isNumeric: isNumeric)),
        const SizedBox(width: 15),
        Expanded(child: _buildInput(label2, controller2, isNumeric: isNumeric)),
      ],
    );
  }

  void limpiarFormulario() {
    raicesAController.clear();
    raicesBController.clear();
    pesoAController.clear();
    pesoBController.clear();
    pesoHojasController.clear();
    ndviController.clear();
    observacionesController.clear();
  }

  void irAEvaluacionDano() async {
    final cantidadA = int.tryParse(raicesAController.text.trim()) ?? 0;
    final cantidadB = int.tryParse(raicesBController.text.trim()) ?? 0;
    final totalRaices = cantidadA + cantidadB;

    final parcela = parcelas[currentIndex];

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => EvaluacionDanoScreen(
              parcelaRef: parcela.reference,
              totalRaices: totalRaices,
              ciudadId: widget.ciudadId,
              serieId: widget.serieId,
            ),
      ),
    );

    // Puedes hacer algo al volver, como refrescar la UI
    if (resultado == 'guardado' || resultado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Evaluación guardada correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() {
        // Opcional: refrescar algo visual o recargar datos si quieres
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (parcelas.isEmpty || currentIndex >= parcelas.length) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final parcela = parcelas[currentIndex];
    final String fechaActual = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final cantidadA = int.tryParse(raicesAController.text.trim()) ?? 0;
    final cantidadB = int.tryParse(raicesBController.text.trim()) ?? 0;
    final totalRaices = cantidadA + cantidadB;

    final pesoA = double.tryParse(pesoAController.text.trim()) ?? 0.0;
    final pesoB = double.tryParse(pesoBController.text.trim()) ?? 0.0;
    final pesoTotal = pesoA + pesoB;

    final parcelaData =
        parcelas.isNotEmpty
            ? parcelas[currentIndex].data() as Map<String, dynamic>
            : <String, dynamic>{};

    final numeroFicha =
        parcelaData.containsKey('numero_ficha')
            ? parcelaData['numero_ficha']?.toString() ?? '-'
            : '-';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: "Volver atrás",
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: "Refrescar datos",
                  onPressed: () async {
                    await cargarCiudadYSerie();
                    await cargarTodasLasParcelas();
                    await cargarTratamientoActual();

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("✅ Datos actualizados"),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(width: 8),
                // Título dinámico (tratamiento y bloque)
                Expanded(
                  child: Text(
                    "T ${obtenerCampoActual('numero_tratamiento')} - BLOQUE ${obtenerNombreBloqueActual()}",

                    style: const TextStyle(fontSize: 18, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Ciudad y Serie alineadas a la derecha
                if (ciudad != null && serie != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        ciudad!['nombre'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        serie!['nombre'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "N° Ficha: $numeroFicha",
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fechaActual,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              _buildInputPair(
                "N° Raíces 1",
                raicesAController,
                "N° Raíces 2",
                raicesBController,
                isNumeric: true,
              ),
              _buildInputPair(
                "Peso Raíces 1 (kg)",
                pesoAController,
                "Peso Raíces 2 (kg)",
                pesoBController,
                isNumeric: true,
              ),
              _buildInputPair(
                "Peso hojas (kg)",
                pesoHojasController,
                "NDVI",
                ndviController,
                isNumeric: true,
              ),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "TOTAL RAÍCES: $totalRaices",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "TOTAL PESO RAÍCES: ${pesoTotal.toStringAsFixed(2)} kg",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Botón RETROCEDER
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                (currentIndex > 0 && !guardado)
                                    ? () => anteriorParcela()
                                    : null,
                            icon: const Icon(
                              Icons.arrow_back,
                              size: 34,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "ANTERIOR",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 12), // Espacio entre botones
                        // Botón SIGUIENTE
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                guardado ? null : () => siguienteParcela(),
                            icon: const Icon(
                              Icons.save_alt,
                              size: 34,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "SIGUIENTE ➡️",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 15),
              _buildInput(
                "Observaciones",
                observacionesController,
                maxLines: 1,
              ),

              const SizedBox(height: 15),
              Row(
                children: [
                  // Botón LIMPIAR DATOS
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          raicesAController.clear();
                          raicesBController.clear();
                          pesoAController.clear();
                          pesoBController.clear();
                          pesoHojasController.clear();
                          ndviController.clear();
                          observacionesController.clear();
                          mensaje = "🧹 Formulario limpiado.";
                          focusedController = null;
                        });
                      },
                      icon: const Icon(
                        Icons.delete_forever,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        "LIMPIAR DATOS",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 16), // Espacio entre los botones
                  // Botón QUINLEI
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: irAEvaluacionDano,
                      icon: const Icon(
                        Icons.analytics_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: const Text(
                        "QUINLEI",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (mensaje.isNotEmpty)
                Center(
                  child: Text(
                    mensaje,
                    style: TextStyle(
                      fontSize: 24,
                      color:
                          mensaje.startsWith("✅")
                              ? Colors.greenAccent
                              : Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomNumPad extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;

  const CustomNumPad({
    Key? key,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<CustomNumPad> createState() => _CustomNumPadState();
}

class _CustomNumPadState extends State<CustomNumPad> {
  late String current;

  @override
  void initState() {
    super.initState();
    current = widget.initialValue;
  }

  void _input(String val) {
    setState(() {
      current += val;
      widget.onChanged(current); // Actualiza en tiempo real
    });
  }

  void _backspace() {
    setState(() {
      if (current.isNotEmpty) {
        current = current.substring(0, current.length - 1);
        widget.onChanged(current);
      }
    });
  }

  void _submit() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      '7',
      '8',
      '9',
      '4',
      '5',
      '6',
      '1',
      '2',
      '3',
      '0',
      '.',
      'BORRAR',
    ];

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 18),
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: Text(
              current,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 46,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            itemCount: keys.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              final key = keys[index];
              return ElevatedButton(
                onPressed: () {
                  if (key == 'BORRAR') {
                    _backspace();
                  } else {
                    _input(key);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: key == 'BORRAR' ? Colors.red : Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(key),
              );
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                textStyle: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              child: const Text("ACEPTAR"),
            ),
          ),
        ],
      ),
    );
  }
}

class CustomNDVIPad extends StatefulWidget {
  final String initialValue;
  final Function(String) onChanged;

  const CustomNDVIPad({
    Key? key,
    required this.initialValue,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<CustomNDVIPad> createState() => _CustomNDVIPadState();
}

class _CustomNDVIPadState extends State<CustomNDVIPad> {
  late String current;
  String? error;

  @override
  void initState() {
    super.initState();
    current = widget.initialValue;
    _validate();
  }

  bool _isKeyDisabled(String key) {
    if (key == 'BORRAR') return false;
    if (current.length >= 4) return true;
    if (key == '.' && current.contains('.')) return true;
    return false;
  }

  void _input(String val) {
    // Si se escribe '1' como primer dígito, completar a '1.00'
    if (val == '1' && current.isEmpty) {
      setState(() {
        current = '1.00';
        _validate();
        widget.onChanged(current);
      });
      return;
    }

    // No permitir más de 4 caracteres (excepto si es autocompletado como 1.00)
    if (current.length >= 4) return;
    if (val == '.' && current.contains('.')) return;

    String next = current + val;

    // Asegura que el primer carácter sea 0 si no fue 1
    if (next.length == 1 && !(next == '0' || next == '1')) return;

    setState(() {
      current = next;
      _validate();
      widget.onChanged(current);
    });
  }

  void _backspace() {
    setState(() {
      if (current.isNotEmpty) {
        current = current.substring(0, current.length - 1);
        _validate();
        widget.onChanged(current);
      }
    });
  }

  void _validate() {
    final regex = RegExp(r'^(0(\.\d{1,2})?|1\.00)$');
    setState(() {
      if (regex.hasMatch(current)) {
        error = null;
      } else {
        error = "Formato inválido (ej: 0.75 o 1.00)";
      }
    });
  }

  void _submit() {
    _validate();
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text(error!, style: const TextStyle(fontSize: 20)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = [
      '7',
      '8',
      '9',
      '4',
      '5',
      '6',
      '1',
      '2',
      '3',
      '0',
      '.',
      'BORRAR',
    ];

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: error == null ? Colors.white : Colors.red,
                width: 3,
              ),
            ),
            child: Text(
              current,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 50,
                color: error == null ? Colors.white : Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (error != null)
            Text(
              error!,
              style: const TextStyle(color: Colors.redAccent, fontSize: 20),
            ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            itemCount: keys.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.6,
            ),
            itemBuilder: (context, index) {
              bool _isKeyDisabled(String key) {
                if (key == 'BORRAR') return false;
                if (current.length >= 4) return true;
                if (key == '.' && current.contains('.')) return true;
                return false;
              }

              final key = keys[index];
              return ElevatedButton(
                onPressed:
                    _isKeyDisabled(key)
                        ? null
                        : () => key == 'BORRAR' ? _backspace() : _input(key),

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                  foregroundColor:
                      key == 'BORRAR'
                          ? Colors.red
                          : const Color.fromARGB(255, 255, 255, 255),
                  textStyle: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: Text(key),
              );
            },
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text(
                "ACEPTAR",
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
