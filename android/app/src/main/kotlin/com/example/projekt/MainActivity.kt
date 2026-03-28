package com.example.projekt

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothServerSocket
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class MainActivity : FlutterActivity() {

    private val BT_CHANNEL = "andoped/bluetooth"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BT_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "receive") {
                    Thread {
                        var serverSocket: BluetoothServerSocket? = null
                        try {
                            val adapter = BluetoothAdapter.getDefaultAdapter()
                            serverSocket = adapter.listenUsingRfcommWithServiceRecord("ANDOPED", SPP_UUID)
                            val socket = serverSocket.accept(30_000)   // 30s timeout
                            serverSocket.close()
                            val baos = java.io.ByteArrayOutputStream()
                            try {
                                val buf = ByteArray(4096)
                                while (true) {
                                    val n = socket.inputStream.read(buf)
                                    if (n == -1) break
                                    baos.write(buf, 0, n)
                                }
                            } catch (_: Exception) { /* normální konec spojení */ }
                            socket.close()
                            runOnUiThread { result.success(String(baos.toByteArray(), Charsets.UTF_8)) }
                        } catch (e: Exception) {
                            try { serverSocket?.close() } catch (_: Exception) {}
                            runOnUiThread { result.error("BT_ERROR", e.message, null) }
                        }
                    }.start()
                } else {
                    result.notImplemented()
                }
            }
    }
}