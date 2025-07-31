import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class TipoConexionScreen extends StatefulWidget {
  const TipoConexionScreen({super.key});

  @override
  State<TipoConexionScreen> createState() => _TipoConexionScreenState();
}

class _TipoConexionScreenState extends State<TipoConexionScreen> {
  String tipoConexion = "Detectando conexión...";

  @override
  void initState() {
    super.initState();
    verificarConexion();
  }

  Future<void> verificarConexion() async {
    final resultado = await Connectivity().checkConnectivity();

    if (kIsWeb) {
      // En web solo podemos detectar si hay conexión o no
      setState(() {
        if (resultado == ConnectivityResult.none) {
          tipoConexion = "Sin conexión a internet";
        } else {
          tipoConexion = "Conectado a internet (tipo de red no disponible en navegador)";
        }
      });
    } else {
      // En Android/iOS sí podemos distinguir el tipo
      setState(() {
        switch (resultado) {
          case ConnectivityResult.wifi:
            tipoConexion = "Conectado por Wi-Fi";
            break;
          case ConnectivityResult.mobile:
            tipoConexion = "Conectado por datos móviles (3G, 4G, 5G)";
            break;
          case ConnectivityResult.none:
            tipoConexion = "Sin conexión a internet";
            break;
          default:
            tipoConexion = "Tipo de conexión desconocido";
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tipo de Conexión")),
      body: Center(
        child: Text(
          tipoConexion,
          style: const TextStyle(fontSize: 24),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
