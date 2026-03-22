import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothService {
  BluetoothConnection? _connection;

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
    for(BluetoothDevice btd in await FlutterBluetoothSerial.instance.getBondedDevices()) {
      connect(btd.address);
      sendString(message);
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
