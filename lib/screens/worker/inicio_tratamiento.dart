import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'formulario_tratamiento.dart';
import '../login_screen.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:controlgestionagro/models/tratamiento_local.dart';
import 'package:controlgestionagro/services/offline_sync_service.dart';
import 'package:hive_flutter/hive_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    cargarCiudades();
  }

  Future<void> guardarSuperficieEnSerie() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    final superficie = superficieController.text.trim();
    final box = Hive.box('offline_series');
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
    final box = Hive.box('offline_ciudades');
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'default';

    if (hayConexion) {
      final snapshot =
          await FirebaseFirestore.instance.collection('ciudades').get();
      setState(() => ciudades = snapshot.docs);

      final ciudadMapList =
          snapshot.docs
              .map((doc) => {'id': doc.id, 'nombre': doc['nombre']})
              .toList();

      await box.put('ciudades_$uid', ciudadMapList);
    } else {
      final local = box.get('ciudades_$uid') ?? [];
      setState(() => ciudades = List<Map<String, dynamic>>.from(local));
    }
  }

  Future<void> cargarSuperficieDesdeSerie() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;
    final box = Hive.box('offline_series');

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

    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;
    final box = Hive.box('offline_series');

    if (hayConexion) {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('ciudades')
              .doc(ciudadSeleccionada)
              .collection('series')
              .get();

      setState(() => series = snapshot.docs);

      final list =
          snapshot.docs
              .map((doc) => {'id': doc.id, 'nombre': doc['nombre']})
              .toList();

      await box.put('series_$ciudadSeleccionada', list);
    } else {
      final local = box.get('series_$ciudadSeleccionada') ?? [];
      setState(() => series = List<Map<String, dynamic>>.from(local));
    }
  }

  Future<void> cargarBloques() async {
    if (ciudadSeleccionada == null || serieSeleccionada == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;
    final box = Hive.box('offline_bloques');

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
      setState(() => bloques = bloquesList);

      await box.put('bloques_$serieSeleccionada', bloquesList);
    } else {
      final local = box.get('bloques_$serieSeleccionada') ?? [];
      setState(() => bloques = List<String>.from(local));
    }
  }

  Future<void> cargarParcelas() async {
    if (bloqueSeleccionado == null) return;

    final connectivity = await Connectivity().checkConnectivity();
    final hayConexion = connectivity != ConnectivityResult.none;
    final box = Hive.box('offline_parcelas');
    final key =
        'parcelas_${ciudadSeleccionada}_${serieSeleccionada}_$bloqueSeleccionado';

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

      bool faltanCampos = docs.any((doc) {
        final data = doc.data();
        return data == null || !data.containsKey('numero_tratamiento');
      });

      if (faltanCampos) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("⚠️ Campo faltante"),
                content: const Text(
                  "Este bloque contiene parcelas sin 'número de tratamiento'.",
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

      setState(() => parcelas = docs);

      final list =
          docs
              .map(
                (doc) => {
                  'id': doc.id,
                  'numero': doc['numero'],
                  'numero_tratamiento': doc['numero_tratamiento'],
                  'numero_ficha': doc['numero_ficha'],
                },
              )
              .toList();

      await box.put(key, list);
    } else {
      final local = box.get(key) ?? [];

      if (local.isEmpty) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text("Sin datos offline"),
                content: const Text(
                  "No hay datos guardados para este bloque en modo offline. Por favor, conéctate al menos una vez.",
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

      // ✅ Este paso hace que el dropdown funcione en modo offline
      setState(() => parcelas = List<Map<String, dynamic>>.from(local));
    }
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

    final doc = parcelas.firstWhere((p) => p.id == parcelaSeleccionada);
    final numeroParcela = doc['numero'];
    if (numeroParcela != 1) return false;

    final bloquesSnapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(ciudadSeleccionada!)
            .collection('series')
            .doc(serieSeleccionada!)
            .collection('bloques')
            .get();

    for (var bloqueDoc in bloquesSnapshot.docs) {
      final parcelasSnapshot =
          await bloqueDoc.reference
              .collection('parcelas')
              .where('numero_ficha', isGreaterThanOrEqualTo: 1)
              .limit(1)
              .get();
      if (parcelasSnapshot.docs.isNotEmpty) return false;
    }

    return true;
  }

  Future<void> generarNumerosFicha(int numeroInicial) async {
    int contador = numeroInicial;

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
        await parcelaDoc.reference.update({'numero_ficha': contador});
        contador++;
      }
    }

    await cargarParcelas(); // Refresca la UI
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("✅ Números de ficha generados exitosamente"),
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
              final userBox = Hive.box('offline_user');
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
      value: fixedValue, // usa el valor fijo corregido
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

class QueryDocumentSnapshotFake {
  final String id;
  final Map<String, dynamic> _data;

  QueryDocumentSnapshotFake(this.id, this._data);

  Map<String, dynamic> data() => _data;
  dynamic operator [](String key) => _data[key];
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
