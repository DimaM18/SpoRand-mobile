package dev.brandtbd.sporand_native

import android.os.SystemClock

/**
 * The device input clock (brief §5 "Clocks"): `SystemClock.uptimeMillis()`
 * is the base of `MotionEvent.getEventTime()`, which the Flutter engine
 * forwards as `PointerEvent.timeStamp`. Precision is 1 ms.
 */
class InputClockHost : InputClockApi {
    override fun nowMicros(): Long = SystemClock.uptimeMillis() * 1000L
}
