import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'crear_ciudad.dart';
import 'crear_serie.dart';
import 'crear_parcelas.dart';
import 'grafico_frecuencia.dart';
import '../login_screen.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF005A56),
        centerTitle: true,
        title: const Text(
          "Panel del Administrador",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: [
                _buildCompactButton(
                  context,
                  "Crear Localidad",
                  Icons.location_city,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CrearCiudad()),
                  ),
                ),
                _buildCompactButton(
                  context,
                  "Crear Ensayo",
                  Icons.map,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CrearSerie()),
                  ),
                ),
                _buildCompactButton(
                  context,
                  "Crear Parcelas",
                  Icons.grid_on,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CrearParcelas()),
                  ),
                ),
                _buildCompactButton(
                  context,
                  "Panel de datos",
                  Icons.bar_chart,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GraficoFrecuencia(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: const Color(0xFF005A56),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout),
              label: const Text("Volver al login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return SizedBox(
      width: 140,
      height: 120,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00B140),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 6,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
