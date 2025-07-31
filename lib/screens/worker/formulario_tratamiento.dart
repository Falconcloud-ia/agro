import 'inicio_tratamiento.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'evaluacion_dano.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:controlgestionagro/data/hive_repository.dart';
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
  final HiveRepository hive = HiveRepository();
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
    hiveBox = hive.box('offline_tratamientos');
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

  Future<bool> hasConectivity() async {
    final connectivity = await Connectivity().checkConnectivity();
    return connectivity != ConnectivityResult.none;
  }

  //Sync2 aplicado
  Future<void> cargarCiudadYSerie() async {
    print("🔍 Iniciando metodo : cargarCiudadYSerie");
    print("🌆 widget.ciudadId: ${widget.ciudadId}");
    print("🧪 widget.serieId: ${widget.serieId}");

    final hayConexion = await hasConectivity();

    if (hayConexion) {
      try {
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

        final ciudadData = ciudadSnap.data();
        final serieData = serieSnap.data();

        print('🌆 ciudadData formulario_tratamiento: ${ciudadData.toString()}');
        print('📘 serieData formulario_tratamiento: ${serieData.toString()}');

        if (ciudadData != null && serieData != null) {
          setState(() {
            ciudad = Map<String, dynamic>.from(ciudadData);
            serie = Map<String, dynamic>.from(serieData);
          });

          print("🌐 Ciudad y serie cargadas online.");
        } else {
          print("⚠️ Los documentos existen pero están vacíos.");
        }
      } catch (e) {
        print("🛑 Error al cargar desde Firestore: $e");
      }
    } else {
      try {
        final ciudadBox = await Hive.openBox('offline_ciudades');
        final seriesBox = await Hive.openBox('offline_series');

        final ciudadRaw = ciudadBox.get(widget.ciudadId);
        final serieKey = '${widget.ciudadId}_${widget.serieId}';
        final serieRaw = seriesBox.get(serieKey);

        if (ciudadRaw is Map && serieRaw is Map) {
          print(
            "🧾 ciudadRaw (desde Hive): ${ciudadRaw.runtimeType} → $ciudadRaw",
          );
          print(
            "🧾 serieRaw (desde Hive): ${serieRaw.runtimeType} → $serieRaw",
          );

          setState(() {
            ciudad = Map<String, dynamic>.from(ciudadRaw);
            serie = Map<String, dynamic>.from(serieRaw);
          });

          print(" Datos cargados desde Hive:");
          print(" Ciudad offline: ${ciudad?['nombre']}");
          print(" Serie offline: ${serie?['nombre']}");
        } else {
          print(" No se encontraron datos en Hive para la ciudad o serie");
        }
      } catch (e) {
        print("Error al cargar desde Hive: $e");
      }
    }
  }

  //Sync2 aplicado
  String obtenerCampoActual(String campo) {
    print("🔍 Iniciando metodo : obtenerCampoActual");
    if (parcelas.isEmpty || currentIndex >= parcelas.length) {
      print("⚠️ Lista de parcelas vacía o índice fuera de rango.");
      return '-';
    }

    final current = parcelas[currentIndex];

    try {
      if (current is DocumentSnapshot) {
        final data = current.data() as Map<String, dynamic>?;
        return data?[campo]?.toString() ?? '-';
      } else if (current is Map) {
        // Forzar cast y acceso seguro
        final data = Map<String, dynamic>.from(current);
        return data[campo]?.toString() ?? '-';
      } else if (current is Map) {
        final data = Map<String, dynamic>.from(current);
        final valor = data[campo];
        print("📦 Obtenido desde Hive → campo '$campo': $valor");
        return valor?.toString() ?? '-';
      } else {
        print("⚠️ Tipo inesperado en 'parcelas': ${current.runtimeType}");
      }
    } catch (e) {
      print("❌ Error al obtener campo '$campo': $e");
      return '-';
    }

    return '-';
  }

  //Sync2 aplicado
  String obtenerNombreBloqueActual() {
    print("🔍 Iniciando metodo : obtenerNombreBloqueActual");

    if (parcelas.isEmpty || currentIndex >= parcelas.length) {
      print("⚠️ Lista de parcelas vacía o índice fuera de rango.");
      return '...';
    }

    final current = parcelas[currentIndex];
    try {
      if (current is DocumentSnapshot) {
        final bloqueId = current.reference.parent.parent?.id;
        final nombre = nombresBloques[bloqueId];

        print(
          "🏢 Firestore → bloqueId: $bloqueId → nombre: ${nombre ?? '...'}",
        );
        return nombre ?? '...';
      } else if (current is Map) {
        final data = Map<String, dynamic>.from(current);
        final bloqueId = data['bloqueId'];
        final nombre = nombresBloques[bloqueId];
        print("📦 Hive → bloqueId: $bloqueId → nombre: ${nombre ?? '...'}");
        return nombre ?? '...';
      } else {
        print("⚠️ Tipo inesperado en 'parcelas': ${current.runtimeType}");
      }
    } catch (e) {
      print("❌ Error al obtener nombre del bloque actual: $e");
    }

    return '...';
  }

  //Sync2 aplicado
  Future<void> guardarTratamientoActual() async {
    print("🔍 Iniciando metodo : guardarTratamientoActual");

    if (parcelas.isEmpty || currentIndex >= parcelas.length) {
      print("⚠️ Lista de parcelas vacía o índice fuera de rango.");
      return;
    }

    final parcela = parcelas[currentIndex];
    final online = await hasConectivity();

    // Obtener ID de la parcela
    final parcelaId =
        (parcela is DocumentSnapshot)
            ? parcela.id
            : (parcela as Map)['parcelaId']?.toString() ?? '';

    // Obtener bloqueId según el origen
    String bloqueId = '';

    try {
      if (parcela is DocumentSnapshot) {
        bloqueId =
            parcela.reference.parent.parent?.id ??
            (parcela.data() as Map<String, dynamic>?)?['bloqueId'] ??
            widget.bloqueId ??
            '';
      } else if (parcela is Map) {
        final data = Map<String, dynamic>.from(parcela);
        bloqueId = data['bloqueId'] ?? widget.bloqueId ?? '';
      }

      if (bloqueId.isEmpty) {
        print("❌ No se pudo determinar el bloqueId. Abortando guardado.");
        return;
      }
    } catch (e) {
      print("🛑 Error al determinar bloqueId: $e");
      return;
    }

    final String key =
        '${widget.ciudadId}_${widget.serieId}_${bloqueId}_$parcelaId';
    print("🔐 Clave generada para guardar tratamiento: $key");
    Map<String, dynamic> tratamientoPrevio = {};

    try {
      if (online && parcela is DocumentSnapshot) {
        final ref = parcela.reference.collection('tratamientos').doc('actual');
        final doc = await ref.get();
        if (doc.exists && doc.data() != null) {
          tratamientoPrevio = Map<String, dynamic>.from(doc.data()!);
          print("📡 Tratamiento previo obtenido online: $tratamientoPrevio");
        }
      } else {
        final dataOffline = hiveBox.get(key);
        if (dataOffline != null) {
          tratamientoPrevio = Map<String, dynamic>.from(dataOffline);
          print(
            "📦 Tratamiento previo obtenido desde Hive: $tratamientoPrevio",
          );
        }else{
          tratamientoPrevio = <String, dynamic>{};
          print("📦 No se encontró tratamiento previo en Hive. Se usará uno vacío.");
        }
      }
    } catch (e) {
      print("⚠️ Error al cargar tratamiento previo: $e");
    }

    final nuevoData = {
      ...tratamientoPrevio,
      if (raicesAController.text.trim().isNotEmpty)
        'raicesA': raicesAController.text.trim(),
      if (raicesBController.text.trim().isNotEmpty)
        'raicesB': raicesBController.text.trim(),
      'pesoA': pesoAController.text.trim(),
      'pesoB': pesoBController.text.trim(),
      'pesoHojas': pesoHojasController.text.trim(),
      'ndvi': ndviController.text.trim(),
      'observaciones': observacionesController.text.trim(),
      'fecha': DateTime.now().toIso8601String(),
      'usuario': userId,
    };

    bool persistioEnFirestore = false;
    try {
      if (online && parcela is DocumentSnapshot) {
        final ref = parcela.reference.collection('tratamientos').doc('actual');
        await ref.set(nuevoData);
        persistioEnFirestore = true;
        print("☁️ Tratamiento guardado en Firestore.");
      }
    } catch (e) {
      print("❌ Error al guardar tratamiento en Firestore: $e");
    }

    try {
      final dataFinal = {...nuevoData, 'flag_sync': !persistioEnFirestore};
      await hiveBox.put(key, dataFinal);
      print('💾 Tratamiento guardado en Hive con key: $key');
    } catch (e) {
      print("❌ Error al guardar tratamiento local: $e");
    }
  }

  Future<void> cargarTratamientoActual() async {
    print("🔍 Iniciando metodo : cargarTratamientoActual");

    if (parcelas.isEmpty || currentIndex >= parcelas.length) {
      print("⚠️ Lista de parcelas vacía o índice fuera de rango.");
      return;
    }

    final parcela = parcelas[currentIndex];

    // Obtener ID de la parcela (soporta tanto DocumentSnapshot como mapa local)

    final String parcelaId;
    try {
      if (parcela is DocumentSnapshot) {
        parcelaId = parcela.id;
      } else if (parcela.containsKey('parcelaId') &&
          parcela['parcelaId'] != null) {
        parcelaId = parcela['parcelaId'];
      } else {
        print("No se encontró el id de la parcela en modo offline.");
        return;
      }
    } catch (e) {
      print("🛑 Error al obtener parcelaId: $e");
      return;
    }

    // Obtener bloqueId de forma segura
    late final String bloqueId;
    try {
      if (parcela is DocumentSnapshot) {
        bloqueId =
            parcela.reference.parent.parent?.id ??
            (parcela.data() as Map<String, dynamic>?)?['bloqueId'] ??
            widget.bloqueId ??
            '';
      } else if (parcela is Map) {
        final data = Map<String, dynamic>.from(parcela);
        bloqueId = data['bloqueId'] ?? data['bloque'] ?? widget.bloqueId ?? '';
      }

      if (bloqueId.isEmpty) {
        print("❌ No se pudo determinar el bloqueId.");
        return;
      }
    } catch (e) {
      print("🛑 Error al obtener bloqueId: $e");
      return;
    }

    // Se genera la clave para identificar el tratamiento en Hive
    final String key =
        '${widget.ciudadId}_${widget.serieId}_${bloqueId}_$parcelaId';
    print("Clave generada para tratamiento: $key");

    final hayConexion = await hasConectivity();

    final hiveBox = Hive.box('offline_tratamientos');

    // Si hay conexión y la parcela proviene de Firestore, se intenta cargar online
    if (hayConexion && parcela is DocumentSnapshot) {
      try {
        final doc =
            await parcela.reference
                .collection('tratamientos')
                .doc('actual')
                .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          print("Tratamiento cargado online desde Firestore: $data");

          // Guarda una copia del tratamiento en Hive para modo offline
          try {
            await hiveBox.put(key, {...data, 'flag_sync': false});
            print("Tratamiento sincronizado y guardado en Hive con clave $key");
          } catch (e) {
            print("Error al guardar tratamiento en Hive: $e");
          }

          // Carga los valores en los controladores de texto
          cargarEnControladores(data);
          return;
        } else {
          print("El documento 'actual' no existe o está vacío en Firestore.");
        }
      } catch (e) {
        print("Error al cargar tratamiento online: $e");
      }
    }

    // Modo offline: intenta cargar el tratamiento desde Hive
    try {
      final data = hiveBox.get(key);

      if (data != null) {
        print("Tratamiento cargado desde Hive (offline): $data");
        cargarEnControladores(data);
      } else {
        print("No hay tratamiento guardado en Hive con la clave: $key");
        limpiarFormulario();
      }
    } catch (e) {
      print("Error al cargar tratamiento desde Hive: $e");
      limpiarFormulario();
    }
  }

  void cargarEnControladores(Map<String, dynamic> data) {
    print("🔍 Iniciando metodo : cargarEnControladores");

    setState(() {
      raicesAController.text = (data['raicesA'] ?? '').toString();
      raicesBController.text = (data['raicesB'] ?? '').toString();
      pesoAController.text = (data['pesoA'] ?? '').toString();
      pesoBController.text = (data['pesoB'] ?? '').toString();
      pesoHojasController.text = (data['pesoHojas'] ?? '').toString();
      ndviController.text = (data['ndvi'] ?? '').toString();
      observacionesController.text = (data['observaciones'] ?? '').toString();
    });
  }

  Future<void> anteriorParcela() async {
    print("🔍 Iniciando metodo : anteriorParcela");

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
    print("🔍 Iniciando metodo : siguienteParcela");

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

        final connectivity = await Connectivity().checkConnectivity();
        final online = connectivity != ConnectivityResult.none;
        final fechaCosecha = Timestamp.now();
        bool persistioEnFirestore = false;

        if (online) {
          try {
            final serieRef = FirebaseFirestore.instance
                .collection('ciudades')
                .doc(widget.ciudadId)
                .collection('series')
                .doc(widget.serieId);

            await serieRef.update({'fecha_cosecha': fechaCosecha});
            persistioEnFirestore = true;
          } catch (e) {
            print("⚠️ Error al actualizar fecha_cosecha en Firestore: $e");
          }
        }

        // Guardar también en Hive con flag_sync false (ya sincronizado)
        final seriesBox = await Hive.openBox('offline_series');
        final serieKey = '${widget.ciudadId}_${widget.serieId}';

        final serieLocal = Map<String, dynamic>.from(
          seriesBox.get(serieKey) ?? {},
        );
        serieLocal['fecha_cosecha'] = DateTime.now();
        serieLocal['flag_sync'] = !persistioEnFirestore;
        await seriesBox.put(serieKey, serieLocal);
        print("💾 fecha_cosecha actualizada en Hive con flag_sync: false");

        // Mostrar mensaje final sin importar si está online u offline
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
    print("🔍 Iniciando metodo : monitorConexionParaSincronizar");

    Connectivity().onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        print("📶 Conexión detectada. Puedes sincronizar.");
        // Aquí luego llamas a sincronización real si lo deseas
      } else {
        print("⚠️ Sin conexión. Usando datos locales de Hive.");
      }
    });
  }

  //trabajar en esta funcion para cargar los datos del tratamiento.
  /*Future<void> cargarTratamientoActualOffline() async {
    print("🔍 Iniciando metodo : cargarTratamientoActualOffline");

    if (parcelas.isEmpty) return;
    final parcela = parcelas[currentIndex];
    final box = hive.box('offline_tratamientos');

    final id = parcela['id'];
    final clave =
        'tratamiento_${widget.ciudadId}_${widget.serieId}_${widget.bloqueId}_$id';

    final data = box.get(clave);

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
    print("🔍 Iniciando metodo : sincronizarTratamientosPendientes");

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

   */
  Future<void> _refrescarParcelaDesdeHive() async {
    if (parcelas.isEmpty || currentIndex >= parcelas.length) return;

    final parcela = parcelas[currentIndex];
    if (parcela is! Map) return; // Solo aplica a modo offline

    final bloqueId = parcela['bloqueId'] ?? parcela['bloque'];
    final parcelaId = parcela['parcelaId'];
    if (bloqueId == null || parcelaId == null) return;

    final key = '${widget.ciudadId}_${widget.serieId}_${bloqueId}_$parcelaId';
    final box = Hive.box('offline_parcelas');
    final data = box.get(key);

    if (data != null) {
      setState(() {
        parcelas[currentIndex] = Map<String, dynamic>.from(data);
      });
      print("🔁 Parcela actual recargada desde Hive: $key");
    }
  }

  Future<void> cargarTodasLasParcelas() async {
    print("🔍 Iniciando metodo : cargarTodasLasParcelas");

    final box = hive.box('offline_parcelas');
    final bloquesBox = hive.box('offline_bloques');
    final prefix = '${widget.ciudadId}_${widget.serieId}_';

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

        for (final bloque in bloquesSnap.docs) {
          final bloqueId = bloque.id;
          final bloqueData = bloque.data();
          final nombreBloque = bloqueData['nombre'] ?? '...';

          nombresBloques[bloqueId] = nombreBloque;

          final parcelasSnap =
              await bloque.reference
                  .collection('parcelas')
                  .orderBy('numero')
                  .get();

          for (final p in parcelasSnap.docs) {
            final data = p.data();
            data['id'] = p.id;
            data['bloque'] = bloqueId;
            todasParcelas.add(p); // DocumentSnapshot (online)
          }
        }
      } catch (e) {
        print("❌ Error online al cargar parcelas: $e");
      }
    } else {
      // 📴 CARGA OFFLINE INDIVIDUAL POR CLAVE
      print("📴 Cargando parcelas desde Hive (offline)...");
      print("🔍 Prefijo esperado: $prefix");
      print("📦 Claves encontradas en Hive:");
      print(box.keys);

      final claves = box.keys.where((k) => k.toString().startsWith(prefix));
      final parcelasOffline =
          claves.map((k) {
              final data = box.get(k);
              return {
                ...Map<String, dynamic>.from(data), // ✅ Conversión explícita
                'bloque': data['bloque'] ?? widget.bloqueId,
              };
            }).toList()
            ..sort((a, b) {
              final aNum =
                  int.tryParse(a['numero_ficha']?.toString() ?? '') ?? 0;
              final bNum =
                  int.tryParse(b['numero_ficha']?.toString() ?? '') ?? 0;
              return aNum.compareTo(bNum);
            });
      ;

      todasParcelas = parcelasOffline;

      // También cargamos los nombres de bloques desde Hive
      final clavesBloques = bloquesBox.keys.where(
        (k) => k.toString().startsWith('${widget.ciudadId}_${widget.serieId}_'),
      );
      for (final k in clavesBloques) {
        final b = bloquesBox.get(k);
        if (b is Map && b['bloqueId'] != null && b['nombre'] != null) {
          nombresBloques[b['bloqueId']] = b['nombre'];
        }
      }
    }

    // Buscar la parcela inicial según bloque y número

    final index = todasParcelas.indexWhere((p) {
      Map<String, dynamic> data;
      String? bloqueId;

      if (p is DocumentSnapshot) {
        data = p.data() as Map<String, dynamic>;
        bloqueId = p.reference.parent.parent?.id;
      } else {
        data = Map<String, dynamic>.from(p);
        bloqueId = data['bloqueId'] ?? data['bloque'];
      }

      final numeroTratamiento = int.tryParse(data['numero_tratamiento']?.toString() ?? '');
      final targetTratamiento = int.tryParse(widget.numeroTratamiento ?? '');
      return bloqueId == widget.bloqueId && numeroTratamiento == targetTratamiento;
    });

    if (index == -1) {
      print(
        "⚠️ No se encontró la parcela de inicio: bloque=${widget.bloqueId}, numero=${widget.parcelaDesde}",
      );
      print("📦 Parcelas disponibles (offline): ${todasParcelas.length}");
      for (final p in todasParcelas) {
        final d =
            (p is DocumentSnapshot)
                ? p.data() as Map<String, dynamic>
                : Map<String, dynamic>.from(p);
        print("🔹 Parcela: bloque=${d['bloque']}, numero=${d['numero']}");
      }
    }

    setState(() {
      parcelas = todasParcelas;
      currentIndex = (index != -1) ? index : 0;
    });

    print(
      "✅ Parcelas cargadas: ${parcelas.length}, index inicial: $currentIndex",
    );

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
                  permitirDecimales: !(label == "N° Raíces 1" || label == "N° Raíces 2"),
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
    print("🔍 Iniciando metodo : limpiarFormulario");

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
    final isOnline = await hasConectivity();

    final resultado = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EvaluacionDanoScreen(
          totalRaices: totalRaices,
          ciudadId: widget.ciudadId,
          serieId: widget.serieId,
          parcelaRef: isOnline ? parcela.reference : null,
          parcelaLocal: isOnline ? null : parcela,
        ),
      ),
    );

    if (resultado == 'anterior') {
      await _refrescarParcelaDesdeHive(); // 👈 para ver los cambios antes de retroceder
      await anteriorParcela();
    } else if (resultado == 'siguiente') {
      await _refrescarParcelaDesdeHive(); // 👈 para ver los cambios antes de avanzar
      await siguienteParcela();
    } else {
      await _refrescarParcelaDesdeHive(); // 👈 para actualizar la vista si solo se guardó
      setState(() {
        mensaje = '✅ Evaluación de daño guardada correctamente';
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
            ? (parcelas[currentIndex] is DocumentSnapshot
                ? (parcelas[currentIndex] as DocumentSnapshot).data()
                    as Map<String, dynamic>
                : parcelas[currentIndex] as Map<String, dynamic>)
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
  final bool permitirDecimales; // ✅ nuevo parámetro

  const CustomNumPad({
    Key? key,
    required this.initialValue,
    required this.onChanged,
    this.permitirDecimales = true, // ✅ valor por defecto: permite decimales
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
    if (val == '.' && !widget.permitirDecimales) return;

    // Solo permitir dígitos o punto
    if (!RegExp(r'^\d$').hasMatch(val) && val != '.') return;

    if (widget.permitirDecimales) {
      if (val == '.' && current.contains('.')) return; // No más de un punto
      if (val == '.' && current.isEmpty) return;       // No punto al inicio

      // Limitar a 2 decimales
      if (current.contains('.')) {
        final partes = current.split('.');
        if (partes.length == 2 && partes[1].length >= 2) return;
      }
    }

    setState(() {
      current += val;
      widget.onChanged(current);
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
    // Mostrar el "." solo si se permiten decimales
    final keys = widget.permitirDecimales
        ? ['7', '8', '9', '4', '5', '6', '1', '2', '3', '0', '.', '⌫']
        : ['7', '8', '9', '4', '5', '6', '1', '2', '3', '0', '⌫', ''];

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
                onPressed: key.isEmpty
                    ? null
                    : () {
                  if (key == '⌫') {
                    _backspace();
                  } else {
                    _input(key);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, // Fondo negro
                  foregroundColor: key == '⌫' ? Colors.red : Colors.white, // Números blancos
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
    if (key == '⌫') return false;
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
      '⌫',
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
                if (key == '⌫') return false;
                if (current.length >= 4) return true;
                if (key == '.' && current.contains('.')) return true;
                return false;
              }

              final key = keys[index];
              return ElevatedButton(
                onPressed:
                    _isKeyDisabled(key)
                        ? null
                        : () => key == '⌫' ? _backspace() : _input(key),

                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color.fromARGB(255, 0, 0, 0),
                  foregroundColor:
                      key == '⌫'
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
