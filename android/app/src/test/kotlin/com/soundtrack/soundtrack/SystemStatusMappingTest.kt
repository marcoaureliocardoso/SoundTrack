package com.soundtrack.soundtrack

import android.app.NotificationManager
import android.media.AudioDeviceInfo
import android.os.BatteryManager
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SystemStatusMappingTest {
    @Test
    fun `battery percentage rounds down and recognizes charging states`() {
        assertEquals(
            BatteryChannelStatus(percent = 76, charging = true),
            mapBatteryStatus(level = 153, scale = 200, status = BatteryManager.BATTERY_STATUS_CHARGING),
        )
        assertEquals(
            BatteryChannelStatus(percent = 50, charging = true),
            mapBatteryStatus(level = 1, scale = 2, status = BatteryManager.BATTERY_STATUS_FULL),
        )
        assertFalse(
            mapBatteryStatus(
                level = 50,
                scale = 100,
                status = BatteryManager.BATTERY_STATUS_DISCHARGING,
            ).charging,
        )
    }

    @Test
    fun `battery preserves unknown percentage safely`() {
        assertNull(mapBatteryStatus(level = -1, scale = 100, status = 0).percent)
        assertNull(mapBatteryStatus(level = 20, scale = 0, status = 0).percent)
        assertFalse(mapBatteryStatus(level = 20, scale = 100, status = 0).charging)
    }

    @Test
    fun `output route prioritizes bluetooth then wired USB and speaker`() {
        assertEquals(
            "Bluetooth",
            mapOutputRouteLabel(
                listOf(
                    AudioDeviceInfo.TYPE_BUILTIN_SPEAKER,
                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_HEARING_AID,
                ),
            ),
        )
        assertEquals(
            "Fone com fio",
            mapOutputRouteLabel(
                listOf(AudioDeviceInfo.TYPE_USB_DEVICE, AudioDeviceInfo.TYPE_WIRED_HEADSET),
            ),
        )
        assertEquals(
            "USB",
            mapOutputRouteLabel(
                listOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER, AudioDeviceInfo.TYPE_USB_ACCESSORY),
            ),
        )
        assertEquals(
            "Alto-falante",
            mapOutputRouteLabel(listOf(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER)),
        )
    }

    @Test
    fun `output route covers supported bluetooth wired USB and fallback types`() {
        val bluetoothTypes =
            listOf(
                AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                AudioDeviceInfo.TYPE_BLE_HEADSET,
                AudioDeviceInfo.TYPE_BLE_SPEAKER,
                AudioDeviceInfo.TYPE_BLE_BROADCAST,
                AudioDeviceInfo.TYPE_HEARING_AID,
            )
        val wiredTypes =
            listOf(
                AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                AudioDeviceInfo.TYPE_WIRED_HEADSET,
                AudioDeviceInfo.TYPE_LINE_ANALOG,
                AudioDeviceInfo.TYPE_LINE_DIGITAL,
                AudioDeviceInfo.TYPE_AUX_LINE,
            )
        val usbTypes =
            listOf(
                AudioDeviceInfo.TYPE_USB_ACCESSORY,
                AudioDeviceInfo.TYPE_USB_DEVICE,
                AudioDeviceInfo.TYPE_USB_HEADSET,
            )

        bluetoothTypes.forEach { assertEquals("Bluetooth", mapOutputRouteLabel(listOf(it))) }
        wiredTypes.forEach { assertEquals("Fone com fio", mapOutputRouteLabel(listOf(it))) }
        usbTypes.forEach { assertEquals("USB", mapOutputRouteLabel(listOf(it))) }
        assertEquals("Saída de áudio", mapOutputRouteLabel(emptyList()))
        assertEquals("Saída de áudio", mapOutputRouteLabel(listOf(AudioDeviceInfo.TYPE_HDMI)))
    }

    @Test
    fun `do not disturb is unavailable without policy access`() {
        assertNull(mapDoNotDisturb(policyAccessGranted = false, interruptionFilter = 999))
    }

    @Test
    fun `do not disturb does not read filter without policy access`() {
        var reads = 0

        val enabled =
            readDoNotDisturb(policyAccessGranted = false) {
                reads += 1
                NotificationManager.INTERRUPTION_FILTER_NONE
            }

        assertNull(enabled)
        assertEquals(0, reads)
    }

    @Test
    fun `do not disturb maps known filters and preserves unknown`() {
        assertFalse(
            mapDoNotDisturb(
                policyAccessGranted = true,
                interruptionFilter = NotificationManager.INTERRUPTION_FILTER_ALL,
            )!!,
        )
        assertTrue(
            mapDoNotDisturb(
                policyAccessGranted = true,
                interruptionFilter = NotificationManager.INTERRUPTION_FILTER_PRIORITY,
            )!!,
        )
        assertTrue(
            mapDoNotDisturb(
                policyAccessGranted = true,
                interruptionFilter = NotificationManager.INTERRUPTION_FILTER_NONE,
            )!!,
        )
        assertTrue(
            mapDoNotDisturb(
                policyAccessGranted = true,
                interruptionFilter = NotificationManager.INTERRUPTION_FILTER_ALARMS,
            )!!,
        )
        assertNull(
            mapDoNotDisturb(
                policyAccessGranted = true,
                interruptionFilter = NotificationManager.INTERRUPTION_FILTER_UNKNOWN,
            ),
        )
    }
}
