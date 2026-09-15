package com.dev.zapfit

import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import javax.crypto.Cipher
import javax.crypto.spec.SecretKeySpec

/**
 * Xiaomi/Huami BLE authentication service.
 * Implements the 3-step AES/ECB auth from Gadgetbridge InitOperation.java.
 *
 * Flow (matching Gadgetbridge exactly):
 * 1. connectGatt(autoConnect=false, TRANSPORT_LE)
 * 2. discoverServices()
 * 3. Enable notifications on auth characteristic (0x0009)
 * 4. Write [AUTH_SEND_KEY, authFlags, ...secretKey] → device responds SUCCESS
 * 5. Write [AUTH_REQUEST_RANDOM, authFlags] → device sends 16-byte random nonce
 * 6. Encrypt nonce with AES/ECB(key) → send back → device confirms
 *
 * Key differences from old code:
 * - Service UUID: 0xFEE1 (not 0xFEE0!)
 * - authFlags: 0x00 for most devices (not 0x08)
 * - cryptFlags: 0x80 for Mi Band 4+ (affects step 3 byte)
 * - Single GATT connection shared with flutter_blue_plus after auth
 */
class XiaomiBleAuthManager {
    companion object {
        private const val TAG = "XIAOMI_AUTH"

        // Auth commands (from HuamiService.java lines 82-116)
        private const val AUTH_SEND_KEY: Byte = 0x01
        private const val AUTH_REQUEST_RANDOM: Byte = 0x02
        private const val AUTH_SEND_ENCRYPTED: Byte = 0x03
        private const val AUTH_RESPONSE: Byte = 0x10
        private const val AUTH_SUCCESS: Byte = 0x01
        private const val AUTH_FAIL: Byte = 0x04

        // Mi Band 2 Service UUID (from HuamiService.java line 23)
        // NOT 0xFEE0! Gadgetbridge uses 0xFEE1 for auth
        private val UUID_SERVICE_MIBAND2 = java.util.UUID.fromString("0000fee1-0000-1000-8000-00805f9b34fb")
        // Auth characteristic (from HuamiService.java line 49)
        private val UUID_CHAR_AUTH = java.util.UUID.fromString("00000009-0000-3512-2118-0009af100700")
        private val UUID_CCCD = java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        // Notification characteristic (Mi Band protocol)
        private val UUID_CHAR_NOTIFICATION = java.util.UUID.fromString("00000002-0000-3512-2118-0009af100700")

        // Default secret key (from InitOperation.java line 93)
        private val DEFAULT_SECRET_KEY = byteArrayOf(
            0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37,
            0x38, 0x39, 0x40, 0x41, 0x42, 0x43, 0x44, 0x45
        )

        // STATIC guard — prevents multiple simultaneous auth across ALL instances
        @Volatile
        private var globalAuthInProgress = false
    }

    private var gatt: BluetoothGatt? = null
    private var authCharacteristic: BluetoothGattCharacteristic? = null
    private val handler = Handler(Looper.getMainLooper())
    private var authCallback: ((Boolean, String) -> Unit)? = null
    private var authStep = 0
    private var secretKey = DEFAULT_SECRET_KEY
    private var isAuthenticating = false
    private var serviceDiscoveryRetries = 0
    private var macAddress = ""
    private var context: Context? = null
    private var bondReceiver: BroadcastReceiver? = null
    private var isAuthComplete = false
    private var standardServicesCallback: ((List<BluetoothGattService>) -> Unit)? = null

    // Per-device auth configuration (from Gadgetbridge HuamiSupport)
    // authFlags: 0x00 for Mi Band 3+, Amazfit Bip, Mi Band 4+
    //            0x08 only for Mi Band 2
    // cryptFlags: 0x00 for Mi Band 2/3, Amazfit Bip
    //             0x80 for Mi Band 4+, Amazfit Bip S
    private var authFlags: Byte = 0x00
    private var cryptFlags: Byte = 0x00

    /**
     * Connect to device and perform 3-step Huami auth.
     * Returns the GATT connection on success so caller can reuse it.
     */
    fun connectAndAuth(
        context: Context,
        macAddress: String,
        authKeyHex: String?,
        callback: (Boolean, String) -> Unit
    ) {
        if (isAuthenticating || globalAuthInProgress) {
            Log.w(TAG, "Auth already in progress, ignoring duplicate request (instance=$isAuthenticating, global=$globalAuthInProgress)")
            callback(false, "Auth already in progress")
            return
        }
        isAuthenticating = true
        globalAuthInProgress = true
        serviceDiscoveryRetries = 0
        this.macAddress = macAddress
        this.context = context
        authCallback = callback

        // Load auth key
        if (!authKeyHex.isNullOrBlank()) {
            try {
                val hex = if (authKeyHex.startsWith("0x")) authKeyHex.substring(2) else authKeyHex
                secretKey = ByteArray(16) { i -> Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16).toByte() }
                Log.d(TAG, "Using custom auth key: ${hex.take(8)}...")
            } catch (e: Exception) {
                Log.w(TAG, "Failed to parse auth key, using default")
                secretKey = DEFAULT_SECRET_KEY
            }
        } else {
            secretKey = DEFAULT_SECRET_KEY
            Log.d(TAG, "Using default auth key")
        }

        val bluetoothManager = context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter = bluetoothManager.adapter ?: run {
            isAuthenticating = false
            globalAuthInProgress = false
            callback(false, "No Bluetooth adapter")
            return
        }

        val device = adapter.getRemoteDevice(macAddress) ?: run {
            isAuthenticating = false
            globalAuthInProgress = false
            callback(false, "Device not found: $macAddress")
            return
        }

        // Close any existing GATT connection
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {}
        gatt = null
        authCharacteristic = null
        authStep = 0

        Log.d(TAG, "Connecting to $macAddress (autoConnect=false, TRANSPORT_LE)")

        // Small delay to let previous connection fully close
        handler.postDelayed({
            gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                device.connectGatt(context, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                device.connectGatt(context, false, gattCallback)
            }
            if (gatt == null) {
                Log.e(TAG, "connectGatt returned null!")
                isAuthenticating = false
                globalAuthInProgress = false
                callback(false, "Failed to connect (GATT null)")
            }
        }, 300)

        // Timeout after 30 seconds
        handler.postDelayed({
            if (isAuthenticating) {
                Log.w(TAG, "Auth timed out after 30s")
                isAuthenticating = false
                globalAuthInProgress = false
                val cb = authCallback
                authCallback = null
                cb?.invoke(false, "Auth timed out")
                cleanup()
            }
        }, 30000)
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
            if (gatt == null) return
            Log.d(TAG, "GATT state: status=$status, newState=$newState")

            when (newState) {
                BluetoothProfile.STATE_CONNECTED -> {
                    Log.d(TAG, "Connected! Waiting 1.5s for stabilization then discovering services...")
                    handler.postDelayed({
                        try {
                            gatt.discoverServices()
                        } catch (e: Exception) {
                            Log.e(TAG, "discoverServices failed: $e")
                            finishAuth(false, "discoverServices failed: ${e.message}")
                        }
                    }, 1500)
                }
                BluetoothProfile.STATE_DISCONNECTED -> {
                    Log.d(TAG, "Disconnected (status=$status)")
                    if (isAuthenticating) {
                        finishAuth(false, "Disconnected during auth (status=$status)")
                    }
                }
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
            if (gatt == null) return
            val services = gatt.services
            Log.d(TAG, "Services discovered: status=$status, count=${services?.size ?: 0}")

            // If auth is already complete, this is the standard services discovery
            if (isAuthComplete) {
                Log.d(TAG, "Auth complete — post-auth initialization (Gadgetbridge phase 2+3)...")
                services?.forEach { svc ->
                    Log.d(TAG, "  Standard service: ${svc.uuid} (${svc.characteristics?.size ?: 0} chars)")
                }

                // Gadgetbridge post-auth init: enable notifications on key characteristics
                val g = gatt ?: return

                // 1. Enable notifications on config characteristic (0x0003) — Gadgetbridge line 149
                val configService = g.getService(java.util.UUID.fromString("0000fee0-0000-3512-2118-0009af100700"))
                if (configService != null) {
                    val configChar = configService.getCharacteristic(java.util.UUID.fromString("00000003-0000-3512-2118-0009af100700"))
                    if (configChar != null) {
                        enableNotification(g, configChar)
                        Log.d(TAG, "  Enabled notifications on config (0x0003)")
                    }
                }

                // 2. Enable notifications on battery (0x0006) — Gadgetbridge line 156
                if (configService != null) {
                    val batteryChar = configService.getCharacteristic(java.util.UUID.fromString("00000006-0000-3512-2118-0009af100700"))
                    if (batteryChar != null) {
                        enableNotification(g, batteryChar)
                        Log.d(TAG, "  Enabled notifications on battery (0x0006)")
                    }
                }

                // 3. Enable notifications on device event (0x0010) — Gadgetbridge line 159
                if (configService != null) {
                    val eventChar = configService.getCharacteristic(java.util.UUID.fromString("00000010-0000-3512-2118-0009af100700"))
                    if (eventChar != null) {
                        enableNotification(g, eventChar)
                        Log.d(TAG, "  Enabled notifications on device event (0x0010)")
                    }
                }

                // 4. Enable HR notifications
                val hrService = g.getService(java.util.UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb"))
                if (hrService != null) {
                    val hrChar = hrService.getCharacteristic(java.util.UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb"))
                    if (hrChar != null) {
                        enableNotification(g, hrChar)
                        Log.d(TAG, "  Enabled notifications on HR (0x2A37)")
                    }
                }

                // 5. Request battery info — Gadgetbridge line 159
                handler.postDelayed({
                    if (configService != null) {
                        val batteryChar = configService.getCharacteristic(java.util.UUID.fromString("00000006-0000-3512-2118-0009af100700"))
                        if (batteryChar != null) {
                            g.readCharacteristic(batteryChar)
                            Log.d(TAG, "  Reading battery info...")
                        }
                    }
                }, 1000)

                // 6. Send current time to device — Gadgetbridge setCurrentTimeWithService
                handler.postDelayed({
                    sendCurrentTime(g)
                }, 1500)

                // 6. Send ALL configuration commands from Gadgetbridge phase 3
                // These are the exact writes Gadgetbridge sends to 0x0003 after auth
                handler.postDelayed({
                    sendDeviceConfiguration(g)
                }, 2000)

                // Notify Flutter that initialization is complete
                standardServicesCallback?.invoke(services ?: emptyList())
                standardServicesCallback = null
                return
            }

            if (status != BluetoothGatt.GATT_SUCCESS) {
                finishAuth(false, "Service discovery failed: status=$status")
                return
            }

            // Log ALL services for debugging
            services?.forEach { svc ->
                Log.d(TAG, "  Service: ${svc.uuid} (${svc.characteristics?.size ?: 0} chars)")
                svc.characteristics?.forEach { char ->
                    Log.d(TAG, "    Char: ${char.uuid} props=${char.properties}")
                }
            }

            // Find Mi Band 2 auth service (0xFEE1)
            // Also try 0xFEE0 as fallback (some older devices)
            var huamiService = gatt.getService(UUID_SERVICE_MIBAND2)
            if (huamiService == null) {
                // Try FEE0 as fallback
                val fee0 = java.util.UUID.fromString("0000fee0-0000-1000-8000-00805f9b34fb")
                huamiService = gatt.getService(fee0)
                if (huamiService != null) {
                    Log.d(TAG, "Found service 0xFEE0 (fallback)")
                }
            }

            if (huamiService == null) {
                serviceDiscoveryRetries++
                if (serviceDiscoveryRetries < 5) {
                    Log.w(TAG, "Auth service not found (attempt $serviceDiscoveryRetries), retrying in 2s...")
                    handler.postDelayed({
                        try { gatt.discoverServices() } catch (_: Exception) {}
                    }, 2000)
                    return
                }
                finishAuth(false, "Auth service (0xFEE1/0xFEE0) not found after $serviceDiscoveryRetries attempts. Available: ${services?.map { it.uuid }?.joinToString()}")
                return
            }

            // Find auth characteristic (0x0009)
            authCharacteristic = huamiService.getCharacteristic(UUID_CHAR_AUTH)
            if (authCharacteristic == null) {
                finishAuth(false, "Auth characteristic (0x0009) not found in service")
                return
            }

            Log.d(TAG, "Found auth service + characteristic! Starting auth flow...")
            startAuth(gatt)
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            // If auth is complete, handle standard BLE characteristics
            if (isAuthComplete) {
                handleStandardCharacteristicChanged(characteristic)
                return
            }

            if (characteristic.uuid != UUID_CHAR_AUTH) return

            val value = characteristic.value ?: return
            Log.d(TAG, "=== AUTH STEP $authStep RESPONSE ===")
            Log.d(TAG, "  Raw bytes [${value.size}]: ${value.joinToString(" ") { String.format("%02X", it) }}")
            Log.d(TAG, "  byte[0]=0x${String.format("%02X", value[0])} (expect AUTH_RESPONSE=0x10)")
            if (value.size > 1) Log.d(TAG, "  byte[1]=0x${String.format("%02X", value[1])} (cmd echo)")
            if (value.size > 2) Log.d(TAG, "  byte[2]=0x${String.format("%02X", value[2])} (status: 01=OK, 04=FAIL)")

            if (value.isEmpty() || value[0] != AUTH_RESPONSE) {
                Log.w(TAG, "Unexpected response (not AUTH_RESPONSE 0x10)")
                return
            }

            when {
                // Step 1 response: AUTH_SEND_KEY SUCCESS → request random
                value[1] == AUTH_SEND_KEY && value[2] == AUTH_SUCCESS -> {
                    Log.d(TAG, "Step 1 OK: Key accepted! Requesting random nonce...")
                    authStep = 1
                    requestRandomAuth(gatt)
                }

                // Step 1 response: AUTH_SEND_KEY FAIL
                value[1] == AUTH_SEND_KEY && value[2] == AUTH_FAIL -> {
                    Log.w(TAG, "Step 1 FAILED: Key rejected by device")
                    finishAuth(false, "Auth key rejected by device")
                }

                // Step 2 response: AUTH_REQUEST_RANDOM SUCCESS + random nonce
                (value[1].toInt() and 0x0F) == AUTH_REQUEST_RANDOM.toInt() && value[2] == AUTH_SUCCESS -> {
                    authStep = 2
                    if (value.size < 19) {
                        Log.w(TAG, "Step 2 FAILED: Nonce too short: ${value.size} bytes (need 19)")
                        finishAuth(false, "Nonce too short: ${value.size} bytes (need 19)")
                        return
                    }
                    val randomNonce = value.copyOfRange(3, 19)
                    Log.d(TAG, "Step 2 OK: Got random nonce:")
                    Log.d(TAG, "  Nonce [${randomNonce.size}]: ${randomNonce.joinToString(" ") { String.format("%02X", it) }}")
                    Log.d(TAG, "  Key:   ${secretKey.joinToString(" ") { String.format("%02X", it) }}")
                    sendEncryptedAuth(gatt, randomNonce)
                }

                // Step 3 response: AUTH_SEND_ENCRYPTED
                (value[1].toInt() and 0x0F) == AUTH_SEND_ENCRYPTED.toInt() -> {
                    authStep = 3
                    if (value[2] == AUTH_SUCCESS) {
                        Log.d(TAG, "Step 3 OK: AUTH SUCCESS!")
                        triggerBonding(gatt)
                    } else {
                        Log.w(TAG, "Step 3 FAILED: status=0x${String.format("%02X", value[2])}")
                        Log.w(TAG, "  This means the encrypted nonce was rejected.");
                        Log.w(TAG, "  Possible causes: wrong key, wrong cryptFlags, wrong authFlags");
                        Log.w(TAG, "  Current: authFlags=0x${String.format("%02X", authFlags)}, cryptFlags=0x${String.format("%02X", cryptFlags)}");
                        finishAuth(false, "Auth failed at step 3 — wrong key?")
                    }
                }

                else -> {
                    Log.w(TAG, "Unknown response: byte[1]=0x${String.format("%02X", value[1])}, byte[2]=0x${String.format("%02X", value[2])}")
                }
            }
        }

        override fun onDescriptorWrite(gatt: BluetoothGatt?, descriptor: BluetoothGattDescriptor?, status: Int) {
            Log.d(TAG, "CCCD write: status=$status")
        }
    }

    private fun startAuth(gatt: BluetoothGatt) {
        authStep = 0
        val char = authCharacteristic ?: return

        // Enable notifications on auth characteristic
        // Gadgetbridge: NotifyAction enables notifications on UUID_CHARACTERISTIC_AUTH
        gatt.setCharacteristicNotification(char, true)
        val cccd = char.getDescriptor(UUID_CCCD)
        if (cccd != null) {
            cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            gatt.writeDescriptor(cccd)
        }

        // Wait for CCCD write to complete, then send step 1
        handler.postDelayed({
            // Step 1: Send secret key
            // From InitOperation.java line 75:
            // byte[] sendKey = ArrayUtils.addAll(new byte[]{AUTH_SEND_KEY, authFlags}, getSecretKey())
            val authCmd = ByteArray(2 + secretKey.size)
            authCmd[0] = AUTH_SEND_KEY
            authCmd[1] = authFlags
            secretKey.copyInto(authCmd, 2)

            Log.d(TAG, "Step 1: Sending auth key (authFlags=${String.format("%02X", authFlags)})...")
            char.value = authCmd
            gatt.writeCharacteristic(char)
        }, 500)
    }

    private fun requestRandomAuth(gatt: BluetoothGatt) {
        val char = authCharacteristic ?: return

        // Step 2: Request random auth number
        // From InitOperation.java line 86:
        // return new byte[]{AUTH_REQUEST_RANDOM_AUTH_NUMBER, authFlags}
        // If cryptFlags != 0x00: new byte[]{(byte)(cryptFlags | AUTH_REQUEST_RANDOM), authFlags}
        val cmdByte = if (cryptFlags.toInt() != 0x00) {
            (cryptFlags.toInt() or AUTH_REQUEST_RANDOM.toInt()).toByte()
        } else {
            AUTH_REQUEST_RANDOM
        }
        val requestCmd = byteArrayOf(cmdByte, authFlags)

        Log.d(TAG, "Step 2: Requesting random nonce (cmd=0x${String.format("%02X", cmdByte)})...")
        char.value = requestCmd
        gatt.writeCharacteristic(char)
    }

    private fun sendEncryptedAuth(gatt: BluetoothGatt, randomNonce: ByteArray) {
        val char = authCharacteristic ?: return

        try {
            val cipher = Cipher.getInstance("AES/ECB/NoPadding")
            val keySpec = SecretKeySpec(secretKey, "AES")
            cipher.init(Cipher.ENCRYPT_MODE, keySpec)

            // Pad to 16 bytes (AES block size)
            val paddedNonce = ByteArray(16)
            System.arraycopy(randomNonce, 0, paddedNonce, 0, minOf(randomNonce.size, 16))

            val encrypted = cipher.doFinal(paddedNonce)

            // From InitOperation.java line 137-138:
            // byte[] responseValue = ArrayUtils.addAll(
            //     new byte[]{(byte)(AUTH_SEND_ENCRYPTED | cryptFlags), authFlags}, eValue)
            val cmdByte = (AUTH_SEND_ENCRYPTED.toInt() or cryptFlags.toInt()).toByte()
            val responseCmd = ByteArray(2 + encrypted.size)
            responseCmd[0] = cmdByte
            responseCmd[1] = authFlags
            encrypted.copyInto(responseCmd, 2)

            Log.d(TAG, "Step 3: Sending encrypted nonce:")
            Log.d(TAG, "  cmdByte=0x${String.format("%02X", cmdByte)} (AUTH_SEND_ENCRYPTED | cryptFlags)")
            Log.d(TAG, "  authFlags=0x${String.format("%02X", authFlags)}")
            Log.d(TAG, "  Nonce input:  ${paddedNonce.joinToString(" ") { String.format("%02X", it) }}")
            Log.d(TAG, "  Encrypted:    ${encrypted.joinToString(" ") { String.format("%02X", it) }}")
            Log.d(TAG, "  Full command: ${responseCmd.joinToString(" ") { String.format("%02X", it) }}")
            char.value = responseCmd
            gatt.writeCharacteristic(char)
        } catch (e: Exception) {
            Log.e(TAG, "AES encryption failed: ${e.message}")
            finishAuth(false, "Encryption error: ${e.message}")
        }
    }

    /**
     * After auth succeeds, trigger Android BLE bonding (pairing).
     * The watch expects the phone to complete BLE pairing before data exchange.
     * This is what Gadgetbridge does — see BondAction.java and BtLEQueue.java.
     */
    private fun triggerBonding(gatt: BluetoothGatt) {
        val ctx = context
        val device = gatt.device
        if (ctx == null) {
            Log.w(TAG, "No context for bonding, skipping")
            finishAuth(true, "Huami auth successful (no bonding)")
            return
        }

        // Check if already bonded
        if (device.bondState == BluetoothDevice.BOND_BONDED) {
            Log.d(TAG, "Device already bonded, skipping bond")
            finishAuth(true, "Huami auth successful (already bonded)")
            return
        }

        Log.d(TAG, "Triggering createBond() for ${device.address}...")

        // Register receiver for bond state changes BEFORE calling createBond
        bondReceiver = object : BroadcastReceiver() {
            override fun onReceive(ctx: Context, intent: Intent) {
                if (intent.action != BluetoothDevice.ACTION_BOND_STATE_CHANGED) return

                val bondDevice = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                } else {
                    @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)

                if (bondDevice?.address != macAddress) return

                Log.d(TAG, "Bond state changed: $bondState")
                when (bondState) {
                    BluetoothDevice.BOND_BONDED -> {
                        Log.d(TAG, "Bonding SUCCESS!")
                        unregisterBondReceiver()
                        finishAuth(true, "Huami auth + bonding successful")
                    }
                    BluetoothDevice.BOND_NONE -> {
                        Log.w(TAG, "Bonding REJECTED or FAILED")
                        unregisterBondReceiver()
                        // Auth succeeded but bonding failed — still report success
                        // The device may work without bonding for basic data
                        finishAuth(true, "Auth successful (bonding rejected)")
                    }
                }
            }
        }

        val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ctx.registerReceiver(bondReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            ctx.registerReceiver(bondReceiver, filter)
        }

        // Trigger bonding
        try {
            val result = device.createBond()
            Log.d(TAG, "createBond() returned: $result")
        } catch (e: Exception) {
            Log.e(TAG, "createBond() failed: ${e.message}")
            unregisterBondReceiver()
            finishAuth(true, "Auth successful (bonding error: ${e.message})")
        }

        // Timeout for bonding (15 seconds)
        handler.postDelayed({
            if (isAuthenticating) {
                Log.w(TAG, "Bonding timed out after 15s")
                unregisterBondReceiver()
                finishAuth(true, "Auth successful (bonding timed out)")
            }
        }, 15000)
    }

    private fun unregisterBondReceiver() {
        try {
            bondReceiver?.let { context?.unregisterReceiver(it) }
        } catch (_: Exception) {}
        bondReceiver = null
    }

    private fun finishAuth(success: Boolean, message: String) {
        if (!isAuthenticating) return
        isAuthenticating = false
        globalAuthInProgress = false
        Log.d(TAG, "Auth result: success=$success, msg=$message")

        if (success && gatt != null) {
            // Auth succeeded — GATT is still open!
            isAuthComplete = true
            // Discover standard BLE services (HR, battery, etc.) on the same GATT
            Log.d(TAG, "Auth OK! Discovering standard services on same GATT...")
            handler.postDelayed({
                try { gatt?.discoverServices() } catch (e: Exception) { Log.e(TAG, "discoverServices failed: $e") }
            }, 500)
        } else {
            val cb = authCallback
            authCallback = null
            cb?.invoke(success, message)
        }
    }

    private fun cleanup() {
        unregisterBondReceiver()
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {}
        gatt = null
        authCharacteristic = null
    }

    fun disconnect() {
        isAuthenticating = false
        globalAuthInProgress = false
        cleanup()
        authCallback = null
    }

    // ====================================================================
    // Post-auth helpers (Gadgetbridge phase 2+3)
    // ====================================================================

    private fun enableNotification(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
        try {
            gatt.setCharacteristicNotification(characteristic, true)
            val cccd = characteristic.getDescriptor(java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
            if (cccd != null) {
                cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                gatt.writeDescriptor(cccd)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to enable notification: ${e.message}")
        }
    }

    private fun sendCurrentTime(gatt: BluetoothGatt) {
        try {
            // Gadgetbridge setCurrentTimeWithService: writes current time to 0x2A2B
            val timeService = gatt.getService(java.util.UUID.fromString("00001805-0000-1000-8000-00805f9b34fb"))
            if (timeService != null) {
                val timeChar = timeService.getCharacteristic(java.util.UUID.fromString("00002a2b-0000-1000-8000-00805f9b34fb"))
                if (timeChar != null) {
                    val now = java.util.Calendar.getInstance()
                    val year = now.get(java.util.Calendar.YEAR)
                    val month = now.get(java.util.Calendar.MONTH) + 1
                    val day = now.get(java.util.Calendar.DAY_OF_MONTH)
                    val hour = now.get(java.util.Calendar.HOUR_OF_DAY)
                    val minute = now.get(java.util.Calendar.MINUTE)
                    val second = now.get(java.util.Calendar.SECOND)

                    val timeData = byteArrayOf(
                        (year and 0xFF).toByte(),
                        (year shr 8 and 0xFF).toByte(),
                        month.toByte(),
                        day.toByte(),
                        hour.toByte(),
                        minute.toByte(),
                        second.toByte(),
                        now.get(java.util.Calendar.DAY_OF_WEEK).toByte(),
                        0
                    )
                    timeChar.value = timeData
                    gatt.writeCharacteristic(timeChar)
                    Log.d(TAG, "  Sent current time: $year-$month-$day $hour:$minute:$second")
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send current time: ${e.message}")
        }
    }

    /**
     * Send device configuration commands — exact replica of Gadgetbridge phase 3.
     * From Gadgetbridge logs: writes to characteristic 0x0003 after auth.
     */
    private fun sendDeviceConfiguration(gatt: BluetoothGatt) {
        try {
            val configService = gatt.getService(java.util.UUID.fromString("0000fee0-0000-3512-2118-0009af100700")) ?: return
            val configChar = configService.getCharacteristic(java.util.UUID.fromString("00000003-0000-3512-2118-0009af100700")) ?: return

            // Configuration commands from Gadgetbridge HuamiSupport phase 3
            // Each command is sent with a delay to avoid overwhelming the device
            val commands = listOf(
                // Set locale to Russian (06 17 00 72 75 5F 52 55 = "ru_RU")
                byteArrayOf(0x06, 0x17, 0x00, 0x72, 0x75, 0x5F, 0x52, 0x55),
                // Display config: enable items
                byteArrayOf(0x06, 0x0A, 0x00, 0x00),
                // Display config: shortcuts
                byteArrayOf(0x06, 0x02, 0x00, 0x01),
                // Display config: goal notification
                byteArrayOf(0x06, 0x03, 0x00, 0x00),
                // Display config: inactivity alert
                byteArrayOf(0x06, 0x05, 0x00, 0x00),
                // Display config: DND
                byteArrayOf(0x06, 0x10, 0x00, 0x00, 0x01),
                // Display config: hourly chime
                byteArrayOf(0x06, 0x06, 0x00, 0x00),
                // Display config: display items (step, distance, calorie, etc.)
                byteArrayOf(0x06, 0x1A, 0x00, 0x00, 0x96.toByte()),
                // Display config: wear location
                byteArrayOf(0x06, 0x22, 0x00, 0x00),
                // Display config: lift wrist display
                byteArrayOf(0x06, 0x19, 0x00, 0x00),
                // Display config: display timeout
                byteArrayOf(0x06, 0x1F, 0x00, 0x00),
                // Display config: date format
                byteArrayOf(0x06, 0x0D, 0x00, 0x00),
                // Display config: goal notification enabled
                byteArrayOf(0x06, 0x0C, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00),
                // HR measurement interval (0 = manual)
                byteArrayOf(0x06, 0x1F, 0x00, 0x00),
                // Enable HR alerts
                byteArrayOf(0x06, 0x08, 0x00, 0x3C, 0x00, 0x04, 0x00, 0x15, 0x00, 0x00, 0x00, 0x00),
            )

            var delay = 500L
            for (cmd in commands) {
                handler.postDelayed({
                    try {
                        configChar.value = cmd
                        gatt.writeCharacteristic(configChar)
                        Log.d(TAG, "  Config: ${cmd.joinToString(" ") { String.format("%02X", it) }}")
                    } catch (e: Exception) {
                        Log.w(TAG, "  Config write failed: ${e.message}")
                    }
                }, delay)
                delay += 100 // 100ms between commands
            }

            Log.d(TAG, "  Sent ${commands.size} configuration commands")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send device configuration: ${e.message}")
        }
    }

    /**
     * Auto-detect device type and set authFlags/cryptFlags accordingly.
     * Call this before connectAndAuth if you know the device name.
     * Based on Gadgetbridge HuamiSupport device detection.
     */
    fun configureForDevice(deviceName: String) {
        val name = deviceName.lowercase()
        when {
            name.contains("mi band 2") || name.contains("mi band2") -> {
                authFlags = 0x08
                cryptFlags = 0x00
                Log.d(TAG, "Configured for Mi Band 2: authFlags=0x08, cryptFlags=0x00")
            }
            name.contains("mi band 3") || name.contains("mi band3") -> {
                authFlags = 0x00
                cryptFlags = 0x00
                Log.d(TAG, "Configured for Mi Band 3: authFlags=0x00, cryptFlags=0x00")
            }
            name.contains("mi band 4") || name.contains("mi band4") || name.contains("mi band 5") || name.contains("mi band 5") -> {
                authFlags = 0x00.toByte()
                cryptFlags = 0x80.toByte()
                Log.d(TAG, "Configured for Mi Band 4/5: authFlags=0x00, cryptFlags=0x80")
            }
            name.contains("amazfit bip") && !name.contains("s") -> {
                authFlags = 0x00
                cryptFlags = 0x00
                Log.d(TAG, "Configured for Amazfit Bip: authFlags=0x00, cryptFlags=0x00")
            }
            name.contains("amazfit bip s") || name.contains("amazfit bip s") -> {
                authFlags = 0x00.toByte()
                cryptFlags = 0x80.toByte()
                Log.d(TAG, "Configured for Amazfit Bip S: authFlags=0x00, cryptFlags=0x80")
            }
            else -> {
                // Default: try Mi Band 3+ config (most common)
                authFlags = 0x00
                cryptFlags = 0x00
                Log.d(TAG, "Default config for '$deviceName': authFlags=0x00, cryptFlags=0x00")
            }
        }
    }

    // ====================================================================
    // Standard BLE services reading (through same GATT after auth)
    // ====================================================================

    fun readBatteryLevel(callback: (Int) -> Unit) {
        val g = gatt ?: return
        val batteryService = g.getService(java.util.UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb"))
        if (batteryService == null) {
            Log.w(TAG, "Battery service not found")
            callback(-1)
            return
        }
        val batteryChar = batteryService.getCharacteristic(java.util.UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb"))
        if (batteryChar == null) {
            Log.w(TAG, "Battery characteristic not found")
            callback(-1)
            return
        }
        g.readCharacteristic(batteryChar)
        // Battery value will come through onCharacteristicRead
        // For now, return -1 and let the callback handle it
        callback(-1)
    }

    fun enableHeartRateNotifications(callback: (Int) -> Unit) {
        val g = gatt ?: return
        val hrService = g.getService(java.util.UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb"))
        if (hrService == null) {
            Log.w(TAG, "Heart Rate service not found")
            return
        }
        val hrChar = hrService.getCharacteristic(java.util.UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb"))
        if (hrChar == null) {
            Log.w(TAG, "Heart Rate characteristic not found")
            return
        }
        hrCallback = callback
        g.setCharacteristicNotification(hrChar, true)
        val cccd = hrChar.getDescriptor(java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"))
        if (cccd != null) {
            cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
            g.writeDescriptor(cccd)
        }
        Log.d(TAG, "Heart Rate notifications enabled")
    }

    private var hrCallback: ((Int) -> Unit)? = null

    fun handleStandardCharacteristicChanged(characteristic: BluetoothGattCharacteristic) {
        when (characteristic.uuid.toString()) {
            "00002a37-0000-1000-8000-00805f9b34fb" -> {
                // Heart Rate Measurement
                val value = characteristic.value ?: return
                if (value.isNotEmpty()) {
                    val flags = value[0].toInt()
                    val hr = if (flags and 0x01 == 0) {
                        value[1].toInt() and 0xFF
                    } else {
                        (value[1].toInt() and 0xFF) or ((value[2].toInt() and 0xFF) shl 8)
                    }
                    Log.d(TAG, "Heart Rate: $hr bpm")
                    hrCallback?.invoke(hr)
                }
            }
            "00002a19-0000-1000-8000-00805f9b34fb" -> {
                // Battery Level
                val value = characteristic.value ?: return
                if (value.isNotEmpty()) {
                    val level = value[0].toInt() and 0xFF
                    Log.d(TAG, "Battery Level: $level%")
                }
            }
        }
    }
}
