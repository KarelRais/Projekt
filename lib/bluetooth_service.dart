import 'dart:typed_data';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothService {
  BluetoothConnection? _connection;

  /// Android 12+ requires [BLUETOOTH_CONNECT] and [BLUETOOTH_SCAN] at runtime
  /// (declaring them in the manifest is not enough).
  Future<void> _ensureBluetoothPermissionsIfNeeded() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final connect = await Permission.bluetoothConnect.request();
    if (!connect.isGranted) {
      throw Exception(
        'Povolte v nastavení aplikace oprávnění Bluetooth (připojení k zařízením).',
      );
    }
    final scan = await Permission.bluetoothScan.request();
    if (!scan.isGranted) {
      throw Exception(
        'Povolte v nastavení aplikace oprávnění Bluetooth (vyhledávání zařízení v okolí).',
      );
    }
  }

  Future<void> ensureEnabled() async {
    await _ensureBluetoothPermissionsIfNeeded();
    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!isEnabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  Future<void> init(int device) async {
    await _ensureBluetoothPermissionsIfNeeded();
    var devices = await FlutterBluetoothSerial.instance.getBondedDevices();

    if (devices.isEmpty) {
      throw Exception("Nenalezena žádná spárovaná BT zařízení");
    }

    _connection = await BluetoothConnection.toAddress(devices[device].address);
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    await _ensureBluetoothPermissionsIfNeeded();
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<void> connect(String address) async {
    await _ensureBluetoothPermissionsIfNeeded();
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {}
      _connection = null;
    }
    _connection = await BluetoothConnection.toAddress(address);
  }

  Future<void> sendString(String message) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception("Bluetooth není připojené");
    }

    final bytes = Uint8List.fromList(message.codeUnits);
    _connection!.output.add(bytes);
    await _connection!.output.allSent;
  }

  Future<void> sendStringBroadcast(String message) async {
    await ensureEnabled();
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    if (devices.isEmpty) {
      throw Exception("Nenalezena žádná spárovaná BT zařízení");
    }
    for (final btd in devices) {
      try {
        await connect(btd.address);
        await sendString(message);
      } finally {
        await disconnect();
      }
    }
  }

  Stream<String> onStringReceived() {
    if (_connection == null) {
      throw Exception("Bluetooth není připojené");
    }

    return _connection!.input!.map(
      (Uint8List data) => String.fromCharCodes(data),
    );
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }
}
