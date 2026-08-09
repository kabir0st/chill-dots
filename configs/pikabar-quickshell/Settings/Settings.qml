pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

Singleton {

    property string shellName: "pikabar"
    property string settingsDir: Quickshell.env("PIKABAR_SETTINGS_DIR") || (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/" + shellName + "/"
    property string settingsFile: Quickshell.env("PIKABAR_SETTINGS_FILE") || (settingsDir + "Settings.json")
    property string themeFile: Quickshell.env("PIKABAR_THEME_FILE") || (settingsDir + (settings.lightMode ? "ThemeLight.json" : "Theme.json"))
    property var settings: settingAdapter

    Item {
        Component.onCompleted: {
            // ensure settings dir
            Quickshell.execDetached(["mkdir", "-p", settingsDir]);
        }
    }

    FileView {
        id: settingFileView
        path: settingsFile
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        property bool initialLoaded: false
        Component.onCompleted: function() {
            reload()
        }
        onLoaded: function() {
            Qt.callLater(function() {
                sanitizeMonitorLists();
            });
            if (!initialLoaded) {
                initialLoaded = true;
                Qt.callLater(function () {
                    WallpaperManager.setCurrentWallpaper(settings.currentWallpaper, true);
                })
            }
        }
        onLoadFailed: function(error) {
            settingAdapter = {}
            writeAdapter()
        }
        JsonAdapter {
            id: settingAdapter
            property bool lightMode: false
            property string weatherCity: "Gothenburg"
            property string profileImage: Quickshell.env("HOME") + "/.face"
            property bool useFahrenheit: false
            property string wallpaperFolder: "/usr/share/wallpapers/pika"
            property string currentWallpaper: "/usr/share/wallpapers/pika/duck_village_by_neytirix_dekbu6y.jpg"
            property string videoPath: "~/Videos/"
            property bool showActiveWindow: true
            property bool showActiveWindowIcon: true
            property bool showSystemInfoInBar: true
            property bool showCorners: true
            property bool showTaskbar: false
            property bool showMediaInBar: true
            property bool useSWWW: true
            property bool randomWallpaper: true
            property bool useWallpaperTheme: true
            property int wallpaperInterval: 300
            property string wallpaperResize: "crop"
            property int transitionFps: 60
            property string transitionType: "random"
            property real transitionDuration: 1.1
            property string visualizerType: "radial"
            property bool reverseDayMonth: false
            property bool use12HourClock: false
            property bool dimPanels: true
            property real barOpacity: 0.72  // Top bar background opacity (0.0 = fully transparent, 1.0 = opaque)
            property real fontSizeMultiplier: 1.0  // Font size multiplier (1.0 = normal, 1.2 = 20% larger, 0.8 = 20% smaller)
            property int taskbarIconSize: 24  // Taskbar icon button size in pixels (default: 32, smaller: 24, larger: 40)
            property var pinnedExecs: [] // Added for AppLauncher pinned apps

            property bool showDock: false
            property bool dockExclusive: false
            property bool wifiEnabled: true
            property bool bluetoothEnabled: true
            property int recordingFrameRate: 60
            property string recordingQuality: "very_high"
            property string recordingCodec: "h264"
            property string audioCodec: "opus"
            property bool showCursor: true
            property string colorRange: "limited"
            
            // Monitor/Display Settings
            property var barMonitors: []
            property var dockMonitors: []
            property var notificationMonitors: []
            property var monitorScaleOverrides: {} // Map of monitor name -> scale override (e.g., 0.8..2.0). When set, Theme.scale() returns this value
        }
    }

    Connections {
        target: settingAdapter
        function onRandomWallpaperChanged() { WallpaperManager.toggleRandomWallpaper() }
        function onWallpaperIntervalChanged() { WallpaperManager.restartRandomWallpaperTimer() }
        function onWallpaperFolderChanged() { WallpaperManager.loadWallpapers() }
        function onNotificationMonitorsChanged() { 
        }
    }

    function sanitizeMonitorLists() {
        let sanitize = (list) => {
            if (!list || !Array.isArray(list)) return [];
            return list.filter(name => name && typeof name === "string" && name.trim() !== "");
        };
        
        let newBar = sanitize(settings.barMonitors);
        let newDock = sanitize(settings.dockMonitors);
        let newNotif = sanitize(settings.notificationMonitors);
        
        if (JSON.stringify(newBar) !== JSON.stringify(settings.barMonitors)) {
            settings.barMonitors = newBar;
        }
        if (JSON.stringify(newDock) !== JSON.stringify(settings.dockMonitors)) {
            settings.dockMonitors = newDock;
        }
        if (JSON.stringify(newNotif) !== JSON.stringify(settings.notificationMonitors)) {
            settings.notificationMonitors = newNotif;
        }
    }
    Process {
        id: themeMonitorProcess
        running: true
        command: ["gsettings", "monitor", "org.gnome.desktop.interface", "color-scheme"]
        stdout: SplitParser {
            onRead: function (line) {
                if (line.includes('prefer-light')) {
                    if (!settingAdapter.lightMode) {
                        settingAdapter.lightMode = true;
                    }
                } else if (line.includes('prefer-dark')) {
                    if (settingAdapter.lightMode) {
                        settingAdapter.lightMode = false;
                    }
                }
            }
        }
    }
}
