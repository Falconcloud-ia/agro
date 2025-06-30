import 'package:flutter/material.dart';

void backgroundCallbackDispatcher() {
  // Necesitas acceso a BuildContext, así que haz esto:
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🚀 Notificación'),
          content: const Text('Hola Benjamín'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  });
}

// GlobalKey para acceder al context desde cualquier lugar
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
