package com.example.alter

import android.content.Context
import android.nfc.cardemulation.HostApduService
import android.os.Bundle
import android.util.Base64

/**
 * Emulates an NFC Forum Type 4 NDEF tag over Host Card Emulation so two phones
 * can exchange ALTER profiles by tapping — the sharer runs this service, the
 * other phone reads it with a normal NDEF reader session. The NDEF message to
 * serve is set from Flutter (via [AlterHceBridge]) and cached in prefs so it
 * survives the service being (re)created by the platform.
 */
class AlterHceService : HostApduService() {

    private enum class Selected { NONE, CC, NDEF }

    private var selected = Selected.NONE

    override fun processCommandApdu(commandApdu: ByteArray?, extras: Bundle?): ByteArray {
        val apdu = commandApdu ?: return SW_ERROR

        // SELECT (by name) the NDEF application.
        if (apdu.size >= 5 + AID_NDEF.size &&
            apdu[0] == 0x00.toByte() && apdu[1] == 0xA4.toByte() && apdu[2] == 0x04.toByte()
        ) {
            val lc = apdu[4].toInt() and 0xff
            if (lc == AID_NDEF.size &&
                apdu.copyOfRange(5, 5 + AID_NDEF.size).contentEquals(AID_NDEF)
            ) {
                selected = Selected.NONE
                return SW_OK
            }
            return SW_FILE_NOT_FOUND
        }

        // SELECT (by file id) the Capability Container or the NDEF file.
        if (apdu.size >= 7 && apdu[0] == 0x00.toByte() && apdu[1] == 0xA4.toByte() &&
            apdu[2] == 0x00.toByte() && apdu[3] == 0x0C.toByte() &&
            (apdu[4].toInt() and 0xff) == 0x02
        ) {
            val fileId = byteArrayOf(apdu[5], apdu[6])
            return when {
                fileId.contentEquals(CC_FILE_ID) -> { selected = Selected.CC; SW_OK }
                fileId.contentEquals(NDEF_FILE_ID) -> { selected = Selected.NDEF; SW_OK }
                else -> SW_FILE_NOT_FOUND
            }
        }

        // READ BINARY from the currently-selected file.
        if (apdu.size >= 5 && apdu[0] == 0x00.toByte() && apdu[1] == 0xB0.toByte()) {
            val offset = ((apdu[2].toInt() and 0xff) shl 8) or (apdu[3].toInt() and 0xff)
            val leRaw = apdu[4].toInt() and 0xff
            val le = if (leRaw == 0) 256 else leRaw
            val data = when (selected) {
                Selected.CC -> CAPABILITY_CONTAINER
                Selected.NDEF -> ndefFile()
                Selected.NONE -> return SW_FILE_NOT_FOUND
            }
            if (offset > data.size) return SW_FILE_NOT_FOUND
            val end = minOf(offset + le, data.size)
            return data.copyOfRange(offset, end) + SW_OK
        }

        return SW_ERROR
    }

    override fun onDeactivated(reason: Int) {
        selected = Selected.NONE
    }

    /** NDEF file = 2-byte length (NLEN) followed by the NDEF message. */
    private fun ndefFile(): ByteArray {
        val message = currentNdefMessage()
        val nlen = message.size
        return byteArrayOf(((nlen shr 8) and 0xff).toByte(), (nlen and 0xff).toByte()) + message
    }

    private fun currentNdefMessage(): ByteArray {
        cachedNdef?.let { return it }
        val b64 = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_NDEF, null) ?: return ByteArray(0)
        return try {
            Base64.decode(b64, Base64.NO_WRAP).also { cachedNdef = it }
        } catch (_: Throwable) {
            ByteArray(0)
        }
    }

    companion object {
        const val PREFS = "alter_hce"
        const val KEY_NDEF = "ndef"

        /** In-process cache of the NDEF message to serve; falls back to prefs. */
        @Volatile
        var cachedNdef: ByteArray? = null

        private val AID_NDEF = byteArrayOf(
            0xD2.toByte(), 0x76, 0x00, 0x00, 0x85.toByte(), 0x01, 0x01,
        )
        private val CC_FILE_ID = byteArrayOf(0xE1.toByte(), 0x03)
        private val NDEF_FILE_ID = byteArrayOf(0xE1.toByte(), 0x04)

        // Capability Container: maps to an NDEF file (E104), read-only, up to
        // 0x0500 bytes; max read/write APDU length 0x00FB.
        private val CAPABILITY_CONTAINER = byteArrayOf(
            0x00, 0x0F, // CCLEN = 15
            0x20, // mapping version 2.0
            0x00, 0xFB.toByte(), // MLe (max bytes read)
            0x00, 0xFB.toByte(), // MLc (max bytes write)
            0x04, 0x06, // NDEF File Control TLV: tag 04, length 06
            0xE1.toByte(), 0x04, // NDEF file id
            0x05, 0x00, // max NDEF file size = 1280
            0x00, // read access granted
            0xFF.toByte(), // write access denied (read-only)
        )

        private val SW_OK = byteArrayOf(0x90.toByte(), 0x00)
        private val SW_FILE_NOT_FOUND = byteArrayOf(0x6A, 0x82.toByte())
        private val SW_ERROR = byteArrayOf(0x6D, 0x00)
    }
}
