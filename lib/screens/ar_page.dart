import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import '../models/sensor_model.dart';
import '../services/firestore_service.dart';

class ARPage extends StatefulWidget {
  const ARPage({super.key});

  @override
  State<ARPage> createState() => _ARPageState();
}

class _ARPageState extends State<ARPage> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;
  ARLocationManager? arLocationManager;

  final FirestoreService _firestoreService = FirestoreService();
  StreamSubscription? _sensorSub;
  double _heading = 0;
  Position? _currentPos;
  List<SensorModel> _sensors = [];

  static const _channel = MethodChannel('com.example.salamander/ar_geospatial');
  
  int _currentStep = 0;
  double _scanProgress = 0.0;
  double _objectScanProgress = 0.0;
  bool _visualMatch = false;
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  void _checkPermissions() async {
    await [Permission.camera, Permission.location].request();
    _initTracking();
  }

  void _initTracking() {
    Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    )).listen((pos) {
      if (mounted) setState(() => _currentPos = pos);
    });

    FlutterCompass.events?.listen((event) {
      if (mounted) {
        double? h = event.heading;
        if (h != null) {
          setState(() {
            double ang = h;
            if (ang < 0) ang += 360;
            _heading = 0.15 * ang + 0.85 * _heading;
          });
        }
      }
    });

    _sensorSub = _firestoreService.getSensorsStream().listen((data) {
      if (mounted) setState(() => _sensors = data);
    });

    _startMappingProgressCheck();
  }

  void _startMappingProgressCheck() {
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_currentStep == 0) {
        try {
          final int planesCount = await _channel.invokeMethod('getMappingProgress');
          setState(() {
            _scanProgress = (planesCount / 5).clamp(0.0, 1.0);
            if (_scanProgress >= 1.0) {
              _currentStep = 1;
              _progressTimer?.cancel();
            }
          });
        } on PlatformException catch (e) {
          print(e);
        }
      }
    });
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    _sensorSub?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void onARViewCreated(
      ARSessionManager arSessionManager,
      ARObjectManager arObjectManager,
      ARAnchorManager arAnchorManager,
      ARLocationManager arLocationManager) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;
    this.arLocationManager = arLocationManager;

    this.arSessionManager!.onInitialize(
          showFeaturePoints: true,
          showPlanes: true,
          showWorldOrigin: false,
          handleTaps: false,
        );
    this.arObjectManager!.onInitialize();
    
    _checkVisualMatch();
  }

  Future<void> _checkVisualMatch() async {
    try {
      final bool match = await _channel.invokeMethod('checkVisualMatch');
      setState(() {
        _visualMatch = match;
      });
    } on PlatformException catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salamander AR Flow')),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          _buildStepUI(),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildStepUI() {
    switch (_currentStep) {
      case 0:
        return _buildMappingUI();
      case 1:
        return _buildLabelingUI();
      case 2:
        return _buildObjectScanningUI();
      default:
        return const SizedBox();
    }
  }

  Widget _buildMappingUI() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Odayı Tarayın',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _scanProgress, color: Colors.cyanAccent),
            const SizedBox(height: 5),
            Text(
              '${(_scanProgress * 100).toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabelingUI() {
    return Stack(
      children: [
        Center(
          child: Icon(Icons.add, size: 40, color: Colors.cyanAccent),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _currentStep = 2;
                _startObjectScan();
              });
            },
            child: const Text('Etiketle'),
          ),
        ),
        Positioned(
          top: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(8),
            color: Colors.green.withOpacity(0.8),
            child: const Text(
              'Oda Tanındı',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  void _startObjectScan() {
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _objectScanProgress += 0.01;
        if (_objectScanProgress >= 1.0) {
          _progressTimer?.cancel();
          _currentStep = 3;
          _showBottomSheet();
        }
      });
    });
  }

  Widget _buildObjectScanningUI() {
    return Stack(
      children: [
        Center(
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.cyanAccent, width: 2),
            ),
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          right: 20,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Nesnenin etrafında 360 derece dönün',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(value: _objectScanProgress, color: Colors.cyanAccent),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showBottomSheet() {
    final nameController = TextEditingController();
    final colorController = TextEditingController(text: '#00FFFF');
    final valueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'İsim'),
              ),
              TextField(
                controller: colorController,
                decoration: const InputDecoration(labelText: 'Buton Rengi (Hex)'),
              ),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'Değer (Value)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  final color = colorController.text.trim();
                  final val = double.tryParse(valueController.text) ?? 0.0;
                  
                  if (name.isNotEmpty && _currentPos != null) {
                    _firestoreService.addSensor(
                      name,
                      _currentPos!.latitude,
                      _currentPos!.longitude,
                      _currentPos!.altitude,
                      val,
                      color,
                    );
                  }
                  Navigator.pop(context);
                  setState(() {
                    _currentStep = 4;
                  });
                },
                child: const Text('Kaydet'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverlay() {
    if (_currentPos == null || _sensors.isEmpty) return const SizedBox();

    return Stack(
      children: [
        if (!_visualMatch && _currentStep == 4)
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              color: Colors.orange.withOpacity(0.8),
              child: const Text(
                'Manuel Sistem Aktif',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ..._sensors.map((sensor) {
          double distance = Geolocator.distanceBetween(
            _currentPos!.latitude,
            _currentPos!.longitude,
            sensor.latitude,
            sensor.longitude,
          );

          if (distance > 15) return const SizedBox();

          double bearing = Geolocator.bearingBetween(
            _currentPos!.latitude,
            _currentPos!.longitude,
            sensor.latitude,
            sensor.longitude,
          );
          if (bearing < 0) bearing += 360;

          double diff = bearing - _heading;
          if (diff > 180) diff -= 360;
          if (diff < -180) diff += 360;

          if (diff.abs() > 30) return const SizedBox();

          double width = MediaQuery.of(context).size.width;
          double x = width / 2 + (diff / 30) * (width / 2);
          
          double baseTop = MediaQuery.of(context).size.height * 0.45;
          double y = baseTop;
          
          if (!_visualMatch) {
            double altDiff = sensor.altitude - _currentPos!.altitude;
            y = baseTop - (altDiff * 50);
          }

          double scale = (1.2 / (distance / 5 + 1)).clamp(0.3, 1.2);

          return Positioned(
            left: x - 60,
            top: y,
            child: Column(
              children: [
                Container(
                  width: 24 * scale,
                  height: 24 * scale,
                  decoration: BoxDecoration(
                    color: Color(int.parse(sensor.buttonColor.replaceAll('#', '0xFF'))),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(int.parse(sensor.buttonColor.replaceAll('#', '0xFF'))), width: 1.5),
                  ),
                  child: Text(
                    "${sensor.name}\n${sensor.value.toStringAsFixed(1)}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}
