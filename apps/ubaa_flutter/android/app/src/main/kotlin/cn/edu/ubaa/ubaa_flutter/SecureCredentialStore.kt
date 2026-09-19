package cn.edu.ubaa.ubaa_flutter

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Password vault only. Session, cookies and school authentication remain in Core. */
class SecureCredentialStore(context: Context) {
    private val file = AtomicFile(File(context.noBackupFilesDir, "credentials-v1.enc"))

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "credentials.capability" -> {
                    // Probe actual Keystore encryption and decryption, not just API availability.
                    val probe = byteArrayOf(1, 2, 3)
                    result.success(decrypt(encrypt(probe)).contentEquals(probe))
                }
                "credentials.read" -> {
                    require(call.arguments == NAMESPACE)
                    val data = try {
                        file.openRead().use { input ->
                            require(input.channel.size() <= MAX_BYTES)
                            val bytes = input.readBytes()
                            require(bytes.size <= MAX_BYTES)
                            bytes
                        }
                    } catch (_: FileNotFoundException) {
                        if (file.baseFile.exists()) throw IllegalStateException()
                        result.success(null)
                        return
                    }
                    val plain = decrypt(data)
                    try {
                        val json = JSONObject(String(plain, Charsets.UTF_8))
                        result.success(validated(mapOf(
                            "username" to json.get("username"),
                            "password" to json.get("password"),
                            "autoLogin" to json.get("autoLogin"),
                        )))
                    } finally { plain.fill(0) }
                }
                "credentials.write" -> {
                    val args = call.arguments as? Map<*, *> ?: throw IllegalArgumentException()
                    require(args["namespace"] == NAMESPACE)
                    val plain = JSONObject(validated(args)).toString().toByteArray(Charsets.UTF_8)
                    val encrypted = try { encrypt(plain) } finally { plain.fill(0) }
                    val stream = file.startWrite()
                    try {
                        stream.write(encrypted)
                        file.finishWrite(stream)
                    } catch (error: Exception) {
                        file.failWrite(stream)
                        throw error
                    }
                    result.success(null)
                }
                "credentials.clear" -> {
                    require(call.arguments == NAMESPACE)
                    file.delete()
                    check(!file.baseFile.exists())
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            if (call.method == "credentials.capability") result.success(false)
            else result.error("credential_storage", "Secure credential storage failed", null)
        }
    }

    private fun validated(args: Map<*, *>): Map<String, Any> {
        val username = args["username"] as? String ?: throw IllegalArgumentException()
        val password = args["password"] as? String ?: throw IllegalArgumentException()
        val autoLogin = args["autoLogin"] as? Boolean ?: throw IllegalArgumentException()
        require(username.isNotBlank() && username.length <= 1024)
        require(password.isNotEmpty() && password.length <= 4096)
        return mapOf("username" to username, "password" to password, "autoLogin" to autoLogin)
    }

    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(NAMESPACE, null) as? SecretKey)?.let { return it }
        // Never silently replace a missing key while encrypted credentials still exist.
        check(create && !file.baseFile.exists() && !File(file.baseFile.path + ".bak").exists())
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(NAMESPACE, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build())
        }.generateKey()
    }

    private fun encrypt(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        cipher.updateAAD(NAMESPACE.toByteArray(Charsets.UTF_8))
        check(cipher.iv.size == 12)
        return byteArrayOf(1) + cipher.iv + cipher.doFinal(plain)
    }

    private fun decrypt(data: ByteArray): ByteArray {
        require(data.size in 29..MAX_BYTES && data[0] == 1.toByte())
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, data.copyOfRange(1, 13)))
        cipher.updateAAD(NAMESPACE.toByteArray(Charsets.UTF_8))
        return cipher.doFinal(data, 13, data.size - 13)
    }

    companion object {
        private const val NAMESPACE = "com.buaa.ubaa.credentials.v1"
        private const val MAX_BYTES = 64 * 1024
    }
}
