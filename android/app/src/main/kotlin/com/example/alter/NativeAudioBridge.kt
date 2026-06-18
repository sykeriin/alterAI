package com.example.alter

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Records microphone audio as 16 kHz mono 16-bit PCM and wraps it in a WAV
 * container. WAV is the format the backend speech stack (Sarvam) reliably
 * accepts — unlike MediaRecorder's AAC/MP4 output — which makes cloud
 * transcription accurate instead of falling back.
 */
object NativeAudioBridge {
    private const val SAMPLE_RATE = 16_000
    private const val CHANNELS = 1

    private var audioRecord: AudioRecord? = null
    private var recordThread: Thread? = null
    @Volatile private var isRecording = false
    private var pcm: ByteArrayOutputStream? = null
    private var recordingStartedAt: Long = 0L
    private var player: MediaPlayer? = null

    fun handle(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startRecording" -> result.success(startRecording(activity))
            "stopRecording" -> result.success(stopRecording())
            "cancelRecording" -> result.success(cancelRecording())
            "playAudioBase64" -> result.success(
                playAudioBase64(
                    activity,
                    call.argument<String>("audioBase64").orEmpty(),
                    call.argument<String>("filename").orEmpty(),
                ),
            )
            "stopPlayback" -> result.success(stopPlayback())
            else -> result.notImplemented()
        }
    }

    private fun startRecording(activity: Activity): Map<String, Any?> {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
            activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return failure("Microphone permission is not granted.")
        }
        if (audioRecord != null || isRecording) {
            return failure("Recording is already active.")
        }

        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
        )
        val bufferSize = if (minBuffer > 0) minBuffer * 2 else SAMPLE_RATE * 2

        return try {
            val record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufferSize,
            )
            if (record.state != AudioRecord.STATE_INITIALIZED) {
                record.release()
                return failure("Could not initialise the microphone.")
            }
            val buffer = ByteArrayOutputStream()
            record.startRecording()
            isRecording = true
            audioRecord = record
            pcm = buffer
            recordingStartedAt = System.currentTimeMillis()
            recordThread = Thread {
                val chunk = ByteArray(bufferSize)
                while (isRecording) {
                    val read = record.read(chunk, 0, chunk.size)
                    if (read > 0) {
                        synchronized(buffer) { buffer.write(chunk, 0, read) }
                    }
                }
            }.also { it.start() }
            success("Recording started.")
        } catch (error: Throwable) {
            isRecording = false
            audioRecord = null
            pcm = null
            failure("Could not start recording: ${error.message}")
        }
    }

    private fun stopRecording(): Map<String, Any?> {
        if (!isRecording && audioRecord == null) {
            return failure("No recording is active.")
        }
        isRecording = false
        try {
            recordThread?.join(800)
        } catch (_: Throwable) {
        }
        recordThread = null

        val record = audioRecord
        val buffer = pcm
        audioRecord = null
        pcm = null
        return try {
            try {
                record?.stop()
            } catch (_: Throwable) {
            }
            record?.release()
            val pcmBytes: ByteArray
            if (buffer != null) {
                synchronized(buffer) { pcmBytes = buffer.toByteArray() }
            } else {
                pcmBytes = ByteArray(0)
            }
            val wav = pcmToWav(pcmBytes)
            mapOf(
                "ok" to true,
                "message" to "Recording captured.",
                "audioBase64" to Base64.encodeToString(wav, Base64.NO_WRAP),
                "filename" to "alter_voice.wav",
                "contentType" to "audio/wav",
                "durationMs" to (System.currentTimeMillis() - recordingStartedAt),
            )
        } catch (error: Throwable) {
            failure("Could not stop recording: ${error.message}")
        }
    }

    private fun cancelRecording(): Map<String, Any?> {
        isRecording = false
        return try {
            try {
                recordThread?.join(300)
            } catch (_: Throwable) {
            }
            recordThread = null
            try {
                audioRecord?.stop()
            } catch (_: Throwable) {
            }
            audioRecord?.release()
            audioRecord = null
            pcm = null
            success("Recording cancelled.")
        } catch (error: Throwable) {
            audioRecord = null
            pcm = null
            failure("Could not cancel recording: ${error.message}")
        }
    }

    /** Wrap raw little-endian PCM 16-bit mono samples in a 44-byte WAV header. */
    private fun pcmToWav(data: ByteArray): ByteArray {
        val bitsPerSample = 16
        val byteRate = SAMPLE_RATE * CHANNELS * bitsPerSample / 8
        val blockAlign = CHANNELS * bitsPerSample / 8
        val out = ByteArrayOutputStream(44 + data.size)

        fun writeString(value: String) = out.write(value.toByteArray(Charsets.US_ASCII))
        fun writeIntLe(value: Int) {
            out.write(value and 0xff)
            out.write((value shr 8) and 0xff)
            out.write((value shr 16) and 0xff)
            out.write((value shr 24) and 0xff)
        }
        fun writeShortLe(value: Int) {
            out.write(value and 0xff)
            out.write((value shr 8) and 0xff)
        }

        writeString("RIFF")
        writeIntLe(36 + data.size)
        writeString("WAVE")
        writeString("fmt ")
        writeIntLe(16)
        writeShortLe(1) // PCM
        writeShortLe(CHANNELS)
        writeIntLe(SAMPLE_RATE)
        writeIntLe(byteRate)
        writeShortLe(blockAlign)
        writeShortLe(bitsPerSample)
        writeString("data")
        writeIntLe(data.size)
        out.write(data)
        return out.toByteArray()
    }

    private fun playAudioBase64(
        activity: Activity,
        audioBase64: String,
        filename: String,
    ): Map<String, Any?> {
        if (audioBase64.isBlank()) {
            return failure("No audio was returned.")
        }
        stopPlayback()
        val extension = filename.substringAfterLast('.', "wav").ifBlank { "wav" }
        val file = File(activity.cacheDir, "alter_tts.$extension")
        return try {
            file.writeBytes(Base64.decode(audioBase64, Base64.DEFAULT))
            player = MediaPlayer().apply {
                setDataSource(file.absolutePath)
                setOnCompletionListener {
                    it.release()
                    if (player == it) player = null
                }
                prepare()
                start()
            }
            success("Playing generated voice.")
        } catch (error: Throwable) {
            failure("Could not play generated voice: ${error.message}")
        }
    }

    private fun stopPlayback(): Map<String, Any?> {
        return try {
            player?.stop()
            player?.release()
            player = null
            success("Audio playback stopped.")
        } catch (error: Throwable) {
            player = null
            failure("Could not stop playback: ${error.message}")
        }
    }

    private fun success(message: String): Map<String, Any?> {
        return mapOf("ok" to true, "message" to message)
    }

    private fun failure(message: String): Map<String, Any?> {
        return mapOf("ok" to false, "message" to message)
    }
}
