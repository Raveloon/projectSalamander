import 'package:flutter/material.dart';
import '../models/sensor_model.dart';
import '../services/firestore_service.dart';

class SensorListScreen extends StatefulWidget {
  const SensorListScreen({super.key});

  @override
  State<SensorListScreen> createState() => _SensorListScreenState();
}

class _SensorListScreenState extends State<SensorListScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _showEditDialog(SensorModel sensor) async {
    final nameController = TextEditingController(text: sensor.name);
    final valueController = TextEditingController(text: sensor.value.toString());
    final colorController = TextEditingController(text: sensor.buttonColor);
    final altitudeController = TextEditingController(text: sensor.altitude.toString());

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Sensor'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: valueController,
                  decoration: const InputDecoration(labelText: 'Value'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: colorController,
                  decoration: const InputDecoration(labelText: 'Button Color (Hex)'),
                ),
                TextField(
                  controller: altitudeController,
                  decoration: const InputDecoration(labelText: 'Altitude'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newValue = double.tryParse(valueController.text) ?? sensor.value;
                final newColor = colorController.text.trim();
                final newAltitude = double.tryParse(altitudeController.text) ?? sensor.altitude;
                _firestoreService.updateSensor(sensor.id, newName, newValue, newColor, newAltitude);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Sensors')),
      body: StreamBuilder<List<SensorModel>>(
        stream: _firestoreService.getSensorsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final sensors = snapshot.data ?? [];

          if (sensors.isEmpty) {
            return const Center(child: Text('No sensors found.'));
          }

          return ListView.builder(
            itemCount: sensors.length,
            itemBuilder: (context, index) {
              final sensor = sensors[index];
              return Dismissible(
                key: Key(sensor.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  _firestoreService.deleteSensor(sensor.id);
                },
                child: ListTile(
                  title: Text(sensor.name),
                  subtitle: Text('Value: ${sensor.value} | Alt: ${sensor.altitude}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        color: Color(int.parse(sensor.buttonColor.replaceAll('#', '0xFF'))),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(sensor),
                      ),
                    ],
                  ),
                  onTap: () => _showEditDialog(sensor),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
