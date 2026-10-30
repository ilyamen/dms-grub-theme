import QtQuick
import Quickshell
import qs.Common
import qs.DCommon.Widgets
import qs.Services
import qs.Widgets
import qs.Modules.Plugins
import "GrubThemeCore.js" as Core

PluginSettings {
    id: root

    pluginId: "grubTheme"

    readonly property var shared: PluginService.globalVars["grubTheme"] ?? ({})
    readonly property var status: shared.status ?? null
    readonly property bool busy: shared.busy === true
    readonly property string errorText: shared.error ?? ""
    readonly property var installed: status?.installed ?? null
    readonly property bool upToDate: installed !== null && installed.version === status.version && installed.current !== false
    readonly property var applied: status?.applied ?? null
    readonly property bool canInstall: status !== null && status.grub && status.pil && status.mkfont

    Component.onCompleted: {
        Core.init(Proc, PluginService);
        Core.refresh();
    }

    StyledText {
        width: parent.width
        text: I18n.trFor("grubTheme", "Paint the GRUB menu in the colors DMS takes from the wallpaper, and repaint it whenever the wallpaper changes. The menu shows for a few seconds on every boot.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: helperColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        Column {
            id: helperColumn

            x: Theme.spacingM
            y: Theme.spacingM
            width: parent.width - Theme.spacingM * 2
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS

                DIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.upToDate ? "check_circle" : "warning"
                    size: Theme.iconSize
                    color: root.upToDate ? Theme.success : Theme.warning
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        if (!root.status)
                            return I18n.trFor("grubTheme", "Checking the helper…");
                        if (!root.installed)
                            return I18n.trFor("grubTheme", "Helper not installed");
                        if (!root.upToDate)
                            return I18n.trFor("grubTheme", "Helper out of date: %1 installed, %2 available").arg(root.installed.version).arg(root.status.version);
                        return I18n.trFor("grubTheme", "Helper installed");
                    }
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                }
            }

            StyledText {
                width: parent.width
                visible: !root.upToDate
                text: I18n.trFor("grubTheme", "The theme lives in /boot, which only root can write. A small helper draws it there, and polkit lets the active session run it without a password, so the menu can follow the wallpaper. Installing it asks for your password once.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            StyledText {
                width: parent.width
                visible: root.status !== null && !root.canInstall
                text: !root.status?.grub ? I18n.trFor("grubTheme", "GRUB with update-grub was not found.") : I18n.trFor("grubTheme", "Install python3-pil and grub-common (grub-mkfont) first.")
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.error
                wrapMode: Text.WordWrap
            }

            DButton {
                visible: root.canInstall && !root.upToDate
                enabled: !root.busy
                text: !root.installed ? I18n.trFor("grubTheme", "Install helper") : I18n.trFor("grubTheme", "Update helper")
                iconName: "download"
                onClicked: Core.runInstaller("install")
            }

            Row {
                visible: root.applied !== null
                spacing: Theme.spacingXS

                Repeater {
                    model: root.applied ? Core.ROLES.map(role => root.applied.colors[role]) : []

                    Rectangle {
                        required property var modelData

                        width: 20
                        height: 20
                        radius: 10
                        color: modelData
                        border.width: 1
                        border.color: Theme.outlineVariant
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: root.applied !== null
                text: root.applied ? I18n.trFor("grubTheme", "Theme drawn %1 for %2").arg(new Date(root.applied.time * 1000).toLocaleString(Qt.locale(), Locale.ShortFormat)).arg(root.applied.size === "auto" ? I18n.trFor("grubTheme", "Auto (2560×1440 or 1920×1080)") : root.applied.size) : ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                wrapMode: Text.WordWrap
            }

            DButton {
                visible: root.upToDate
                enabled: !root.busy
                text: I18n.trFor("grubTheme", "Repaint now")
                iconName: "palette"
                onClicked: Proc.runCommand("grubTheme.applyNow", ["dms", "ipc", "call", "grubTheme", "apply"], () => {})
            }
        }
    }

    SelectionSetting {
        settingKey: "resolution"
        label: I18n.trFor("grubTheme", "Resolution")
        description: I18n.trFor("grubTheme", "Auto asks for 2560×1440, then 1920×1080, which nearly every firmware offers. A screen's own size works only if the firmware can drive it: see which modes it has by typing videoinfo in the GRUB console (C). If GRUB can't set it, it falls back to Auto.")
        defaultValue: "auto"
        options: {
            const options = [
                {
                    "label": I18n.trFor("grubTheme", "Auto"),
                    "value": "auto"
                }
            ];
            const add = (size, label) => {
                if (!options.some(option => option.value === size))
                    options.push({
                        "label": label,
                        "value": size
                    });
            };
            for (const screen of Quickshell.screens) {
                const ratio = screen.devicePixelRatio || 1;
                const width = Math.round(screen.width * ratio);
                const height = Math.round(screen.height * ratio);
                // GRUB has no portrait modes
                if (width < height)
                    continue;
                const name = screen.model || screen.name;
                add(width + "x" + height, "%1 · %2".arg(width + "x" + height).arg(name));
                // Wide screens usually list their shape at 1080 lines too (3840x1080 on a
                // 5120x1440 one), and firmware that can't drive the full size often can that
                if (height > 1080) {
                    const scaled = Math.round(width * 1080 / height / 8) * 8 + "x1080";
                    add(scaled, I18n.trFor("grubTheme", "%1 · %2, whole screen at a lower resolution").arg(scaled).arg(name));
                }
            }
            return options;
        }
    }

    ToggleSetting {
        settingKey: "fadeEdges"
        label: I18n.trFor("grubTheme", "Fade the sides to black")
        description: I18n.trFor("grubTheme", "The picture eases into black on the left and right, so the black bars beside a menu the firmware can't stretch to the whole screen blend in. The top and bottom keep the full color.")
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "followWallpaper"
        label: I18n.trFor("grubTheme", "Follow the wallpaper")
        description: I18n.trFor("grubTheme", "Repaint the menu whenever DMS makes a new palette. Off keeps the current colors until you press Repaint now.")
        defaultValue: true
    }

    SliderSetting {
        settingKey: "timeout"
        label: I18n.trFor("grubTheme", "Menu timeout")
        description: I18n.trFor("grubTheme", "How long the menu waits before starting the default entry.")
        minimum: 1
        maximum: 10
        defaultValue: 3
        unit: I18n.trFor("grubTheme", "s", "unit, seconds")
    }

    StyledText {
        width: parent.width
        visible: root.errorText !== ""
        text: root.errorText
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.error
        wrapMode: Text.WordWrap
    }

    DButton {
        visible: root.installed !== null
        enabled: !root.busy
        text: I18n.trFor("grubTheme", "Remove helper and theme")
        iconName: "delete"
        onClicked: Core.runInstaller("uninstall")
    }
}
