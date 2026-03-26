import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;

  Future<void> ensureEnabled() async {
    final isEnabled = await FlutterBluetoothSerial.instance.isEnabled ?? false;
    if (!isEnabled) {
      await FlutterBluetoothSerial.instance.requestEnable();
    }
  }

  Future<void> init(int device) async {
    var devices = await FlutterBluetoothSerial.instance.getBondedDevices();

    if (devices.isEmpty) {
      throw Exception("Nenalezena žádná spárovaná BT zařízení");
    }

    _connection = await BluetoothConnection.toAddress(devices[device].address);
  }

  Future<List<BluetoothDevice>> getBondedDevices() async {
    return await FlutterBluetoothSerial.instance.getBondedDevices();
  }

  Future<void> connect(String address) async {
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
