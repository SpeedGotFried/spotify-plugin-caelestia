pragma ComponentBehavior: Bound

import ".."
import "../components"
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

// ─────────────────────────────────────────────────────────────────────────────
// SpotifyPane — Caelestia control-centre pane for spotify-plugin-caelestia
// Reads:  ~/.config/caelestia/spotify-plugin.conf  (bash key=value format)
// Writes: same file via sed, then restarts the systemd user service.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    required property Session session

    // ── Config path ────────────────────────────────────────────────
    // Paths.config = XDG_CONFIG_HOME/caelestia  (from qs.utils)
    readonly property string confPath: Paths.config + "/spotify-plugin.conf"
    readonly property string service:  "spotify-wallpaper"

    // ── Live properties (populated by readConfig) ──────────────────
    property int    coverSize:      480
    property int    radius:         30
    property int    blurStrength:   30
    property int    darkenAmount:   35
    property int    titleSize:      40
    property int    artistSize:     26
    property int    maxChars:       28
    property int    verticalOffset: -80
    property int    primaryMonitor: 0
    property int    retryDelay:     5
    property bool   matchScheme:    false
    property string schemeMode:     "dark"
    property string schemeVariant:  "tonalspot"

    // ── State ──────────────────────────────────────────────────────
    property bool loaded: false
    property bool serviceRunning: false

    anchors.fill: parent

    // ─────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────

    function readConfig(): void {
        readProc.running = true;
    }

    // writeKey: runs python3 directly (no shell) to safely rewrite
    // the key=value line, then restarts the service on exit.
    function writeKey(key: string, value: string): void {
        writeProc.command = [
            "python3", "-c",
            "import re,sys;" +
            "k,v,p=sys.argv[1],sys.argv[2],sys.argv[3];" +
            "t=open(p).read();" +
            "t=re.sub(r'(?m)^'+re.escape(k)+r'=.*',k+'='+v,t) if re.search(r'(?m)^'+re.escape(k)+r'=',t) else t+k+'='+v+'\\n';" +
            "open(p,'w').write(t)",
            key, value, root.confPath
        ];
        writeProc.running = true;
    }

    function restartService(): void {
        Quickshell.execDetached(["systemctl", "--user", "restart", root.service]);
    }

    function clearCache(): void {
        Quickshell.execDetached([
            "bash", "-c",
            "rm -f ~/.cache/spotify-plugin-caelestia/wall_*.jpg ~/.cache/spotify-plugin-caelestia/cover_*.jpg"
        ]);
    }

    // ─────────────────────────────────────────────────────────────
    // Processes
    // ─────────────────────────────────────────────────────────────

    Process {
        id: readProc

        property string buf: ""

        running: false
        command: [
            "bash", "-c",
            "source \"" + root.confPath + "\" 2>/dev/null; " +
            "echo COVER_SIZE=${COVER_SIZE:-480}; " +
            "echo RADIUS=${RADIUS:-30}; " +
            "echo BLUR_STRENGTH=${BLUR_STRENGTH:-30}; " +
            "echo DARKEN_AMOUNT=${DARKEN_AMOUNT:-35}; " +
            "echo TITLE_SIZE=${TITLE_SIZE:-40}; " +
            "echo ARTIST_SIZE=${ARTIST_SIZE:-26}; " +
            "echo MAX_CHARS=${MAX_CHARS:-28}; " +
            "echo VERTICAL_OFFSET=${VERTICAL_OFFSET:--80}; " +
            "echo PRIMARY_MONITOR=${PRIMARY_MONITOR:-0}; " +
            "echo RETRY_DELAY=${RETRY_DELAY:-5}; " +
            "echo MATCH_SCHEME=${MATCH_SCHEME:-false}; " +
            "echo SCHEME_MODE=${SCHEME_MODE:-dark}; " +
            "echo SCHEME_VARIANT=${SCHEME_VARIANT:-tonalspot}"
        ]

        stdout: SplitParser {
            onRead: line => { readProc.buf += line + "\n"; }
        }

        onExited: {
            const lines = readProc.buf.trim().split("\n");
            for (let l of lines) {
                const eq = l.indexOf("=");
                if (eq < 0) continue;
                const k = l.slice(0, eq).trim();
                const v = l.slice(eq + 1).trim();
                switch (k) {
                    case "COVER_SIZE":      root.coverSize      = parseInt(v) || 480;  break;
                    case "RADIUS":          root.radius         = parseInt(v) || 30;   break;
                    case "BLUR_STRENGTH":   root.blurStrength   = parseInt(v) || 30;   break;
                    case "DARKEN_AMOUNT":   root.darkenAmount   = parseInt(v) || 35;   break;
                    case "TITLE_SIZE":      root.titleSize      = parseInt(v) || 40;   break;
                    case "ARTIST_SIZE":     root.artistSize     = parseInt(v) || 26;   break;
                    case "MAX_CHARS":       root.maxChars       = parseInt(v) || 28;   break;
                    case "VERTICAL_OFFSET": root.verticalOffset = parseInt(v) || -80;  break;
                    case "PRIMARY_MONITOR": root.primaryMonitor = parseInt(v) || 0;    break;
                    case "RETRY_DELAY":     root.retryDelay     = parseInt(v) || 5;    break;
                    case "MATCH_SCHEME":    root.matchScheme    = (v === "true");      break;
                    case "SCHEME_MODE":     root.schemeMode     = v;                   break;
                    case "SCHEME_VARIANT":  root.schemeVariant  = v;                   break;
                }
            }
            readProc.buf = "";
            root.loaded = true;
        }
    }

    // Writes config via python3 (no shell involved = no quoting issues).
    // Restarts the service automatically after the write completes.
    Process {
        id: writeProc

        running: false
        onExited: {
            Quickshell.execDetached(["systemctl", "--user", "restart", root.service]);
        }
    }

    Process {
        id: statusProc

        running: true
        command: ["systemctl", "--user", "is-active", "--quiet", root.service]
        onExited: code => { root.serviceRunning = (code === 0); }
    }

    Timer {
        interval: 5000
        repeat:   true
        running:  true
        onTriggered: { statusProc.running = true; }
    }

    Component.onCompleted: { root.readConfig(); }

    // ─────────────────────────────────────────────────────────────
    // UI
    // ─────────────────────────────────────────────────────────────

    StyledFlickable {
        id: flickable

        anchors.fill: parent
        flickableDirection: Flickable.VerticalFlick
        contentHeight: mainLayout.implicitHeight + Tokens.padding.larger * 2

        StyledScrollBar.vertical: StyledScrollBar { flickable: flickable }

        ColumnLayout {
            id: mainLayout

            anchors.top:    parent.top
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.margins: Tokens.padding.larger
            spacing: Tokens.spacing.normal

            // ── Header ─────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.normal

                StyledText {
                    text: qsTr("Spotify Plugin")
                    font.pointSize: Tokens.font.size.large
                    font.weight: 500
                    Layout.fillWidth: true
                }

                // Service status pill
                StyledRect {
                    radius: Tokens.rounding.full
                    color: Qt.alpha(
                        root.serviceRunning ? Colours.palette.m3primaryContainer : Colours.palette.m3errorContainer,
                        0.8
                    )
                    implicitWidth: statusRow.implicitWidth + Tokens.padding.normal * 2
                    implicitHeight: statusRow.implicitHeight + Tokens.padding.small * 2

                    StateLayer {
                        onClicked: {
                            if (root.serviceRunning) {
                                Quickshell.execDetached(["systemctl", "--user", "stop", root.service]);
                            } else {
                                Quickshell.execDetached(["systemctl", "--user", "start", root.service]);
                            }
                            Qt.callLater(() => { statusTimer.restart(); });
                        }
                        color: root.serviceRunning
                            ? Colours.palette.m3onPrimaryContainer
                            : Colours.palette.m3onErrorContainer
                    }

                    RowLayout {
                        id: statusRow
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.smaller

                        MaterialIcon {
                            text: root.serviceRunning ? "play_circle" : "stop_circle"
                            font.pointSize: Tokens.font.size.normal
                            color: root.serviceRunning
                                ? Colours.palette.m3onPrimaryContainer
                                : Colours.palette.m3onErrorContainer
                        }

                        StyledText {
                            text: root.serviceRunning ? qsTr("Running") : qsTr("Stopped")
                            font.pointSize: Tokens.font.size.small
                            color: root.serviceRunning
                                ? Colours.palette.m3onPrimaryContainer
                                : Colours.palette.m3onErrorContainer
                        }
                    }

                    Timer {
                        id: statusTimer
                        interval: 1200
                        onTriggered: { statusProc.running = true; }
                    }
                }
            }

            // ── Album Art ──────────────────────────────────────
            CollapsibleSection {
                Layout.fillWidth: true
                title: qsTr("Album Art")
                showBackground: true
                expanded: true

                SectionContainer {
                    contentSpacing: Tokens.spacing.normal

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Cover size")
                        value: root.loaded ? root.coverSize : 480
                        from: 100; to: 800; stepSize: 10
                        suffix: "px"
                        validator: IntValidator { bottom: 100; top: 800 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.coverSize = Math.round(newValue);
                            root.writeKey("COVER_SIZE", root.coverSize.toString());
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Corner radius")
                        value: root.loaded ? root.radius : 30
                        from: 0; to: 120; stepSize: 1
                        suffix: "px"
                        validator: IntValidator { bottom: 0; top: 120 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.radius = Math.round(newValue);
                            root.writeKey("RADIUS", root.radius.toString());
                        }
                    }
                }
            }

            // ── Background ─────────────────────────────────────
            CollapsibleSection {
                Layout.fillWidth: true
                title: qsTr("Background")
                showBackground: true
                expanded: true

                SectionContainer {
                    contentSpacing: Tokens.spacing.normal

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Blur strength")
                        value: root.loaded ? root.blurStrength : 30
                        from: 0; to: 80; stepSize: 1
                        suffix: "σ"
                        validator: IntValidator { bottom: 0; top: 80 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.blurStrength = Math.round(newValue);
                            root.writeKey("BLUR_STRENGTH", root.blurStrength.toString());
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Darken amount")
                        value: root.loaded ? root.darkenAmount : 35
                        from: 0; to: 100; stepSize: 1
                        suffix: "%"
                        validator: IntValidator { bottom: 0; top: 100 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.darkenAmount = Math.round(newValue);
                            root.writeKey("DARKEN_AMOUNT", root.darkenAmount.toString());
                        }
                    }
                }
            }

            // ── Layout ─────────────────────────────────────────
            CollapsibleSection {
                Layout.fillWidth: true
                title: qsTr("Layout")
                showBackground: true
                expanded: true

                SectionContainer {
                    contentSpacing: Tokens.spacing.normal

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Vertical offset")
                        value: root.loaded ? root.verticalOffset : -80
                        from: -500; to: 500; stepSize: 5
                        suffix: "px"
                        validator: IntValidator { bottom: -500; top: 500 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.verticalOffset = Math.round(newValue);
                            root.writeKey("VERTICAL_OFFSET", root.verticalOffset.toString());
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Title font size")
                        value: root.loaded ? root.titleSize : 40
                        from: 10; to: 80; stepSize: 1
                        suffix: "pt"
                        validator: IntValidator { bottom: 10; top: 80 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.titleSize = Math.round(newValue);
                            root.writeKey("TITLE_SIZE", root.titleSize.toString());
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Artist font size")
                        value: root.loaded ? root.artistSize : 26
                        from: 8; to: 60; stepSize: 1
                        suffix: "pt"
                        validator: IntValidator { bottom: 8; top: 60 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.artistSize = Math.round(newValue);
                            root.writeKey("ARTIST_SIZE", root.artistSize.toString());
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Max text length")
                        value: root.loaded ? root.maxChars : 28
                        from: 5; to: 60; stepSize: 1
                        suffix: "ch"
                        validator: IntValidator { bottom: 5; top: 60 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.maxChars = Math.round(newValue);
                            root.writeKey("MAX_CHARS", root.maxChars.toString());
                        }
                    }
                }
            }

            // ── Match Scheme ───────────────────────────────────
            CollapsibleSection {
                Layout.fillWidth: true
                title: qsTr("Match Scheme")
                showBackground: true
                expanded: true

                SwitchRow {
                    label: qsTr("Match scheme to album art")
                    checked: root.matchScheme
                    onToggled: checked => {
                        root.matchScheme = checked;
                        root.writeKey("MATCH_SCHEME", checked ? "true" : "false");
                    }
                }

                SectionContainer {
                    contentSpacing: Tokens.spacing.small
                    enabled: root.matchScheme
                    opacity: root.matchScheme ? 1 : 0.4

                    StyledText {
                        text: qsTr("Mode")
                        font.pointSize: Tokens.font.size.small
                        color: Colours.palette.m3outline
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Tokens.spacing.small

                        Repeater {
                            model: [
                                { label: qsTr("Dark"),  value: "dark",  icon: "dark_mode"  },
                                { label: qsTr("Light"), value: "light", icon: "light_mode" }
                            ]

                            delegate: StyledRect {
                                required property var modelData
                                Layout.fillWidth: true

                                readonly property bool active: root.schemeMode === modelData.value

                                radius: Tokens.rounding.normal
                                color: active ? Colours.layer(Colours.palette.m3surfaceContainer, 2) : "transparent"
                                border.width: active ? 1 : 0
                                border.color: Colours.palette.m3primary
                                implicitHeight: modeRow.implicitHeight + Tokens.padding.normal * 2

                                StateLayer {
                                    onClicked: {
                                        if (!root.matchScheme) return;
                                        root.schemeMode = modelData.value;
                                        root.writeKey("SCHEME_MODE", modelData.value);
                                    }
                                }

                                RowLayout {
                                    id: modeRow
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.small

                                    MaterialIcon {
                                        text: modelData.icon
                                        font.pointSize: Tokens.font.size.normal
                                        color: active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                    }

                                    StyledText {
                                        text: modelData.label
                                        font.weight: active ? 600 : 400
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        text: qsTr("Variant")
                        font.pointSize: Tokens.font.size.small
                        color: Colours.palette.m3outline
                    }

                    Repeater {
                        model: [
                            { name: "tonalspot",  icon: "palette"        },
                            { name: "vibrant",    icon: "colorize"       },
                            { name: "expressive", icon: "auto_awesome"   },
                            { name: "fidelity",   icon: "tune"           },
                            { name: "fruitsalad", icon: "spa"            },
                            { name: "monochrome", icon: "filter_b_and_w" },
                            { name: "neutral",    icon: "circle"         },
                            { name: "rainbow",    icon: "gradient"       },
                            { name: "content",    icon: "image"          }
                        ]

                        delegate: StyledRect {
                            required property var modelData
                            Layout.fillWidth: true

                            readonly property bool active: root.schemeVariant === modelData.name

                            radius: Tokens.rounding.normal
                            color: active ? Colours.layer(Colours.palette.m3surfaceContainer, 2) : "transparent"
                            border.width: active ? 1 : 0
                            border.color: Colours.palette.m3primary
                            implicitHeight: variantRow.implicitHeight + Tokens.padding.normal * 2

                            StateLayer {
                                onClicked: {
                                    if (!root.matchScheme) return;
                                    root.schemeVariant = modelData.name;
                                    root.writeKey("SCHEME_VARIANT", modelData.name);
                                }
                            }

                            RowLayout {
                                id: variantRow
                                anchors.left:   parent.left
                                anchors.right:  parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.margins: Tokens.padding.normal
                                spacing: Tokens.spacing.normal

                                MaterialIcon {
                                    text: modelData.icon
                                    font.pointSize: Tokens.font.size.large
                                    fill: active ? 1 : 0
                                    color: active ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: modelData.name
                                    font.weight: active ? 500 : 400
                                }

                                MaterialIcon {
                                    visible: active
                                    text: "check"
                                    color: Colours.palette.m3primary
                                    font.pointSize: Tokens.font.size.large
                                }
                            }
                        }
                    }
                }
            }

            // ── Advanced ───────────────────────────────────────
            CollapsibleSection {
                Layout.fillWidth: true
                title: qsTr("Advanced")
                showBackground: true
                expanded: false

                SectionContainer {
                    contentSpacing: Tokens.spacing.normal

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Primary monitor index")
                        value: root.loaded ? root.primaryMonitor : 0
                        from: 0; to: 8; stepSize: 1
                        suffix: ""
                        validator: IntValidator { bottom: 0; top: 8 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.primaryMonitor = Math.round(newValue);
                            root.writeKey("PRIMARY_MONITOR", root.primaryMonitor.toString());
                        }
                    }

                    SliderInput {
                        Layout.fillWidth: true
                        label: qsTr("Retry delay")
                        value: root.loaded ? root.retryDelay : 5
                        from: 1; to: 30; stepSize: 1
                        suffix: "s"
                        validator: IntValidator { bottom: 1; top: 30 }
                        formatValueFunction: val => Math.round(val).toString()
                        parseValueFunction: text => parseInt(text)
                        onValueModified: newValue => {
                            root.retryDelay = Math.round(newValue);
                            root.writeKey("RETRY_DELAY", root.retryDelay.toString());
                        }
                    }
                }
            }

            // ── Service controls ───────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Tokens.spacing.normal

                // Restart service
                StyledRect {
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    implicitHeight: reloadRow.implicitHeight + Tokens.padding.large * 2

                    StateLayer {
                        onClicked: {
                            root.restartService();
                            Qt.callLater(() => { statusTimer2.restart(); });
                        }
                    }

                    Timer {
                        id: statusTimer2
                        interval: 1500
                        onTriggered: { statusProc.running = true; }
                    }

                    RowLayout {
                        id: reloadRow
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "refresh"
                            font.pointSize: Tokens.font.size.normal
                            color: Colours.palette.m3primary
                        }

                        StyledText {
                            text: qsTr("Restart service")
                            color: Colours.palette.m3primary
                        }
                    }
                }

                // Reload config from disk
                StyledRect {
                    Layout.fillWidth: true
                    radius: Tokens.rounding.normal
                    color: Colours.layer(Colours.palette.m3surfaceContainer, 2)
                    implicitHeight: reloadRow.implicitHeight + Tokens.padding.large * 2

                    StateLayer {
                        onClicked: { root.readConfig(); }
                    }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "sync"
                            font.pointSize: Tokens.font.size.normal
                            color: Colours.palette.m3secondary
                        }

                        StyledText {
                            text: qsTr("Reload config")
                            color: Colours.palette.m3secondary
                        }
                    }
                }
            }

            // ── Clear cache ────────────────────────────────────
            StyledRect {
                id: clearCacheBtn

                property bool clearing: false

                Layout.fillWidth: true
                radius: Tokens.rounding.normal
                color: clearing
                    ? Qt.alpha(Colours.palette.m3errorContainer, 0.6)
                    : Qt.alpha(Colours.palette.m3surfaceContainer, 0.5)
                implicitHeight: clearCacheRow.implicitHeight + Tokens.padding.large * 2

                Behavior on color { ColorAnimation { duration: 200 } }

                StateLayer {
                    onClicked: {
                        if (clearCacheBtn.clearing) return;
                        clearCacheBtn.clearing = true;
                        root.clearCache();
                        clearCacheTimer.restart();
                    }
                }

                Timer {
                    id: clearCacheTimer
                    interval: 1500
                    onTriggered: { clearCacheBtn.clearing = false; }
                }

                RowLayout {
                    id: clearCacheRow
                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: clearCacheBtn.clearing ? "hourglass_empty" : "delete_sweep"
                        font.pointSize: Tokens.font.size.normal
                        color: clearCacheBtn.clearing
                            ? Colours.palette.m3onErrorContainer
                            : Colours.palette.m3error
                    }

                    StyledText {
                        text: clearCacheBtn.clearing ? qsTr("Clearing…") : qsTr("Clear cached images")
                        color: clearCacheBtn.clearing
                            ? Colours.palette.m3onErrorContainer
                            : Colours.palette.m3error
                    }
                }
            }

            Item { implicitHeight: Tokens.padding.larger }
        }
    }
}
