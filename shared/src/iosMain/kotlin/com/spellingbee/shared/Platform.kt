package com.spellingbee.shared

import platform.Foundation.NSDate
import platform.Foundation.NSUUID
import platform.posix.time
import kotlinx.cinterop.ExperimentalForeignApi

actual fun generateUUID(): String {
    return NSUUID().UUIDString
}

@OptIn(ExperimentalForeignApi::class)
actual fun getCurrentTimestamp(): Long {
    return time(null) * 1000L
}