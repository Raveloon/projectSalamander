import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sensor_model.dart';

class FirestoreService {
  final CollectionReference _sensorsCollection =
      FirebaseFirestore.instance.collection('sensors');

  Stream<List<SensorModel>> getSensorsStream() {
    return _sensorsCollection.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SensorModel.fromDocument(doc)).toList();
    });
  }

  Future<List<SensorModel>> getAllSensorsOnce() async {
    final snapshot = await _sensorsCollection.get();
    return snapshot.docs.map((doc) => SensorModel.fromDocument(doc)).toList();
  }

  Future<void> addSensor(String name, double latitude, double longitude, double altitude, double value, String buttonColor) async {
    await _sensorsCollection.add({
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'value': value,
      'buttonColor': buttonColor,
    });
  }

  Future<void> updateSensor(String id, String name, double value, String buttonColor, double altitude) async {
    await _sensorsCollection.doc(id).update({
      'name': name,
      'value': value,
      'buttonColor': buttonColor,
      'altitude': altitude,
    });
  }

  Future<void> deleteSensor(String id) async {
    await _sensorsCollection.doc(id).delete();
  }
}
