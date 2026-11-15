package com.hader.app

import android.annotation.SuppressLint
import android.content.Context
import android.location.LocationManager
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.model.IntegrityTokenRequest
import org.json.JSONArray

/**
 * حاضر — النشاط الرئيسي + القنوات الأصلية الثلاث (الجزء 3.4/3.6/4.1)
 *
 *  القناة "hader/native" بثلاث طرق:
 *   scanBssids      : قائمة BSSID+RSSI للشبكات في الهواء (بصمة المكان — بلا الحاجة
 *                     للاتصال بأي شبكة). يتطلب إذن الموقع الدقيق (يطلبه التطبيق أولًا).
 *   requestIntegrity: شهادة Play Integrity (كشف الروت والمحاكيات والتطبيقات المعدلة).
 *   isMockLocationOn: فحص خيارات المطورين وبرامج الموقع الوهمي.
 *
 *  مبادئ الخصوصية (الجزء 6 من المستند): لا يوجد أي كود يقرأ المعرض أو جهات
 *  الاتصال أو الميكروفون؛ المسح يحدث لحظة التسجيل فقط.
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "hader/native"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scanBssids" -> {
                    try {
                        result.success(scanBssids())
                    } catch (e: SecurityException) {
                        result.error("permission", "إذن الموقع مطلوب لمسح الشبكات", null)
                    } catch (e: Exception) {
                        result.error("scan_failed", e.message, null)
                    }
                }
                "requestIntegrity" -> {
                    requestIntegrity(call.argument<String>("nonce") ?: "", result)
                }
                "isMockLocationOn" -> {
                    result.success(isMockLocationOn())
                }
                "elapsedRealtime" -> {
                    // ساعة الرتابة (SystemClock.elapsedRealtime) — أساس العدل الزمني
                    // للتسجيلات الأوفلاين: لا تتأثر بتغيير المستخدم لساعة الهاتف
                    result.success(android.os.SystemClock.elapsedRealtime().toLong())
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * مسح نقاط الوصول في الهواء: [{"bssid":"A4:2B:..","rssi":-58}, ...]
     * النظام لا ينظر لأسماء الشبكات (SSID) إطلاقًا — العنوان الفيزيائي فقط (BSSID)
     * لأن الاسم يُقلَّد بسهولة بنقطة اتصال منزلية (الجزء 3.6 قاعدة 1-2).
     */
    @SuppressLint("MissingPermission") // التطبيق يطلب إذن الموقع قبل الاستدعاء
    private fun scanBssids(): String {
        val wifi = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        @Suppress("DEPRECATION") // scanResults ما زالت الطريقة القياسية لمسح الهواء
        val results = wifi.scanResults ?: emptyList()
        val arr = JSONArray()
        for (r in results) {
            if (r.bssid.isNullOrEmpty()) continue
            val o = org.json.JSONObject()
            o.put("bssid", r.bssid.uppercase())
            o.put("rssi", r.level)
            arr.put(o)
        }
        return arr.toString()
    }

    /**
     * Play Integrity API — الطلب بـ nonce مربوط بالجلسة يمنع إعادة التشغيل.
     * تُرسل الشهادة الخام إلى complete-activation / register-capture للتحقق على السيرفر.
     */
    private fun requestIntegrity(nonce: String, result: MethodChannel.Result) {
        try {
            val manager = IntegrityManagerFactory.create(applicationContext)
            val request = IntegrityTokenRequest.builder()
                .setNonce(nonce)
                .build()
            manager.requestIntegrityToken(request)
                .addOnSuccessListener { response ->
                    result.success(response.token())
                }
                .addOnFailureListener { e ->
                    // فشل الشهادة ليس فشل تسجيلًا — يُسجل verdict بلا شهادة وتراجعه الإدارة
                    result.error("integrity_failed", e.message, null)
                }
        } catch (e: Exception) {
            result.error("integrity_unavailable", e.message, null)
        }
    }

    /**
     * كشف الموقع الوهمي: خيار «تحديد الموقع الوهمي» في خيارات المطورين مفعّل،
     * أو أحد مزودي الموقع يعلن isFromMockProvider (أندرويد 12+).
     */
    private fun isMockLocationOn(): Boolean {
        var mockOn = false
        try {
            // (أ) خيار خيارات المطورين الكلاسيكي
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
                @Suppress("DEPRECATION")
                val op = Settings.Secure.getString(
                    contentResolver,
                    Settings.Secure.ALLOW_MOCK_LOCATION
                )
                mockOn = !op.isNullOrEmpty() && op != "0"
            }
            // (ب) علم isMock من مزودي الموقع (API 31+)
            if (!mockOn && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
                for (provider in lm.allProviders) {
                    try {
                        @Suppress("MissingPermission")
                        val last = lm.getLastKnownLocation(provider)
                        if (last != null && last.isMock) {
                            mockOn = true
                            break
                        }
                    } catch (_: SecurityException) {
                        // إذن الموقع لم يُمنح بعد — نتجاهل هذا المزود
                    }
                }
            }
        } catch (_: Exception) {
            // الفشل لا يتهم الموظف — يُعالج كإشارة غائبة وتراجعه الإدارة
        }
        return mockOn
    }
}
