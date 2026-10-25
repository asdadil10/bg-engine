/*
 * NerveCenter — headless regression tests for the effect-stack config dialog.
 *
 * Run with:
 *   QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/tst_config_effects.qml
 *
 * These tests drive the real `config.qml` component and simulate Plasma's
 * KConfigXT load/apply cycle, so they cover the dialog half of the
 * persistence contract without opening the Plasma settings window.
 */

import QtQuick
import QtTest

TestCase {
    id: tc
    name: "ConfigEffectStack"
    when: windowShown

    readonly property string configQml: Qt.resolvedUrl("../nervecenter/contents/ui/config.qml")

    property var cfg: null

    function collectSwitches(item, out) {
        if (!item) return
        var kids = item.children
        for (var i = 0; i < kids.length; i++) {
            var c = kids[i]
            if (typeof c.checked === "boolean" && typeof c.text === "string")
                out.push(c)
            collectSwitches(c, out)
        }
        if (item.contentItem && item.contentItem !== item)
            collectSwitches(item.contentItem, out)
    }

    function findSwitch(keyword) {
        var all = []
        collectSwitches(cfg, all)
        for (var i = 0; i < all.length; i++) {
            if (all[i].text.indexOf(keyword) >= 0)
                return all[i]
        }
        return null
    }

    // Simulates a real user click on a QQC2.Switch: the control flips
    // `checked` first, then emits `clicked`, which is what config.qml binds.
    function clickSwitch(keyword) {
        var sw = findSwitch(keyword)
        verify(sw !== null, "switch not found: " + keyword)
        sw.checked = !sw.checked
        sw.clicked()
        return sw
    }

    function initTestCase() {
        var comp = Qt.createComponent(configQml)
        verify(comp.status === Component.Ready,
               "config.qml failed to load: " + comp.errorString())
        cfg = comp.createObject(tc, { width: 900, height: 1400 })
        verify(cfg !== null, "config.qml failed to instantiate")
    }

    function cleanupTestCase() {
        if (cfg) cfg.destroy()
    }

    function test_01_initialEmpty() {
        compare(cfg.cfg_EffectsStackJson, "[]")
        compare(cfg.effectsOrder.length, 0)
        verify(!cfg.cfg_EffectPrismBlur)
        verify(!cfg.cfg_EffectLidarSobel)
    }

    // Plasma loads KConfig values: booleans first, EffectsStackJson last.
    function test_02_loadFromConfigPreservesOrder() {
        cfg.cfg_EffectPrismBlur = true
        cfg.cfg_EffectHologram = true
        cfg.cfg_EffectsStackJson = '["vignette","hologram","prism_blur"]'

        compare(cfg.effectsOrder.length, 3)
        compare(cfg.effectsOrder[0], "vignette")
        compare(cfg.effectsOrder[1], "hologram")
        compare(cfg.effectsOrder[2], "prism_blur")

        verify(cfg.cfg_EffectVignette)
        verify(cfg.cfg_EffectHologram)
        verify(cfg.cfg_EffectPrismBlur)
        verify(!cfg.cfg_EffectLidarSobel)
        verify(!cfg.cfg_EffectDuotone)
    }

    // Real click on LiDAR: appended last, alias true.
    function test_03_clickEnableAppends() {
        var sw = clickSwitch("Pre-filtered anti-aliased")
        verify(sw.checked)
        compare(cfg.cfg_EffectsStackJson,
                '["vignette","hologram","prism_blur","lidar_sobel"]')
        verify(cfg.cfg_EffectLidarSobel)
    }

    // Clicking an enabled effect off removes it, order of the rest intact.
    function test_04_clickDisableRemovesKeepsOrder() {
        var sw = clickSwitch("Luminous neon gradient")
        verify(!sw.checked)
        compare(cfg.cfg_EffectsStackJson,
                '["vignette","prism_blur","lidar_sobel"]')
        verify(!cfg.cfg_EffectHologram)
        verify(cfg.cfg_EffectVignette)
        verify(cfg.cfg_EffectPrismBlur)
    }

    // Re-enabling puts it last, i.e. newest activation layer on top.
    function test_05_reenableGoesLast() {
        clickSwitch("Luminous neon gradient")
        compare(cfg.cfg_EffectsStackJson,
                '["vignette","prism_blur","lidar_sobel","hologram"]')
        compare(cfg.effectsOrder[cfg.effectsOrder.length - 1], "hologram")
    }

    // Apply then reopen: the serialized value must load back identically.
    function test_06_applyReopenRoundTrip() {
        var applied = cfg.cfg_EffectsStackJson
        var appliedOrder = cfg.effectsOrder.slice()

        var comp2 = Qt.createComponent(configQml)
        verify(comp2.status === Component.Ready)
        var cfg2 = comp2.createObject(tc, { width: 900, height: 1400 })
        verify(cfg2 !== null)

        cfg2.cfg_EffectsStackJson = applied
        compare(cfg2.cfg_EffectsStackJson, applied)
        compare(cfg2.effectsOrder.length, appliedOrder.length)
        for (var i = 0; i < appliedOrder.length; i++) {
            compare(cfg2.effectsOrder[i], appliedOrder[i])
        }
        verify(cfg2.cfg_EffectVignette)
        verify(cfg2.cfg_EffectPrismBlur)
        verify(cfg2.cfg_EffectLidarSobel)
        verify(cfg2.cfg_EffectHologram)

        cfg2.destroy()
    }

    // Click every one of the 11 switches; each must reach the stack.
    function test_07_allElevenEffects() {
        var keywords = [
            "Optical chromatic", "Contour-detecting 16-glyph", "Luminous neon",
            "Top and bottom dark", "Deterministic PCB", "Static 2px",
            "Pre-filtered anti-aliased", "FLIR Ironbow", "Pixel-space",
            "3-stop theme", "8-tap Poisson"
        ]
        var keys = ["prism_blur", "ascii", "hologram", "vignette", "circuit",
                    "scanlines", "lidar_sobel", "thermal_flir", "halftone",
                    "duotone", "dither_frost"]
        var cfgKeys = ["cfg_EffectPrismBlur", "cfg_EffectAscii", "cfg_EffectHologram",
                       "cfg_EffectVignette", "cfg_EffectCircuit", "cfg_EffectScanlines",
                       "cfg_EffectLidarSobel", "cfg_EffectThermalFlir", "cfg_EffectHalftone",
                       "cfg_EffectDuotone", "cfg_EffectDitherFrost"]

        // Reset to empty through the UI.
        cfg.cfg_EffectsStackJson = "[]"

        for (var i = 0; i < keywords.length; i++) {
            var sw = findSwitch(keywords[i])
            verify(sw !== null, "missing switch: " + keywords[i])
            if (!sw.checked) {
                sw.checked = true
                sw.clicked()
            }
            compare(cfg[cfgKeys[i]], true, cfgKeys[i] + " should be true")
            compare(cfg.effectsOrder.indexOf(keys[i]), i,
                    keys[i] + " should be at activation position " + i)
        }
        compare(cfg.effectsOrder.length, 11)

        // Read-back as Plasma Apply would: every boolean matches the stack.
        var parsed = JSON.parse(cfg.cfg_EffectsStackJson)
        compare(parsed.length, 11)
        for (var k = 0; k < cfgKeys.length; k++) {
            compare(cfg[cfgKeys[k]], parsed.indexOf(keys[k]) >= 0,
                    cfgKeys[k] + " disagrees with stack")
        }
    }

    // Malformed JSON must not crash and must normalize to "[]".
    function test_08_invalidJsonNormalizes() {
        cfg.cfg_EffectsStackJson = "not valid json"
        compare(cfg.cfg_EffectsStackJson, "[]")
        compare(cfg.effectsOrder.length, 0)
        verify(!cfg.cfg_EffectPrismBlur)
        verify(!cfg.cfg_EffectHologram)
    }

    // A non-array JSON value is also rejected.
    function test_09_nonArrayJsonRejected() {
        cfg.cfg_EffectsStackJson = '{"hologram":true}'
        compare(cfg.cfg_EffectsStackJson, "[]")
        compare(cfg.effectsOrder.length, 0)
    }
}
