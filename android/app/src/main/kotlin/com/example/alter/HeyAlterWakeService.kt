package com.example.alter

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.plugin.common.EventChannel
import java.util.Locale

class HeyAlterWakeService : Service(), RecognitionListener {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var recognizer: SpeechRecognizer? = null
    private var listening = false
    private var running = false
    private var usingOnDeviceRecognizer = false
    private var wakeDetectedThisSession = false
    private var commandHandoffUntilMillis = 0L

    private val restartRunnable = Runnable {
        if (running) startListening()
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }

        if (!hasRecordAudioPermission() || !SpeechRecognizer.isRecognitionAvailable(this)) {
            stopSelf()
            return START_NOT_STICKY
        }

        running = true
        startAsForeground("Listening for \"Hey Alter\"")
        ensureRecognizer()
        startListening()
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        listening = false
        mainHandler.removeCallbacks(restartRunnable)
        recognizer?.cancel()
        recognizer?.destroy()
        recognizer = null
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onReadyForSpeech(params: Bundle?) {
        listening = true
        updateNotification("Listening for \"Hey Alter\"")
    }

    override fun onBeginningOfSpeech() {
        listening = true
    }

    override fun onRmsChanged(rmsdB: Float) = Unit

    override fun onBufferReceived(buffer: ByteArray?) = Unit

    override fun onEndOfSpeech() {
        listening = false
    }

    override fun onError(error: Int) {
        listening = false
        val handoffDelay = commandHandoffUntilMillis - System.currentTimeMillis()
        scheduleRestart(if (handoffDelay > 0) handoffDelay else errorRestartDelay(error))
    }

    override fun onResults(results: Bundle?) {
        listening = false
        val detected = handleRecognitionBundle(results)
        scheduleRestart(if (detected) COMMAND_HANDOFF_DELAY_MS else IDLE_RESTART_DELAY_MS)
    }

    override fun onPartialResults(partialResults: Bundle?) {
        handleRecognitionBundle(partialResults)
    }

    override fun onEvent(eventType: Int, params: Bundle?) = Unit

    private fun ensureRecognizer() {
        if (recognizer != null) return

        recognizer = createSpeechRecognizer().also {
            it?.setRecognitionListener(this)
        }
    }

    private fun createSpeechRecognizer(): SpeechRecognizer? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                if (SpeechRecognizer.isOnDeviceRecognitionAvailable(this)) {
                    usingOnDeviceRecognizer = true
                    return SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                }
            } catch (_: Throwable) {
                usingOnDeviceRecognizer = false
            }
        }

        usingOnDeviceRecognizer = false
        return SpeechRecognizer.createSpeechRecognizer(this)
    }

    private fun startListening() {
        if (!running || listening) return
        val handoffDelay = commandHandoffUntilMillis - System.currentTimeMillis()
        if (handoffDelay > 0) {
            scheduleRestart(handoffDelay)
            return
        }

        mainHandler.removeCallbacks(restartRunnable)
        ensureRecognizer()
        wakeDetectedThisSession = false

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(
                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
            )
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 4)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, packageName)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
        }

        try {
            recognizer?.startListening(intent)
            listening = true
        } catch (_: RuntimeException) {
            listening = false
            scheduleRestart(ERROR_RESTART_DELAY_MS)
        }
    }

    private fun handleRecognitionBundle(bundle: Bundle?): Boolean {
        val matches = bundle
            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
            .orEmpty()

        for (phrase in matches) {
            if (matchesWakePhrase(phrase)) {
                onWakeDetected(phrase)
                return true
            }
        }

        return false
    }

    private fun matchesWakePhrase(rawPhrase: String): Boolean {
        val normalized = rawPhrase
            .lowercase(Locale.US)
            .replace(Regex("[^a-z0-9 ]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()

        if (normalized.isEmpty()) return false

        // Rigid: require a "hey/ok"-like lead word IMMEDIATELY followed by an
        // "alter"-like name. A bare "alter"-ish word on its own no longer wakes
        // ALTER, which is what caused stray/false triggers. The pair may appear
        // anywhere in the phrase (the recognizer often prepends noise).
        val tokens = normalized.split(" ")
        for (i in 1 until tokens.size) {
            if (WAKE_NAME.contains(tokens[i]) && WAKE_LEAD.contains(tokens[i - 1])) {
                return true
            }
        }

        // Keep the exact-phrase list as a fast path / safety net.
        return WAKE_PHRASES.any { phrase ->
            normalized == phrase ||
                normalized.startsWith("$phrase ") ||
                normalized.contains(" $phrase ") ||
                normalized.endsWith(" $phrase")
        }
    }

    private fun onWakeDetected(phrase: String) {
        if (wakeDetectedThisSession) return
        wakeDetectedThisSession = true
        commandHandoffUntilMillis = System.currentTimeMillis() + COMMAND_HANDOFF_DELAY_MS
        recognizer?.cancel()
        listening = false
        updateNotification("Heard \"Hey Alter\" - tap to speak")

        val event = mapOf(
            "phrase" to phrase,
            "detectedAtMillis" to System.currentTimeMillis(),
            "source" to "android_speech_recognizer",
            "onDevice" to usingOnDeviceRecognizer,
        )
        HeyAlterWakeEvents.emit(event)
    }

    private fun scheduleRestart(delayMs: Long) {
        if (!running) return
        listening = false
        mainHandler.removeCallbacks(restartRunnable)
        mainHandler.postDelayed(restartRunnable, delayMs)
    }

    private fun errorRestartDelay(error: Int): Long {
        return when (error) {
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> ERROR_RESTART_DELAY_MS
            SpeechRecognizer.ERROR_NO_MATCH,
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> IDLE_RESTART_DELAY_MS
            else -> ERROR_RESTART_DELAY_MS
        }
    }

    private fun startAsForeground(content: String) {
        val notification = buildNotification(content)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun updateNotification(content: String) {
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(content))
    }

    private fun buildNotification(content: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        launchIntent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutableFlag()
        val contentIntent = PendingIntent.getActivity(this, 0, launchIntent, flags)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Hey Alter")
            .setContentText(content)
            .setContentIntent(contentIntent)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Hey Alter wake service",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Keeps the local Hey Alter microphone service running."
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun immutableFlag(): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_IMMUTABLE
        } else {
            0
        }
    }

    private fun hasRecordAudioPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
            checkSelfPermission(Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val ACTION_START = "com.example.alter.action.START_WAKE_SERVICE"
        const val ACTION_STOP = "com.example.alter.action.STOP_WAKE_SERVICE"

        private const val CHANNEL_ID = "hey_alter_wake_service"
        private const val NOTIFICATION_ID = 4207
        private const val IDLE_RESTART_DELAY_MS = 700L
        private const val ERROR_RESTART_DELAY_MS = 1500L
        private const val COMMAND_HANDOFF_DELAY_MS = 18000L

        private val WAKE_PHRASES = listOf(
            "hey alter",
            "ok alter",
            "okay alter",
            "hi alter",
        )

        // Phonetic tolerance: the on-device recognizer occasionally mishears
        // "alter". Keep only CLOSE sound-alikes so the wake stays rigid and
        // doesn't false-fire on unrelated words.
        private val WAKE_LEAD = setOf(
            "hey", "hay", "ok", "okay", "okey", "hi", "hello",
        )
        private val WAKE_NAME = setOf(
            "alter", "halter", "altar", "walter", "alta",
        )
    }
}

object HeyAlterWakeEvents {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var lastEvent: Map<String, Any?>? = null

    fun attach(eventSink: EventChannel.EventSink?) {
        sink = eventSink
        lastEvent?.let { event ->
            mainHandler.post {
                sink?.success(event)
            }
        }
    }

    fun detach() {
        sink = null
    }

    fun emit(event: Map<String, Any?>) {
        lastEvent = event
        mainHandler.post {
            sink?.success(event)
        }
    }
}
