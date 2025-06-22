import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'setup_screen.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menú Principal"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // 🔥 Ir a la pantalla de configuración para editar datos
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
      body: const Center(child: Text("¡Bienvenido! Has iniciado sesión.")),
    );
  }
}
