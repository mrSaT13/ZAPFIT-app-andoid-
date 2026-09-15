package com.dev.zapfit

import android.appwidget.AppWidgetManager
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.dev.zapfit.widget.ZapfitDailyWidget
import com.dev.zapfit.widget.ZapfitSummaryWidget
import com.dev.zapfit.widget.ZapfitSleepWidget
import com.dev.zapfit.widget.ZapfitHrWidget

class MainActivity : FlutterFragmentActivity(), SensorEventListener {
    private val CHANNEL = "com.zapfit/widgets"
    private val STEP_CHANNEL = "com.zapfit/step_counter"
    private var gatt: BluetoothGatt? = null
    private val handler = Handler(Looper.getMainLooper())
    private var currentAudioFocusRequest: android.media.AudioFocusRequest? = null

    private var sensorManager: SensorManager? = null
    private var stepCounterSensor: Sensor? = null
    private var stepDetectorSensor: Sensor? = null
    private var stepEventSink: EventChannel.EventSink? = null
    private var initialStepCount: Float = -1f
    private var detectorStepCount: Int = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "updateWidgets") {
                updateAllWidgets()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        // Storage permission channel for folder auto-import
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.zapfit/storage").setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkVersion" -> result.success(Build.VERSION.SDK_INT)
                "hasStoragePermission" -> {
                    result.success(if (Build.VERSION.SDK_INT >= 30) Environment.isExternalStorageManager() else true)
                }
                "openStorageSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                        startActivity(intent)
                        result.success(true)
                    }
                }
                "removeBluetoothBond" -> {
                    try {
                        val macAddress = call.argument<String>("macAddress") ?: ""
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        val device = adapter.getRemoteDevice(macAddress)
                        // Use reflection to call removeBond() — hidden API
                        val method = device.javaClass.getMethod("removeBond")
                        val success = method.invoke(device) as Boolean
                        result.success(success)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "createBond" -> {
                    // Gadgetbridge approach: connectGatt(autoConnect=true) FIRST
                    // This establishes BLE link so pairing request reaches the watch
                    try {
                        val macAddress = call.argument<String>("macAddress") ?: ""
                        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
                        val adapter = bluetoothManager.adapter
                        val device = adapter.getRemoteDevice(macAddress)

                        if (device.bondState == BluetoothDevice.BOND_BONDED) {
                            result.success("already_bonded")
                            return@setMethodCallHandler
                        }

                        // Register bond receiver FIRST
                        val bondReceiver = object : BroadcastReceiver() {
                            override fun onReceive(ctx: Context, intent: Intent) {
                                if (intent.action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                                    val bondDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                                    } else {
                                        @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                                    }
                                    val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
                                    Log.d("ZAPFIT", "Bond state changed: $bondDevice, state=$bondState")
                                    if (bondDevice?.address == macAddress) {
                                        when (bondState) {
                                            BluetoothDevice.BOND_BONDED -> {
                                                try { unregisterReceiver(this) } catch (_: Exception) {}
                                                // Close GATT and return
                                                try { gatt?.close() } catch (_: Exception) {}
                                                Handler(Looper.getMainLooper()).post { result.success("bonded") }
                                            }
                                            BluetoothDevice.BOND_NONE -> {
                                                try { unregisterReceiver(this) } catch (_: Exception) {}
                                                try { gatt?.close() } catch (_: Exception) {}
                                                Handler(Looper.getMainLooper()).post { result.success("rejected") }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        registerReceiver(bondReceiver, IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED))

                        // Timeout after 60s
                        Handler(Looper.getMainLooper()).postDelayed({
                            try { unregisterReceiver(bondReceiver) } catch (_: Exception) {}
                            try { gatt?.close() } catch (_: Exception) {}
                        }, 60000)

                        // Step 1: Connect GATT with autoConnect=true
                        Log.d("ZAPFIT", "Connecting GATT to $macAddress with autoConnect=true")
                        gatt = device.connectGatt(this, true, object : BluetoothGattCallback() {
                            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                                Log.d("ZAPFIT", "GATT state: status=$status, newState=$newState")
                                if (newState == BluetoothProfile.STATE_CONNECTED) {
                                    Log.d("ZAPFIT", "GATT connected! Discovering services first...")
                                    // Gadgetbridge approach: discover services BEFORE bonding
                                    // This ensures the GATT link is fully initialized
                                    Handler(Looper.getMainLooper()).postDelayed({
                                        Log.d("ZAPFIT", "Discovering services...")
                                        gatt.discoverServices()
                                    }, 1000) // 1 second delay to let connection stabilize
                                } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                                    Log.d("ZAPFIT", "GATT disconnected")
                                }
                            }
                            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                                Log.d("ZAPFIT", "Services discovered: status=$status, count=${gatt.services?.size ?: 0}")
                                // NOW trigger bonding after services are discovered
                                // This ensures the pairing request reaches the watch
                                Handler(Looper.getMainLooper()).postDelayed({
                                    Log.d("ZAPFIT", "Services ready, triggering bond...")
                                    device.createBond()
                                }, 500)
                            }
                        })

                        Log.d("ZAPFIT", "GATT connect initiated, waiting...")
                        // Result will be delivered by bond receiver
                    } catch (e: Exception) {
                        Log.e("ZAPFIT", "createBond error: $e")
                        result.success("error: $e")
                    }
                }
                "getBondState" -> {
                    try {
                        val macAddress = call.argument<String>("macAddress") ?: ""
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        val device = adapter.getRemoteDevice(macAddress)
                        when (device.bondState) {
                            BluetoothDevice.BOND_BONDED -> result.success("bonded")
                            BluetoothDevice.BOND_BONDING -> result.success("bonding")
                            else -> result.success("none")
                        }
                    } catch (e: Exception) {
                        result.success("error")
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Audio focus channel for music ducking during TTS
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.zapfit/audio_focus").setMethodCallHandler { call, result ->
            when (call.method) {
                "requestFocus" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        val focusRequest = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK)
                            .setAudioAttributes(
                                android.media.AudioAttributes.Builder()
                                    .setUsage(android.media.AudioAttributes.USAGE_ASSISTANT)
                                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                                    .build()
                            )
                            .setOnAudioFocusChangeListener { focusChange ->
                                if (focusChange == android.media.AudioManager.AUDIOFOCUS_LOSS ||
                                    focusChange == android.media.AudioManager.AUDIOFOCUS_LOSS_TRANSIENT) {
                                    // keep focus stored, flutter will stop TTS via completion/cancel handlers
                                }
                            }
                            .build()
                        currentAudioFocusRequest = focusRequest
                        val focusResult = audioManager.requestAudioFocus(focusRequest)
                        result.success(focusResult == android.media.AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "abandonFocus" -> {
                    try {
                        val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
                        val req = currentAudioFocusRequest
                        if (req != null) {
                            audioManager.abandonAudioFocusRequest(req)
                            currentAudioFocusRequest = null
                        } else {
                            // fallback: abandon generic
                            val fallback = android.media.AudioFocusRequest.Builder(android.media.AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_MAY_DUCK).build()
                            audioManager.abandonAudioFocusRequest(fallback)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        currentAudioFocusRequest = null
                        result.success(false)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // CompanionDeviceManager channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.zapfit/companion_device").setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    result.success(true)
                }
                "pairDevice" -> {
                    val macAddress = call.argument<String>("macAddress") ?: ""
                    pairDeviceLegacy(macAddress, result)
                }
                "removeBluetoothBond" -> {
                    try {
                        val macAddress = call.argument<String>("macAddress") ?: ""
                        val adapter = BluetoothAdapter.getDefaultAdapter()
                        val device = adapter.getRemoteDevice(macAddress)
                        val method = device.javaClass.getMethod("removeBond")
                        val success = method.invoke(device) as Boolean
                        result.success(success)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "getAssociations" -> {
                    result.success(emptyList<String>())
                }
                "startObserving" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    registerAclReceiver(deviceId)
                    result.success(true)
                }
                "stopObserving" -> {
                    val deviceId = call.argument<String>("deviceId") ?: ""
                    unregisterAclReceiver(deviceId)
                    result.success(true)
                }
                "disassociate" -> {
                    result.success(false)
                }
                else -> result.notImplemented()
            }
        }

        // Xiaomi BLE Auth channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.zapfit/xiaomi_auth").setMethodCallHandler { call, result ->
            when (call.method) {
                "connectAndAuth" -> {
                    val macAddress = call.argument<String>("macAddress") ?: ""
                    val authKey = call.argument<String>("authKey")
                    val deviceName = call.argument<String>("deviceName") ?: ""
                    Log.d("ZAPFIT", "Xiaomi auth requested for $macAddress (name=$deviceName)")

                    val authManager = XiaomiBleAuthManager()
                    // Configure authFlags/cryptFlags based on device name
                    authManager.configureForDevice(deviceName)
                    authManager.connectAndAuth(this, macAddress, authKey) { success, message ->
                        Log.d("ZAPFIT", "Xiaomi auth result: success=$success, msg=$message")
                        handler.post { result.success(mapOf("success" to success, "message" to message)) }
                    }
                }
                "disconnect" -> {
                    // Disconnect native GATT
                    try { gatt?.disconnect(); gatt?.close() } catch (_: Exception) {}
                    gatt = null
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STEP_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    stepEventSink = events
                    startStepSensor()
                }
                override fun onCancel(arguments: Any?) {
                    stepEventSink = null
                    stopStepSensor()
                }
            }
        )
    }

    private fun startStepSensor() {
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager

        // Пробуем TYPE_STEP_COUNTER (кумулятивный с момента перезагрузки)
        stepCounterSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)

        // Пробуем TYPE_STEP_DETECTOR (срабатывает на каждый шаг)
        stepDetectorSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)

        if (stepCounterSensor != null) {
            sensorManager?.registerListener(this, stepCounterSensor, SensorManager.SENSOR_DELAY_NORMAL)
        } else if (stepDetectorSensor != null) {
            sensorManager?.registerListener(this, stepDetectorSensor, SensorManager.SENSOR_DELAY_NORMAL)
        } else {
            stepEventSink?.error("NO_SENSOR", "Step sensor not available on this device", null)
        }
    }

    private fun stopStepSensor() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        when (event?.sensor?.type) {
            Sensor.TYPE_STEP_COUNTER -> {
                val totalSteps = event.values[0]
                if (initialStepCount < 0) {
                    initialStepCount = totalSteps
                }
                val cumulative = totalSteps.toInt()
                stepEventSink?.success(mapOf(
                    "cumulative" to cumulative,
                    "stepsSinceBoot" to cumulative
                ))
            }
            Sensor.TYPE_STEP_DETECTOR -> {
                detectorStepCount++
                stepEventSink?.success(mapOf(
                    "cumulative" to detectorStepCount,
                    "stepsSinceBoot" to detectorStepCount
                ))
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun updateAllWidgets() {
        try {
            val context: Context = applicationContext

            val dailyManager = AppWidgetManager.getInstance(context)
            val dailyIds = dailyManager.getAppWidgetIds(ComponentName(context, ZapfitDailyWidget::class.java))
            for (id in dailyIds) {
                ZapfitDailyWidget.updateAppWidget(context, dailyManager, id)
            }

            val summaryManager = AppWidgetManager.getInstance(context)
            val summaryIds = summaryManager.getAppWidgetIds(ComponentName(context, ZapfitSummaryWidget::class.java))
            for (id in summaryIds) {
                ZapfitSummaryWidget.updateAppWidget(context, summaryManager, id)
            }

            val sleepManager = AppWidgetManager.getInstance(context)
            val sleepIds = sleepManager.getAppWidgetIds(ComponentName(context, ZapfitSleepWidget::class.java))
            for (id in sleepIds) {
                ZapfitSleepWidget.updateAppWidget(context, sleepManager, id)
            }

            val hrManager = AppWidgetManager.getInstance(context)
            val hrIds = hrManager.getAppWidgetIds(ComponentName(context, ZapfitHrWidget::class.java))
            for (id in hrIds) {
                ZapfitHrWidget.updateAppWidget(context, hrManager, id)
            }
        } catch (_: Exception) {}
    }

    // =====================================================================
    // COMPANION DEVICE MANAGER
    // =====================================================================

    private val aclReceivers = mutableMapOf<String, BroadcastReceiver>()

    private fun registerAclReceiver(deviceId: String) {
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                if (device?.address == deviceId) {
                    when (intent.action) {
                        BluetoothDevice.ACTION_ACL_CONNECTED -> {
                            Log.d("ZAPFIT", "ACL connected: $deviceId")
                            // Notify Flutter
                        }
                        BluetoothDevice.ACTION_ACL_DISCONNECTED -> {
                            Log.d("ZAPFIT", "ACL disconnected: $deviceId, scheduling reconnect")
                            // Auto-reconnect logic handled by Flutter side
                        }
                    }
                }
            }
        }
        aclReceivers[deviceId] = receiver
        val filter = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_ACL_CONNECTED)
            addAction(BluetoothDevice.ACTION_ACL_DISCONNECTED)
        }
        registerReceiver(receiver, filter)
    }

    private fun unregisterAclReceiver(deviceId: String) {
        aclReceivers.remove(deviceId)?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
        }
    }

    @Suppress("DEPRECATION")
    private fun pairDeviceLegacy(macAddress: String, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val adapter = BluetoothAdapter.getDefaultAdapter()
            val device = adapter.getRemoteDevice(macAddress)
            device.createBond()
            result.success(mapOf("success" to true, "macAddress" to macAddress, "message" to "Bond request sent"))
        } catch (e: Exception) {
            result.success(mapOf("success" to false, "message" to e.message))
        }
    }

    @Suppress("DEPRECATION")
    private fun pairDeviceWithCompanion(macAddress: String, deviceName: String, result: io.flutter.plugin.common.MethodChannel.Result) {
        pairDeviceLegacy(macAddress, result)
    }

    private fun pairDeviceWithCompanionApi33(macAddress: String, deviceName: String, result: io.flutter.plugin.common.MethodChannel.Result) {
        pairDeviceLegacy(macAddress, result)
    }
}
