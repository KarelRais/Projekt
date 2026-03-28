import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
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

    final bytes = Uint8List.fromList(utf8.encode(message));
    _connection!.output.add(bytes);
    await _connection!.output.allSent;
  }

  /// Sends to one paired device. Prefer this over broadcasting: most paired
  /// devices (headphones, car kits, watches) are not SPP servers — connecting
  /// to them causes "read failed / socket closed" errors.
  Future<void> sendStringToAddress(String address, String message) async {
    await ensureEnabled();
    StreamSubscription? readSub;
    try {
      await connect(address);
      final input = _connection?.input;
      if (input != null) {
        readSub = input.listen(
          (_) {},
          onError: (_) {},
          cancelOnError: false,
        );
      }
      await Future.delayed(const Duration(milliseconds: 280));
      await sendString(message);
    } on PlatformException catch (e, st) {
      debugPrint('Bluetooth sendStringToAddress: $e\n$st');
      throw Exception(
        'Nepodařilo se připojit nebo odeslat. Vyberte telefon s touto aplikací, '
        'který je zapnutý, v dosahu a má Bluetooth zapnuté. (Typické chyby: špatné '
        'zařízení v seznamu spárovaných, druhá strana neposlouchá sériový profil.)',
      );
    } finally {
      await readSub?.cancel();
      await disconnect();
    }
  }

  /// Tries every paired device; most setups should use [sendStringToAddress] instead.
  Future<void> sendStringBroadcast(String message) async {
    await ensureEnabled();
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    if (devices.isEmpty) {
      throw Exception("Nenalezena žádná spárovaná BT zařízení");
    }
    Object? lastError;
    for (final btd in devices) {
      try {
        await sendStringToAddress(btd.address, message);
        return;
      } catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) {
      if (lastError is Exception) throw lastError;
      throw Exception(lastError.toString());
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
