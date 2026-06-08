package com.guitartuner.guitar_tuner

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    @Volatile private var capturing = false
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, "com.guitartuner.guitar_tuner/audio")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    startCapture(events)
                }
                override fun onCancel(arguments: Any?) {
                    stopCapture()
                }
            })
    }

    private fun startCapture(sink: EventChannel.EventSink?) {
        stopCapture()
        try {
            val rate = 44100
            val minBuf = AudioRecord.getMinBufferSize(
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )
            val bufSize = maxOf(minBuf * 2, 8192)

            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                rate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT,
                bufSize
            )

            if (audioRecord!!.state != AudioRecord.STATE_INITIALIZED) {
                mainHandler.post { sink?.error("INIT_ERROR", "AudioRecord failed to initialize", null) }
                return
            }

            audioRecord!!.startRecording()
            capturing = true

            captureThread = thread(name = "AudioCapture") {
                val buf = ByteArray(bufSize)
                while (capturing) {
                    val n = audioRecord?.read(buf, 0, bufSize) ?: break
                    if (n > 0) {
                        val copy = buf.copyOf(n)
                        mainHandler.post { sink?.success(copy) }
                    }
                }
            }
        } catch (e: SecurityException) {
            mainHandler.post { sink?.error("PERMISSION", "Mic permission denied: ${e.message}", null) }
        } catch (e: Exception) {
            mainHandler.post { sink?.error("ERROR", e.message, null) }
        }
    }

    private fun stopCapture() {
        capturing = false
        captureThread?.join(500)
        captureThread = null
        try { audioRecord?.stop() } catch (_: Exception) {}
        try { audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
    }

    override fun onDestroy() {
        stopCapture()
        super.onDestroy()
    }
}
