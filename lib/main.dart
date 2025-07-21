//import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:controlgestionagro/screens/setup_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'batch/batch_procesor.dart';
import 'config/hive_config.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/loading_screen.dart';
import 'screens/login_screen.dart';
import 'package:controlgestionagro/screens/worker/inicio_tratamiento.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:workmanager/workmanager.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Inicializa Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
    //cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // 🔹 Inicializa Hive usando la nueva configuración centralizada
  await HiveConfig.init();

  Workmanager().initialize(backgroundCallbackDispatcher, isInDebugMode: true);

  Workmanager().registerPeriodicTask(
    "periodicSyncTask",       // ID único
    "backgroundSync",         // Nombre de la tarea (match con el `task` que recibes)
    frequency: Duration(hours: 1),  // mínimo 15 minutos en Android
    initialDelay: Duration(seconds: 0), // opcional: para evitar que corra de inmediato
    constraints: Constraints(
      networkType: NetworkType.connected,
      requiresBatteryNotLow: false,
      requiresCharging: false,
    ),
    backoffPolicy: BackoffPolicy.exponential,
    backoffPolicyDelay: Duration(minutes: 10),
  );

/*
  //Android_alarm
  await AndroidAlarmManager.initialize();
  if (!kIsWeb && Platform.isAndroid) {
    print('comienza proceso sync');

    //exact: true, // intenta que sea lo más preciso posible
    //wakeup: true, // despierta el dispositivo si está dormido
    await AndroidAlarmManager.oneShot(const Duration(seconds: 1),0, backgroundCallbackDispatcher, exact: true, wakeup: true,);
    //Agregar tiempo
    await AndroidAlarmManager.periodic(const Duration(minutes: 15), 0, backgroundCallbackDispatcher, exact: true, wakeup: true,);
  }
 */

  // 🔐 Persistencia UID anónimo si es que existe en Auth pero no está en Hive
  final userBox = Hive.box('offline_user');
  final currentUser = FirebaseAuth.instance.currentUser;
  final guardado = userBox.get('usuario_actual');

  if (currentUser != null && currentUser.isAnonymous && guardado == null) {
    // 🔐 Persistimos el usuario anónimo activo en Hive
    await userBox.put('usuario_actual', {
      'uid': currentUser.uid,
      'email': 'anonimo@operador.com',
      'rol': 'operador',
      'nombre': 'Usuario Operador',
      'ciudad': '',
      'password': '',
    });

    print('✅ UID anónimo recuperado y persistido: ${currentUser.uid}');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final Connectivity _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();

    // 🔄 Escucha cambios de conexión para futuras sincronizaciones dentro de la app
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        print("📶 Conexión disponible. Puedes sincronizar.");
        // TODO: sincronizar datos Hive -> Firestore si hay cambios pendientes
      } else {
        print("⚠️ Sin conexión. Modo offline activado.");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color.fromARGB(255, 10, 9, 49),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.black12,
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: Colors.white70),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/inicio_tratamiento': (context) => const InicioTratamientoScreen(),
      },
    );
  }
}

// 🔐 Verifica si el usuario está autenticado
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _determinarPantallaInicial(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen();
        }

        if (snapshot.hasData) {
          return snapshot.data as Widget;
        }

        return const LoginScreen(); // fallback en caso de error
      },
    );
  }

  Future<Widget> _determinarPantallaInicial() async {
    final user = FirebaseAuth.instance.currentUser;
    final box = await Hive.openBox('offline_user');
    final usuario = box.get('usuario_actual');

    if (user != null && user.isAnonymous && usuario?['rol'] == 'operador') {
      // 🔁 Usuario anónimo y operador persistido → ir a inicio tratamiento
      return const InicioTratamientoScreen();
    }

    if (user != null) {
      // Usuario con cuenta → ir a SetupScreen para verificar datos
      return const SetupScreen();
    }

    return const LoginScreen();
  }
}