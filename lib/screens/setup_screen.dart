import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin/admin_dashboard.dart';
import 'worker/worker_dashboard.dart';
import 'login_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  String selectedRole = 'trabajador';
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;
      DocumentSnapshot userDoc =
          await FirebaseFirestore.instance
              .collection('usuarios')
              .doc(uid)
              .get();

      if (userDoc.exists) {
        Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

        setState(() {
          nameController.text = userData['nombre'] ?? '';

          selectedRole = userData['rol'] ?? 'trabajador';
        });
      }
    } catch (e) {
      print("❌ Error al cargar datos del usuario: $e");
    }
  }

  Future<void> saveUserInfo() async {
    try {
      String uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('usuarios').doc(uid).set({
        "nombre": nameController.text.trim(),
        "rol": selectedRole,
      }, SetOptions(merge: true));

      print("✅ Datos guardados en Firestore correctamente.");

      if (selectedRole == "admin") {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const WorkerDashboard()),
        );
      }
    } catch (e) {
      print("❌ Error al guardar datos: $e");
      setState(() {
        errorMessage = 'Error al guardar datos: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF005A56), // Azul petróleo IANSA
        centerTitle: true,
        elevation: 0,
        title: Image.asset('assets/images/iansa_logo.jpeg', height: 40),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 350),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Completa tu información antes de continuar",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF004D4C),
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(controller: nameController, label: "Nombre"),

                  const SizedBox(height: 16),

                  _buildDropdown(),

                  const SizedBox(height: 20),

                  if (errorMessage.isNotEmpty)
                    Text(
                      errorMessage,
                      style: const TextStyle(color: Colors.red),
                    ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: saveUserInfo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00B140), // Verde IANSA
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 35,
                        vertical: 20,
                      ),
                      textStyle: const TextStyle(fontSize: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Guardar"),
                  ),
                  const SizedBox(height: 25),

                  TextButton(
                    onPressed: () {
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      "Volver al login",
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 18,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 20, color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black87, fontSize: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 20,
          horizontal: 16,
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

  Widget _buildDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButton<String>(
        value: selectedRole,
        dropdownColor: Colors.white,
        isExpanded: true,
        style: const TextStyle(color: Colors.black, fontSize: 18),
        underline: const SizedBox(),
        iconEnabledColor: Colors.black,
        onChanged: (String? newValue) {
          setState(() {
            selectedRole = newValue!;
          });
        },
        items:
            ['trabajador', 'admin'].map((String value) {
              return DropdownMenuItem<String>(value: value, child: Text(value));
            }).toList(),
      ),
    );
  }
}
