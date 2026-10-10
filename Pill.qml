import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// A small pill at the bottom of the focused screen while Voxtype is dictating.
//
//   recording     bars follow your voice, newest level in the middle
//   transcribing  bars ripple softly until the text is typed
//
// Voxtype's daemon state comes from $XDG_RUNTIME_DIR/voxtype/state and the mic
// level from `voxtype-audio-bridge` (ships with voxtype), which only runs while
// the pill is showing. Colours are Omarchy's popup colours, so it matches the
// volume OSD and follows theme changes.
Item {
  id: root

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || ("/run/user/" + Quickshell.env("UID"))

  property string daemonState: "idle"
  property bool suppressed: false
  readonly property bool active: !root.suppressed
    && (root.daemonState === "recording" || root.daemonState === "streaming" || root.daemonState === "transcribing")
  readonly property bool transcribing: root.daemonState === "transcribing"

  readonly property int barCount: 11
  readonly property int barWidth: Style.space(3)
  readonly property int barGap: Style.space(3)
  readonly property int minBar: Style.space(3)
  readonly property int maxBar: Style.space(16)

  // Latest mic level (0..1, dB-scaled), the recent levels that flow out from
  // the centre, and the eased bar heights.
  property real level: 0
  property var history: []
  property var heights: []
  property real phase: 0

  // -55 dBFS (room noise) .. -10 dBFS (loud speech) -> 0..1
  function toLevel(peak) {
    if (peak <= 0) return 0
    return Math.max(0, Math.min(1, (20 * Math.log10(peak) + 55) / 45))
  }

  function reset() {
    var h = [], hist = []
    for (var i = 0; i < root.barCount; i++) h.push(root.minBar)
    for (var j = 0; j < Math.ceil(root.barCount / 2); j++) hist.push(0)
    root.level = 0
    root.heights = h
    root.history = hist
  }

  Component.onCompleted: reset()
  onActiveChanged: if (!active) reset()

  FileView {
    path: root.runtimeDir + "/voxtype/state"
    watchChanges: true
    printErrors: false
    onLoaded: root.daemonState = (text() || "idle").trim()
    onLoadFailed: root.daemonState = "idle"
    onFileChanged: reload()
  }

  // Set by `voxtype record start --no-osd`, for tools that draw their own UI.
  FileView {
    path: root.runtimeDir + "/voxtype/osd_suppressed"
    watchChanges: true
    printErrors: false
    onLoaded: root.suppressed = true
    onLoadFailed: root.suppressed = false
    onFileChanged: reload()
  }

  Process {
    command: ["voxtype-audio-bridge"]
    running: root.active
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: function(line) {
        var frame
        try { frame = JSON.parse(line) } catch (e) { return }
        if (typeof frame.peak !== "number") return
        var l = root.toLevel(frame.peak)
        // Fast attack, slower release so the bars don't flicker.
        root.level = l > root.level ? l : root.level * 0.85 + l * 0.15
      }
    }
  }

  Timer {
    interval: 16
    repeat: true
    running: root.active
    property int tick: 0
    onTriggered: {
      root.phase += 0.016
      var hist = root.history.slice()
      if (++tick % 3 === 0) {
        hist.unshift(root.level)
        while (hist.length > Math.ceil(root.barCount / 2)) hist.pop()
        root.history = hist
      }
      var centre = (root.barCount - 1) / 2
      var h = root.heights.slice()
      for (var i = 0; i < root.barCount; i++) {
        var d = Math.abs(i - centre)
        var target
        if (root.transcribing) {
          target = root.minBar + (0.5 + 0.5 * Math.sin(root.phase * 7 - i * 0.7)) * Style.space(5)
        } else {
          var v = hist[Math.min(hist.length - 1, Math.round(d))] || 0
          target = root.minBar + v * (1 - (d / (centre + 1)) * 0.45) * (root.maxBar - root.minBar)
        }
        h[i] += (target - h[i]) * 0.35
      }
      root.heights = h
    }
  }

  // Plain PanelWindow (like Omarchy 4.0's own OSD), so it works on released
  // Omarchy too. Mapped only while showing, so it lands on the focused screen.
  PanelWindow {
    visible: root.active
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "kenners22-dictation-pill"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Visual only: never block clicks to the window underneath.
    mask: Region {}

    Rectangle {
      id: pill
      width: root.barCount * root.barWidth + (root.barCount - 1) * root.barGap + Style.space(32)
      height: Style.space(32)
      radius: height / 2
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(28)
      color: Util.alpha(Commons.Color.popups.background, 0.94)
      border.width: 1
      border.color: Util.alpha(Commons.Color.popups.border, 0.35)
      opacity: root.active ? 1 : 0
      scale: root.active ? 1 : 0.85
      Behavior on opacity { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack } }

      Row {
        anchors.centerIn: parent
        spacing: root.barGap
        Repeater {
          model: root.barCount
          delegate: Rectangle {
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            width: root.barWidth
            height: root.heights[index] || root.minBar
            radius: width / 2
            color: Commons.Color.popups.text
            opacity: root.transcribing ? 0.6 : 0.95
            Behavior on opacity { NumberAnimation { duration: 150 } }
          }
        }
      }
    }
  }
}
