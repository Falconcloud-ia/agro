import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'formulario_tratamiento.dart';
import '../login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:controlgestionagro/models/tratamiento_local.dart';
import 'package:controlgestionagro/models/query_document_snapshot_fake.dart';
import 'package:controlgestionagro/services/offline_sync_service.dart';
import 'package:controlgestionagro/data/hive_repository.dart';
import 'package:hive/hive.dart';

class InicioTratamientoScreen extends StatefulWidget {
  const InicioTratamientoScreen({super.key});

  @override
  State<InicioTratamientoScreen> createState() =>
      _InicioTratamientoScreenState();
}

class _InicioTratamientoScreenState extends State<InicioTratamientoScreen> {
  String? ciudadSeleccionada;
  String? serieSeleccionada;
  String? bloqueSeleccionado;
  String? parcelaSeleccionada;

  List<dynamic> ciudades = [];
  List<dynamic> series = [];
  List<String> bloques = [];
  List<dynamic> parcelas = [];

  String numeroFicha = '';
  String numeroTratamiento = '';
  final TextEditingController superficieController = TextEditingController(
    text: "10",
  );

  final HiveRepository hive = HiveRepository();

  Box get _ciudadesBox => hive.box('offline_ciudades');

  Box get _seriesBox => hive.box('offline_series');

  Box get _bloquesBox => hive.box('offline_bloques');

  Box get _parcelasBox => hive.box('offline_parcelas');

  @override
  void initState() {
    super.initState();
    cargarCiudades();
  }

  Future<void> guardarSuperficieEnSerie() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    final superficie = superficieController.text.trim();
    final box = hive.box('offline_series');
    final key = 'series_$ciudadSeleccionada';

    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;

    if (hayConexion) {
      try {
        // 🔄 Actualiza en Firestore
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada!)
            .collection('series')
            .doc(serieSeleccionada!)
            .update({'superficie': superficie});

        // 🔄 También actualiza en Hive
        final lista = box.get(key) ?? [];
        final actualizada =
            (lista as List).map((e) {
              if (e['id'] == serieSeleccionada) {
                return {...e, 'superficie': superficie};
              }
              return e;
            }).toList();
        await box.put(key, actualizada);
      } catch (e) {
        print("❌ Error al guardar superficie online: $e");
      }
    } else {
      // 📴 Modo offline: guarda solo en Hive
      final lista = box.get(key) ?? [];
      final actualizada =
          (lista as List).map((e) {
            if (e['id'] == serieSeleccionada) {
              return {...e, 'superficie': superficie};
            }
            return e;
          }).toList();
      await box.put(key, actualizada);
      print("📦 Superficie guardada en Hive offline.");
    }
  }

  Future<void> cargarCiudades() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';
    final firestore = FirebaseFirestore.instance;

    if (hayConexion) {
      final snapshot =
          await firestore
              .collection('ciudades')
              .get(); //Obtiene ciudades desde caché almacenado en firestore para casos con o sin conxión
      setState(() => ciudades = snapshot.docs);

      final ciudadMapList =
          snapshot.docs
              .map((doc) => {'id': doc.id, 'nombre': doc['nombre']})
              .toList();
    } else {
      final ciudadMapList =
          _ciudadesBox.keys.map((key) {
            final data = _ciudadesBox.get(key);
            return {'id': key, 'nombre': data['nombre']};
          }).toList();

      setState(() => ciudades = ciudadMapList);
    }
  }

  Future<void> cargarSuperficieDesdeSerie() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;
    final box = hive.box('offline_series');

    if (hayConexion) {
      final doc =
          await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadSeleccionada!)
              .collection('series')
              .doc(serieSeleccionada!)
              .get();

      final data = doc.data();
      if (data != null && data.containsKey('superficie')) {
        final superficie = data['superficie'].toString();
        superficieController.text = superficie;

        // 🔄 Guarda en Hive
        final lista = box.get('series_$ciudadSeleccionada') ?? [];
        final actualizada =
            (lista as List).map((e) {
              if (e['id'] == serieSeleccionada) {
                return {...e, 'superficie': superficie};
              }
              return e;
            }).toList();
        await box.put('series_$ciudadSeleccionada', actualizada);
      } else {
        superficieController.text = '10';
      }
    } else {
      // 🔄 Lee desde Hive
      final lista = box.get('series_$ciudadSeleccionada') ?? [];
      final serie = (lista as List).firstWhere(
        (e) => e['id'] == serieSeleccionada,
        orElse: () => {},
      );
      superficieController.text = serie['superficie']?.toString() ?? '10';
    }
  }

  Future<void> cargarSeries() async {
    if (ciudadSeleccionada == null) return;

    final hayConexion =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;
    if (hayConexion) {
      final snapshot = await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadSeleccionada)
              .collection('series')
              .get();

      setState(() => series = snapshot.docs);
    }else {
      final seriesMapList = _seriesBox.keys
          .where((key) => key.contains(ciudadSeleccionada))
          .map((key) {
        final rawData = _seriesBox.get(key);
        if (rawData is Map) {
          final data = Map<String, dynamic>.from(rawData); // fuerza el tipo
          return {
            'id': data['serieId'],
            'nombre': data['nombre'],
            'ciudadId': data['ciudadId'],
          };
        } else {
          print('❌ Entrada inválida en Hive para key: $key → $rawData');
          return null;
        }
      })
          .whereType<Map<String, dynamic>>()
          .where((data) => data['ciudadId'] == ciudadSeleccionada)
          .toList();

      setState(() => series = seriesMapList);
  print('📦 Series offline filtradas (por clave): $seriesMapList');
  setState(() => series = seriesMapList);
}
  }

  Future<void> cargarBloques() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    final hayConexion =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;
    if (hayConexion) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadSeleccionada)
              .collection('series')
              .doc(serieSeleccionada)
              .collection('bloques')
              .get();

      final bloquesList = snapshot.docs.map((doc) => doc.id).toList();
      print('🧱 bloquesList: $bloquesList');

      setState(() => bloques = bloquesList);
    } else {

      final bloquesList =_bloquesBox.keys.where((key) => key.contains(serieSeleccionada)) // Filtra claves que contienen el ID de la serie
              .map((key) {
                final data = _bloquesBox.get(key);
                return data['bloqueId'];
              })
              .toList()
              .cast<String>();

      print('🧱 bloquesList: $bloquesList');
      setState(() => bloques = bloquesList);
    }
  }

  Future<void> cargarParcelas() async {
    if (bloqueSeleccionado == null) return;

    final hayConexion =
        (await Connectivity().checkConnectivity()) != ConnectivityResult.none;
    final key ='parcelas_${ciudadSeleccionada}_${serieSeleccionada}_$bloqueSeleccionado';

    if (hayConexion) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadSeleccionada!)
              .collection('series')
              .doc(serieSeleccionada!)
              .collection('bloques')
              .doc(bloqueSeleccionado!)
              .collection('parcelas')
              .orderBy('numero')
              .get();

      final docs = snapshot.docs;

      if (docs.any((doc) => !doc.data().containsKey('numero_tratamiento'))) {
        _mostrarDialogoFaltante('número de tratamiento');
        return;
        /*ANTES
        *
        *
        * else {
  final seriesMapList = _seriesBox.keys
      .where((key) => key.contains(ciudadSeleccionada))
      .map((key) {
        final data = _seriesBox.get(key);
        return {
          'id': data['serieId'],
          'nombre': data['nombre'],
          'ciudadId': data['ciudadId'],
        };
      })
      .where((data) =>
          data['ciudadId'] == ciudadSeleccionada) // filtro adicional para mayor seguridad
      .toList();

  print('📦 Series offline filtradas (por clave): $seriesMapList');
  setState(() => series = seriesMapList);
}*/




      }

      setState(() => parcelas = docs);

    } else {
      final keyPrefix ='${ciudadSeleccionada}_${serieSeleccionada}_${bloqueSeleccionado}_';
      final allKeys = _parcelasBox.keys;
      final matchingKeys = allKeys.where((k) => k.startsWith(keyPrefix));

      //TODO: Order by numero
      final list =
          matchingKeys.map((k) {
            final data = _parcelasBox.get(k);
            return {
              'id': k.split('_').last,
              'numero': data['numero'],
              'numero_tratamiento': data['numero_tratamiento'],
              'numero_ficha': data['numero_ficha'],
            };
          }).toList()
            ..sort((a, b) {
              final aNum = int.tryParse(a['numero'].toString()) ?? 0;
              final bNum = int.tryParse(b['numero'].toString()) ?? 0;
              return (aNum as int).compareTo(bNum as int);
            });;

      setState(() => parcelas = list);
    }
  }

  void _mostrarDialogoFaltante(String detalle) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("⚠️ Campo faltante"),
            content: Text("Este bloque contiene parcelas sin $detalle."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Aceptar"),
              ),
            ],
          ),
    );
  }

  Future<void> actualizarInfoParcela(String id) async {
    final doc = parcelas.firstWhere((p) => p.id == id);
    final data = doc.data() as Map<String, dynamic>?;

    if (data == null || !data.containsKey('numero_tratamiento')) {
      setState(() {
        numeroFicha = '';
        numeroTratamiento = '';
      });

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Campo faltante"),
              content: const Text(
                "Las parcelas de este bloque no tienen asignado el campo 'número de tratamiento'.\n\nPor favor, pide al administrador que lo genere antes de continuar.",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Aceptar"),
                ),
              ],
            ),
      );
      return;
    }

    setState(() {
      numeroFicha = data['numero_ficha']?.toString() ?? '';
      numeroTratamiento = data['numero_tratamiento']?.toString() ?? '';
    });
  }

  Future<bool> puedeGenerarNumerosFicha() async {
    if (bloqueSeleccionado != 'A' || parcelaSeleccionada == null) return false;

  // 1️⃣ Verifica que la parcela seleccionada sea la número 1
  final doc = parcelas.firstWhere((p) => obtenerId(p) == parcelaSeleccionada);
  final numeroParcela = int.tryParse(obtenerCampo(doc, 'numero')) ?? 0;
  if (numeroParcela != 1) return false;

  // 2️⃣ Verifica si hay conectividad
  final hayConexion =
      (await Connectivity().checkConnectivity()) != ConnectivityResult.none;

  if (hayConexion) {
    // 🔄 Versión online
    final bloquesSnapshot = await FirebaseFirestore.instance
        .collection('ciudades')
        .doc(ciudadSeleccionada!)
        .collection('series')
        .doc(serieSeleccionada!)
        .collection('bloques')
        .get();

    for (var bloqueDoc in bloquesSnapshot.docs) {
      final parcelasSnapshot = await bloqueDoc.reference
          .collection('parcelas')
          .where('numero_ficha', isGreaterThanOrEqualTo: 1)
          .limit(1)
          .get();

      if (parcelasSnapshot.docs.isNotEmpty) return false;
    }
    return true;
  } else {
    // 📦 Versión offline
    final bloqueKeys = _bloquesBox.keys.where((k) =>
        k.contains('${ciudadSeleccionada}_${serieSeleccionada}_'));

    for (final bloqueKey in bloqueKeys) {
      final bloqueData = _bloquesBox.get(bloqueKey);
      final bloqueId = bloqueData['bloqueId'];
      final prefix = '${ciudadSeleccionada}_${serieSeleccionada}_${bloqueId}_';

      final parcelaKeys = _parcelasBox.keys.where((k) => k.startsWith(prefix));
      for (final key in parcelaKeys) {
        final data = _parcelasBox.get(key);
        if ((data['numero_ficha'] ?? 0) >= 1) {
          return false;
        }
      }
    }
    return true;
  }
}


  Future<void> generarNumerosFicha(int numeroInicial) async {
    int contador = numeroInicial;

final hayConexion = (await Connectivity().checkConnectivity()) != ConnectivityResult.none;
    if (hayConexion) {
    final bloquesSnapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada!)
            .collection('series')
            .doc(serieSeleccionada!)
            .collection('bloques')
            .orderBy(FieldPath.documentId)
            .get();

    for (var bloqueDoc in bloquesSnapshot.docs) {
      final parcelasSnapshot =
          await bloqueDoc.reference
              .collection('parcelas')
              .orderBy('numero')
              .get();

      for (var parcelaDoc in parcelasSnapshot.docs) {
        await parcelaDoc.reference.update({'numero_ficha': contador, 'flag_sync': true});
        contador++;
      }
    }

    }else{
      final bloquesKeys = _bloquesBox.keys
          .where((k) => k.contains('${ciudadSeleccionada}_${serieSeleccionada}_'))
          .toList()
        ..sort(); // orden por clave (similar al orderBy documentId) //TODO: validar ordenamiento

      for (final bloqueKey in bloquesKeys) {
        final bloqueData = _bloquesBox.get(bloqueKey);
        final bloqueId = bloqueData['bloqueId'];
        final prefixParcela = '${ciudadSeleccionada}_${serieSeleccionada}_${bloqueId}_';

        final parcelaKeys = _parcelasBox.keys
            .where((k) => k.startsWith(prefixParcela))
            .toList();

        final parcelaList = parcelaKeys.map((k) {
          final data = _parcelasBox.get(k);
          return {
            'key': k,
            'numero': int.tryParse(data['numero'].toString()) ?? 0,
            'data': data,
          };
        }).toList()
          ..sort((a, b) => a['numero'].compareTo(b['numero']));

        for (final parcela in parcelaList) {
          final updatedData = Map<String, dynamic>.from(parcela['data']);
          updatedData['numero_ficha'] = contador;

          await _parcelasBox.put(parcela['key'], updatedData);
          contador++;
        }
      }
    }

    await cargarParcelas(); // Refresca UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Números de ficha generados offline exitosamente"),
      ),
    );
  }

  void mostrarModalGenerarFicha() async {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text("Ingresar número inicial de ficha"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Ej: 100"),
            ),
            actions: [
              TextButton(
                child: const Text("Cancelar"),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text("Generar"),
                onPressed: () {
                  final input = int.tryParse(controller.text.trim());
                  if (input != null) {
                    Navigator.pop(context);
                    generarNumerosFicha(input);
                  }
                },
              ),
            ],
          ),
    );
  }

  Future<void> iniciarTratamiento() async {
    if (ciudadSeleccionada == null ||
        serieSeleccionada == null ||
        parcelaSeleccionada == null)
      return;

    await guardarSuperficieEnSerie();

    final doc = parcelas.firstWhere((p) => obtenerId(p) == parcelaSeleccionada);
    final numeroTratamiento = obtenerCampo(doc, 'numero_tratamiento');
    final numeroFicha = obtenerCampo(doc, 'numero_ficha');
    final numeroParcela = int.tryParse(obtenerCampo(doc, 'numero')) ?? 0;

    if (numeroTratamiento.isEmpty) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text("Falta número de tratamiento"),
              content: const Text(
                "Esta parcela no tiene asignado el número de tratamiento. Por favor, pide al administrador que lo genere.",
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => FormularioTratamiento(
              ciudadId: ciudadSeleccionada!,
              serieId: serieSeleccionada!,
              bloqueId: bloqueSeleccionado ?? '1',
              parcelaDesde: numeroParcela,
              numeroFicha: numeroFicha,
              numeroTratamiento: numeroTratamiento,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 70,
        leading: IconButton(
          icon: const Icon(Icons.refresh, color: Colors.black),
          tooltip: "Refrescar datos",
          onPressed: () async {
            await cargarCiudades();
            await cargarSeries();
            await cargarBloques();
            await cargarParcelas();

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
        centerTitle: true,
        title: const Text(
          "POSICIONAR TERRENO",
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            tooltip: "Cerrar sesión",
            onPressed: () async {
              final userBox = hive.box('offline_user');
              await userBox.delete('usuario_actual');

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),

      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 34),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldBox(
                              _buildDropdown(
                                "Localidad",
                                ciudadSeleccionada,
                                ciudades.map((doc) {
                                  return DropdownMenuItem(
                                    value: obtenerId(doc),
                                    child: Text(
                                      obtenerCampo(doc, 'nombre'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                (value) {
                                  setState(() {
                                    ciudadSeleccionada = value;
                                    serieSeleccionada = null;
                                    bloqueSeleccionado = null;
                                    parcelaSeleccionada = null;
                                    series.clear();
                                    bloques.clear();
                                    parcelas.clear();
                                  });
                                  cargarSeries();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 35),
                          Expanded(
                            child: _buildFieldBox(
                              _buildDropdown(
                                "Ensayo",
                                serieSeleccionada,
                                series.map((doc) {
                                  return DropdownMenuItem(
                                    value: obtenerId(doc),
                                    child: Text(
                                      obtenerCampo(doc, 'nombre'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                (value) {
                                  setState(() {
                                    serieSeleccionada = value;
                                    bloqueSeleccionado = null;
                                    parcelaSeleccionada = null;
                                    bloques.clear();
                                    parcelas.clear();
                                  });
                                  cargarBloques();
                                  cargarSuperficieDesdeSerie();
                                },
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 🔹 Bloque y Tratamiento de inicio
                      Row(
                        children: [
                          Expanded(
                            child: _buildFieldBox(
                              _buildDropdown(
                                "Bloque",
                                bloqueSeleccionado,
                                bloques.map((b) {
                                  return DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      "Bloque $b",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                (value) {
                                  setState(() {
                                    bloqueSeleccionado = value;
                                    parcelaSeleccionada = null;
                                    parcelas.clear();
                                  });
                                  cargarParcelas();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildFieldBox(
                              _buildDropdown(
                                "Tratamiento de inicio",
                                parcelaSeleccionada,
                                parcelas.map((doc) {
                                  return DropdownMenuItem(
                                    value: obtenerId(doc),
                                    child: Text(
                                      "T ${obtenerCampo(doc, 'numero_tratamiento')}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                (value) {
                                  setState(() {
                                    parcelaSeleccionada = value;
                                  });
                                  if (value != null) {
                                    actualizarInfoParcela(value);
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildFieldBox(
                        Row(
                          children: [
                            // Campo de número editable
                            Expanded(
                              child: TextField(
                                controller: superficieController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                                decoration: const InputDecoration(
                                  hintText: "Superficie cosechable",
                                  hintStyle: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 15,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const Text(
                              "m²",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      FutureBuilder<bool>(
                        future: puedeGenerarNumerosFicha(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const SizedBox(); // o loader
                          }

                          if (snapshot.data == true) {
                            return Column(
                              children: [
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.85,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    onPressed: mostrarModalGenerarFicha,
                                    icon: const Icon(
                                      Icons.auto_fix_high,
                                      size: 34,
                                    ),
                                    label: const Text(
                                      "GENERAR N° FICHA",
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),

                      const SizedBox(height: 20),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed:
                              parcelaSeleccionada != null
                                  ? iniciarTratamiento
                                  : null,
                          icon: const Icon(Icons.play_arrow, size: 34),
                          label: const Text(
                            "INICIAR TOMA DE DATOS",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF04bc04),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String? value,
    List<DropdownMenuItem<String>> items,
    Function(String?) onChanged,
  ) {
    final validValues = items.map((item) => item.value).toList();
    final fixedValue = validValues.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      value: fixedValue,
      // usa el valor fijo corregido
      isExpanded: true,
      dropdownColor: Colors.black,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        filled: true,
        fillColor: Colors.black,
        border: InputBorder.none,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 22),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildFieldBox(Widget child) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white, width: 10),
        borderRadius: BorderRadius.circular(5),
      ),
      child: child,
    );
  }
}

QueryDocumentSnapshotFake _mapToQuerySnapshot(Map<String, dynamic> map) {
  return QueryDocumentSnapshotFake(map['id'], {'nombre': map['nombre']});
}

String obtenerCampo(dynamic doc, String campo) {
  try {
    if (doc is QueryDocumentSnapshot || doc is DocumentSnapshot) {
      return doc[campo]?.toString() ?? '';
    } else if (doc is Map<String, dynamic>) {
      return doc[campo]?.toString() ?? '';
    }
  } catch (_) {}
  return '';
}

String obtenerId(dynamic doc) {
  try {
    if (doc is QueryDocumentSnapshot || doc is DocumentSnapshot) {
      return doc.id;
    } else if (doc is Map<String, dynamic>) {
      return doc['id'] ?? '';
    }
  } catch (_) {}
  return '';
}
