import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VerMatriz extends StatefulWidget {
  final String ciudadId;
  final String serieId;

  const VerMatriz({super.key, required this.ciudadId, required this.serieId});

  @override
  State<VerMatriz> createState() => _VerMatrizState();
}

class _VerMatrizState extends State<VerMatriz> {
  String? bloqueSeleccionado;
  String nombreSerie = '';
  List<DocumentSnapshot> parcelas = [];
  bool cargando = false;

  @override
  void initState() {
    super.initState();
    cargarNombreSerie();
  }

  Future<void> cargarNombreSerie() async {
    final serieDoc =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .collection('series')
            .doc(widget.serieId)
            .get();

    setState(() {
      nombreSerie = serieDoc['nombre'];
    });
  }

  Future<void> cargarParcelas(String bloque) async {
    setState(() {
      cargando = true;
      parcelas = [];
    });

    final snapshot =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .collection('series')
            .doc(widget.serieId)
            .collection('bloques')
            .doc(bloque)
            .collection('parcelas')
            .orderBy('numero')
            .get();

    setState(() {
      parcelas = snapshot.docs;
      cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Visualización de Matriz")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Serie: $nombreSerie",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: bloqueSeleccionado,
              decoration: const InputDecoration(
                labelText: "Seleccionar bloque",
              ),
              items:
                  ['A', 'B', 'C', 'D'].map((b) {
                    return DropdownMenuItem(value: b, child: Text("Bloque $b"));
                  }).toList(),
              onChanged: (value) {
                setState(() => bloqueSeleccionado = value);
                if (value != null) {
                  cargarParcelas(value);
                }
              },
            ),
            const SizedBox(height: 20),
            cargando
                ? const Center(child: CircularProgressIndicator())
                : parcelas.isEmpty
                ? const Text("⚠️ Este bloque aún no tiene parcelas creadas.")
                : Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.5,
                        ),
                    itemCount: parcelas.length,
                    itemBuilder: (context, index) {
                      final parcela = parcelas[index];
                      final numero = parcela['numero'];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple[50],
                          border: Border.all(color: Colors.deepPurple),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Parcela $numero",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              onPressed: () {
                                // 🔜 Configurar acción de edición más adelante
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(80, 30),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                              ),
                              child: const Text(
                                "Editar",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
