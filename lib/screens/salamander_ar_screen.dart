import 'package:flutter/material.dart';
import 'package:ar_flutter_plugin/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin/managers/ar_location_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:ar_flutter_plugin/models/ar_node.dart';
import 'package:ar_flutter_plugin/datatypes/node_types.dart';

class SalamanderArScreen extends StatefulWidget {
  @override
  _SalamanderArScreenState createState() => _SalamanderArScreenState();
}

class _SalamanderArScreenState extends State<SalamanderArScreen> {
  ARSessionManager? _arSessionManager;
  ARObjectManager? _arObjectManager;
  ARAnchorManager? _arAnchorManager;
  ARLocationManager? _arLocationManager;

  bool _permissionsGranted = false;
  static const _channel = MethodChannel('com.example.salamander/ar_geospatial');

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.location.request();

    if (cameraStatus.isGranted && locationStatus.isGranted) {
      setState(() {
        _permissionsGranted = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _permissionsGranted
          ? ARView(
              onARViewCreated: _onARViewCreated,
            )
          : Center(
              child: CircularProgressIndicator(),
            ),
    );
  }

  void _onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    _arSessionManager = arSessionManager;
    _arObjectManager = arObjectManager;
    _arAnchorManager = arAnchorManager;
    _arLocationManager = arLocationManager;

    _arSessionManager!.onInitialize();
    _arObjectManager!.onInitialize();

    _enableGeospatialMode();
  }

  Future<void> _enableGeospatialMode() async {
    try {
      await _channel.invokeMethod('enableGeospatial');
    } on PlatformException catch (e) {
      print(e);
    }
  }

  Future<void> _createGeospatialAnchor(double lat, double lon, double alt) async {
    try {
      final String? anchorId = await _channel.invokeMethod('createGeospatialAnchor', {
        'latitude': lat,
        'longitude': lon,
        'altitude': alt,
      });

      if (anchorId != null) {
        final node = ARNode(
          type: NodeType.localGLTF2,
          uri: 'models/duck.gltf',
          position: Vector3(0, 0, 0),
        );
        print(anchorId);
      }
    } on PlatformException catch (e) {
      print(e);
    }
  }
}
