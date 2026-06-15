package com.mpesatracker.mpesa_tracker2

import android.Manifest
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Bundle
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "com.mpesatracker2/sms"
    private val smsPermissionCode = 100
    private val mpesaSender = "MPESA"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readSms" -> {
                        if (ContextCompat.checkSelfPermission(
                                this,
                                Manifest.permission.READ_SMS,
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.READ_SMS),
                                smsPermissionCode,
                            )
                            result.success(emptyList<Map<String, Any>>())
                        } else {
                            result.success(readMpesaSmsMessages())
                        }
                    }
                    "hasPermission" -> {
                        val hasPermission = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS,
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(hasPermission)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readMpesaSmsMessages(): List<Map<String, Any>> {
        val messages = mutableListOf<Map<String, Any>>()

        try {
            val uri = Uri.parse("content://sms/inbox")
            val cursor = contentResolver.query(
                uri,
                arrayOf("address", "body", "date"),
                "address = ? OR address = ? OR address = ?",
                arrayOf(mpesaSender, "MPESA", "234700"),
                "date DESC",
            )

            cursor?.use {
                val addressIndex = it.getColumnIndex("address")
                val bodyIndex = it.getColumnIndex("body")
                val dateIndex = it.getColumnIndex("date")

                while (it.moveToNext() && messages.size < 500) {
                    val address = if (addressIndex >= 0) it.getString(addressIndex) ?: "" else ""
                    val body = if (bodyIndex >= 0) it.getString(bodyIndex) ?: "" else ""
                    val date = if (dateIndex >= 0) it.getLong(dateIndex) else 0L

                    if (isMpesaSender(address) || body.uppercase().contains("M-PESA")) {
                        messages.add(
                            mapOf(
                                "address" to address,
                                "body" to body,
                                "date" to date,
                            ),
                        )
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return messages
    }

    private fun isMpesaSender(address: String): Boolean {
        val normalized = address.uppercase().replace("-", "").replace(" ", "")
        return normalized == mpesaSender ||
            normalized.contains("MPESA") ||
            normalized == "234700"
    }
}
