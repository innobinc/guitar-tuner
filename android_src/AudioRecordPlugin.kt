package com.guitartuner.guitar_tuner

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import kotlin.concurrent.thread

class AudioRecordPlugin : FlutterPlugin, EventChannel.StreamHandler {
    private val CHANNEL_NAME = "com.guitartuner.guitar_tuner/audio"
    private var eventChannel: EventChannel? = null
    private var audioRecord: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false

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
        val sampleRate = 44100
        val minBuf = AudioRecord.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = maxOf(minBuf * 4, 8192)

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            bufSize
        )

        if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
            events?.error("INIT_ERROR", "AudioRecord init failed", null)
            return
        }

        audioRecord?.startRecording()
        isRecording = true

        recordingThread = thread(name = "AudioCapture") {
            val buffer = ByteArray(bufSize)
            while (isRecording) {
                val read = audioRecord?.read(buffer, 0, bufSize) ?: -1
                if (read > 0) {
                    events?.success(buffer.copyOf(read))
                }
            }
        }
    }

    override fun onCancel(arguments: Any?) = stopRecording()

    private fun stopRecording() {
        isRecording = false
        recordingThread?.join(200)
        recordingThread = null
        audioRecord?.stop()
        audioRecord?.release()
        audioRecord = null
    }
}
