import 'package:cloud_firestore/cloud_firestore.dart';

class SensorModel {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double altitude;
  final double value;
  final String buttonColor;

  SensorModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.value,
    required this.buttonColor,
  });

  factory SensorModel.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SensorModel(
      id: doc.id,
      name: data['name'] ?? '',
      latitude: (data['latitude'] ?? 0.0).toDouble(),
      longitude: (data['longitude'] ?? 0.0).toDouble(),
      altitude: (data['altitude'] ?? 0.0).toDouble(),
      value: (data['value'] ?? 0.0).toDouble(),
      buttonColor: data['buttonColor'] ?? '#00FFFF',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'value': value,
      'buttonColor': buttonColor,
    };
  }
}
