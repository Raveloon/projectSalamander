import 'package:flutter/material.dart';
import 'sensor_list_screen.dart';
import 'ar_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AR Sensor App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ARPage()),
                );
              },
              child: const Text('AR Camera'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SensorListScreen()),
                );
              },
              child: const Text('Manage Sensors'),
            ),
          ],
        ),
      ),
    );
  }
}
