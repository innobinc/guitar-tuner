package com.guitartuner.guitar_tuner

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import kotlin.concurrent.thread

class AudioRecordPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private val CHANNEL_NAME = "com.guitartuner.guitar_tuner/audio"
    private var eventChannel: EventChannel? = null
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        eventChannel = EventChannel(binding.binaryMessenger, CHANNEL_NAME)
        eventChannel?.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopRecording()
        eventChannel?.setStreamHandler(null)
        eventChannel = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        try {
            val sampleRate = 44100
            val minBuf = AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            if (minBuf <= 0) {
                mainHandler.post { events?.error("BUFFER_ERROR", "Invalid buffer size: $minBuf", null) }
                return
            }
            val bufSize = maxOf(minBuf * 4, 8192)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                mainHandler.post { events?.error("INIT_ERROR", "AudioRecord not initialized", null) }
                return
            }

            audioRecord?.startRecording()
            isRecording = true

            recordingThread = thread(name = "AudioCapture") {
                val buffer = ByteArray(bufSize)
                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, bufSize) ?: -1
                    if (read > 0) {
                        val data = buffer.copyOf(read)
                        // Must post to main thread for Flutter EventSink
                        mainHandler.post { events?.success(data) }
                    }
                }
            }
        } catch (e: SecurityException) {
            mainHandler.post { events?.error("PERMISSION_ERROR", "Microphone permission denied: ${e.message}", null) }
        } catch (e: Exception) {
            mainHandler.post { events?.error("UNKNOWN_ERROR", e.message, null) }
        }
    }

    override fun onCancel(arguments: Any?) = stopRecording()

    private fun stopRecording() {
        isRecording = false
        recordingThread?.join(300)
        recordingThread = null
        try {
            audioRecord?.stop()
            audioRecord?.release()
        } catch (_: Exception) {}
        audioRecord = null
    }
}
