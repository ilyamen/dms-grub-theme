import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Modules.Plugins
import "GrubThemeCore.js" as Core

// Watches the palette DMS generates from the wallpaper and repaints the GRUB
// theme when it changes. The helper only rewrites grub.cfg when the screen size
// or the timeout changes, so a new wallpaper costs a few small files in /boot.
PluginComponent {
    id: root

    readonly property var status: PluginService.globalVars["grubTheme"]?.status ?? null
    // What was last sent to the helper, so a failure isn't retried on every refresh
    property string lastAttempt: ""

    Component.onCompleted: {
        Core.init(Proc, PluginService);
        Core.refresh();
    }

    FileView {
        id: colorsFile

        path: Theme.stateDir + "/dms-colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: syncTimer.restart()
    }

    // matugen rewrites the file in several steps; wait until it has settled
    Timer {
        id: syncTimer

        interval: 3000
        onTriggered: root.sync(false)
    }

    onStatusChanged: syncTimer.restart()

    Connections {
        target: PluginService

        function onPluginDataChanged(pluginId) {
            if (pluginId === "grubTheme")
                syncTimer.restart();
        }
    }

    function wantedTheme() {
        const colors = Core.paletteFrom(colorsFile.text());
        if (!colors)
            return null;
        return {
            "colors": colors,
            "size": SettingsData.getPluginSetting("grubTheme", "resolution", "auto"),
            "fade": SettingsData.getPluginSetting("grubTheme", "fadeEdges", true) !== false,
            "timeoutText": I18n.trFor("grubTheme", "Booting in %d s", "GRUB menu, %d is the number of seconds"),
            "hintsText": I18n.trFor("grubTheme", "↑ ↓  select    ·    Enter  boot    ·    E  edit    ·    C  console", "GRUB menu key hints")
        };
    }

    // force: repaint even if nothing changed (the settings page's Apply button)
    function sync(force) {
        if (!status?.installed || status.installed.version !== status.version || status.installed.current === false)
            return "helper not installed";
        if (!force && SettingsData.getPluginSetting("grubTheme", "followWallpaper", true) === false)
            return "off";
        const timeout = SettingsData.getPluginSetting("grubTheme", "timeout", 3);
        const wanted = wantedTheme();
        if (!wanted)
            return "no palette";
        if (force || !Core.sameTheme(wanted, status.applied, status.renderer)) {
            const attempt = JSON.stringify(wanted);
            if (!force && attempt === lastAttempt)
                return "failed before";
            if (!Core.apply(wanted))
                return "busy";
            lastAttempt = attempt;
            return "applying";
        }
        // Needs a theme first: setting the timeout before it would show the stock menu
        if (status.config && status.config.timeout !== timeout) {
            const attempt = "timeout " + timeout;
            if (attempt === lastAttempt)
                return "failed before";
            if (!Core.setMenuTimeout(timeout))
                return "busy";
            lastAttempt = attempt;
            return "setting timeout";
        }
        return "up to date";
    }

    IpcHandler {
        target: "grubTheme"

        function apply(): string {
            return root.sync(true);
        }

        function status(): string {
            return JSON.stringify(root.status);
        }
    }
}
