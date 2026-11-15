package com.hader.app.alarms

import android.content.Context

/**
 * جسر إعادة الجدولة بعد الإقلاع — يستدعي رأس التطبيق (headless) لإعادة ضبط
 * منبهات اليوم من الجدول المشفر المحفوظ في flutter_secure_storage.
 * (التنفيذ الكامل داخل Dart: LocalAlarms.rescheduleAfterBoot)
 */
object FlutterBootBridge {
    @Volatile
    var rescheduleCallback: ((Context) -> Unit)? = null

    fun rescheduleAlarms(context: Context) {
        rescheduleCallback?.invoke(context)
    }
}
