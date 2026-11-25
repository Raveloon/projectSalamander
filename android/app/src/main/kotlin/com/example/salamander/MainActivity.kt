package com.example.salamander

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.ar.core.Session
import com.google.ar.core.Config
import com.google.ar.core.TrackingState
import com.google.ar.core.Plane
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.salamander/ar_geospatial"
    private var session: Session? = null
    private val anchors = mutableMapOf<String, com.google.ar.core.Anchor>()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableGeospatial" -> {
                    val success = enableGeospatialMode(flutterEngine)
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("UNAVAILABLE", "Geospatial mode not available", null)
                    }
                }
                "checkVpsStatus" -> {
                    val status = checkVpsStatus(flutterEngine)
                    result.success(status)
                }
                "createGeospatialAnchor" -> {
                    val lat = call.argument<Double>("latitude")
                    val lon = call.argument<Double>("longitude")
                    val alt = call.argument<Double>("altitude")
                    if (lat != null && lon != null && alt != null) {
                        val anchorId = createGeospatialAnchor(lat, lon, alt, flutterEngine)
                        if (anchorId != null) {
                            result.success(anchorId)
                        } else {
                            result.error("FAILED", "Failed to create anchor", null)
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "Missing coordinates", null)
                    }
                }
                "getMappingProgress" -> {
                    if (session == null) {
                        session = getSessionViaReflection(flutterEngine)
                    }
                    val planes = session?.getAllTrackables(Plane::class.java)
                    val count = planes?.size ?: 0
                    result.success(count)
                }
                "checkVisualMatch" -> {
                    if (session == null) {
                        session = getSessionViaReflection(flutterEngine)
                    }
                    val earth = session?.earth
                    if (earth != null && earth.trackingState == TrackingState.TRACKING) {
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun getSessionViaReflection(flutterEngine: FlutterEngine): Session? {
        try {
            val pluginClass = Class.forName("io.carius.lars.ar_flutter_plugin.ArFlutterPlugin") as Class<out io.flutter.embedding.engine.plugins.FlutterPlugin>
            val plugin = flutterEngine.plugins.get(pluginClass) ?: return null
            
            val session = findSession(plugin)
            if (session != null) return session
            
            for (field in pluginClass.declaredFields) {
                field.isAccessible = true
                val value = field.get(plugin) ?: continue
                val s = findSession(value)
                if (s != null) return s
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
        return null
    }

    private fun findSession(obj: Any): Session? {
        val clazz = obj.javaClass
        for (field in clazz.declaredFields) {
            if (field.type == Session::class.java) {
                field.isAccessible = true
                return field.get(obj) as? Session
            }
        }
        return null
    }

    private fun enableGeospatialMode(flutterEngine: FlutterEngine): Boolean {
        if (session == null) {
            session = getSessionViaReflection(flutterEngine)
        }
        if (session == null) {
            return false
        }
        if (!session!!.isGeospatialModeSupported(Config.GeospatialMode.ENABLED)) {
            return false
        }
        val config = session!!.config
        config.geospatialMode = Config.GeospatialMode.ENABLED
        session!!.configure(config)
        return true
    }

    private fun checkVpsStatus(flutterEngine: FlutterEngine): Map<String, Any>? {
        if (session == null) {
            session = getSessionViaReflection(flutterEngine)
        }
        if (session == null) return null
        val earth = session!!.earth ?: return null
        val status = mutableMapOf<String, Any>()
        status["supported"] = session!!.isGeospatialModeSupported(Config.GeospatialMode.ENABLED)
        status["trackingState"] = earth.trackingState.toString()
        if (earth.trackingState == TrackingState.TRACKING) {
            val pose = earth.cameraGeospatialPose
            status["latitude"] = pose.latitude
            status["longitude"] = pose.longitude
            status["altitude"] = pose.altitude
            status["heading"] = pose.heading
        }
        return status
    }

    private fun createGeospatialAnchor(lat: Double, lon: Double, alt: Double, flutterEngine: FlutterEngine): String? {
        if (session == null) {
            session = getSessionViaReflection(flutterEngine)
        }
        if (session == null) return null
        val earth = session!!.earth ?: return null
        if (earth.trackingState != TrackingState.TRACKING) return null
        
        val anchor = earth.createAnchor(lat, lon, alt, 0.0f, 0.0f, 0.0f, 1.0f)
        val id = UUID.randomUUID().toString()
        anchors[id] = anchor
        return id
    }
}
