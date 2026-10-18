package au.mollaworkshop.continuum_dex

import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.Uri
import io.flutter.FlutterInjector
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // LCARS beeps (lib/ui/sound.dart): each bundled WAV is copied out of the APK
    // once, loaded into a SoundPool, and played from there.
    private val sounds: SoundPool by lazy {
        SoundPool.Builder()
            .setMaxStreams(4)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .build()
    }
    private val loaded = mutableMapOf<String, Int>()
    private val ready = mutableSetOf<Int>()
    private val playWhenReady = mutableSetOf<Int>()

    private fun soundId(name: String): Int? {
        if (!name.matches(Regex("[a-z0-9_]+"))) return null
        loaded[name]?.let { return it }
        val key = FlutterInjector.instance().flutterLoader()
            .getLookupKeyForAsset("assets/sounds/$name.wav")
        val file = File(cacheDir, "sound_$name.wav")
        if (!file.exists()) {
            assets.open(key).use { input -> file.outputStream().use { input.copyTo(it) } }
        }
        val id = sounds.load(file.path, 1)
        loaded[name] = id
        return id
    }

    // Opens canon links in the browser (lib/ui/open_link.dart). Only https links
    // are accepted; they all come from the Dex's own data.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sounds.setOnLoadCompleteListener { pool, id, status ->
            if (status == 0) {
                ready.add(id)
                if (playWhenReady.remove(id)) pool.play(id, 1f, 1f, 1, 0, 1f)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "continuum_dex/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "filesDir" -> result.success(filesDir.path)
                    "play" -> {
                        try {
                            val id = soundId(call.arguments as? String ?: "")
                            if (id != null) {
                                if (id in ready) sounds.play(id, 1f, 1f, 1, 0, 1f) else playWhenReady.add(id)
                            }
                        } catch (e: Exception) {
                            // A missing beep never stops a button working.
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "continuum_dex/links")
            .setMethodCallHandler { call, result ->
                if (call.method != "open") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val url = call.arguments as? String
                if (url == null || !url.startsWith("https://")) {
                    result.success(false)
                    return@setMethodCallHandler
                }
                try {
                    startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    result.success(true)
                } catch (e: ActivityNotFoundException) {
                    result.success(false)
                }
            }
    }
}
