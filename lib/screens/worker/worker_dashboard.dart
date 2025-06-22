import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../setup_screen.dart';
import 'inicio_tratamiento.dart'; // 💡 Asegúrate de que esta ruta esté correcta

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard> {
  @override
  void initState() {
    super.initState();

    // Redirige automáticamente después de un frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InicioTratamientoScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel de Trabajador"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SetupScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: const Center(
        child: CircularProgressIndicator(), // Carga hasta redirigir
      ),
    );
  }
}
