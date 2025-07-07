import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class HiveViewerScreen extends StatefulWidget {
  const HiveViewerScreen({super.key});

  @override
  State<HiveViewerScreen> createState() => _HiveViewerScreenState();
}

class _HiveViewerScreenState extends State<HiveViewerScreen> {
  late List<String> boxNames;
  String? selectedBoxName;
  Map<dynamic, dynamic> boxData = {};

  @override
  void initState() {
    super.initState();
    boxNames = [
    'offline_data',
    'user_data',
    'offline_user',
    'offline_ciudades',
    'offline_series',
    'offline_bloques',
    'offline_parcelas',
    'offline_tratamientos',
    ];
  }

  void loadBoxData(String boxName) {
    final box = Hive.box(boxName);
    setState(() {
      selectedBoxName = boxName;
      boxData = box.toMap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hive Viewer'),
        backgroundColor: const Color(0xFF005A56),
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          DropdownButton<String>(
            hint: const Text("Selecciona una caja Hive"),
            value: selectedBoxName,
            items: boxNames.map((name) {
              return DropdownMenuItem(value: name, child: Text(name));
            }).toList(),
            onChanged: (value) {
              if (value != null) loadBoxData(value);
            },
          ),
          const Divider(),
          Expanded(
            child: selectedBoxName == null
                ? const Center(child: Text("Selecciona una caja para ver sus datos"))
                : ListView(
              children: boxData.entries.map((entry) {
                return ListTile(
                  title: Text(entry.key.toString()),
                  subtitle: Text(entry.value.toString()),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
