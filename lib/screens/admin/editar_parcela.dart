import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditarParcela extends StatefulWidget {
  final String ciudadId;
  final String serieId;
  final String bloqueId;
  final String parcelaId;

  const EditarParcela({
    super.key,
    required this.ciudadId,
    required this.serieId,
    required this.bloqueId,
    required this.parcelaId,
  });

  @override
  State<EditarParcela> createState() => _EditarParcelaState();
}

class _EditarParcelaState extends State<EditarParcela> {
  final TextEditingController fichaController = TextEditingController();
  final TextEditingController asignadoController = TextEditingController();
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    cargarDatosParcela();
  }

  Future<void> cargarDatosParcela() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('ciudades')
            .doc(widget.ciudadId)
            .collection('series')
            .doc(widget.serieId)
            .collection('bloques')
            .doc(widget.bloqueId)
            .collection('parcelas')
            .doc(widget.parcelaId)
            .get();

    if (doc.exists) {
      final data = doc.data() ?? {};
      fichaController.text = (data['numero_ficha'] ?? '').toString();
      asignadoController.text = (data['numero_tratamiento'] ?? '').toString();
    }

    setState(() => cargando = false);
  }

  Future<void> guardarCambios() async {
    await FirebaseFirestore.instance
        .collection('ciudades')
        .doc(widget.ciudadId)
        .collection('series')
        .doc(widget.serieId)
        .collection('bloques')
        .doc(widget.bloqueId)
        .collection('parcelas')
        .doc(widget.parcelaId)
        .update({
          "numero_ficha": int.tryParse(fichaController.text.trim()),
          "numero_tratamiento": int.tryParse(asignadoController.text.trim()),
        });

    Navigator.pop(context); // Volver atrás
  }

  Future<void> reiniciarParcela() async {
    await FirebaseFirestore.instance
        .collection('ciudades')
        .doc(widget.ciudadId)
        .collection('series')
        .doc(widget.serieId)
        .collection('bloques')
        .doc(widget.bloqueId)
        .collection('parcelas')
        .doc(widget.parcelaId)
        .update({"numero_ficha": null, "numero_tratamiento": null});

    fichaController.clear();
    asignadoController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Editar Parcela",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF005A56),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body:
          cargando
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Modificar datos de la parcela",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF005A56),
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: fichaController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18),
                      decoration: _inputDecoration("Número de ficha (único)"),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: asignadoController,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 18),
                      decoration: _inputDecoration(
                        "Número tratamiento (manual)",
                      ),
                    ),
                    const SizedBox(height: 30),

                    ElevatedButton.icon(
                      onPressed: guardarCambios,
                      icon: const Icon(Icons.save),
                      label: const Text(
                        "Guardar cambios",
                        style: TextStyle(fontSize: 18),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00B140),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextButton.icon(
                      onPressed: reiniciarParcela,
                      icon: const Icon(Icons.refresh),
                      label: const Text("Reiniciar datos de esta parcela"),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black87, fontSize: 16),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.black),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF005A56), width: 2),
      ),
    );
  }
}
