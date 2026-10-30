.pragma library

// Shared by the background component and the settings page: runs the helper and
// publishes its status through PluginService global vars, so both update together.

var PLUGIN_ID = "grubTheme";
// pkexec exits with 126 when the password dialog is dismissed or access is denied
var PKEXEC_DISMISSED = 126;
// The Material You roles the theme is drawn with, as DMS names them in dms-colors.json
var ROLES = ["surface", "surface_container", "primary_container", "on_primary_container", "on_surface", "on_surface_variant", "outline"];

var proc = null;
var store = null;

function init(procSingleton, pluginService) {
    proc = procSingleton;
    store = pluginService;
}

function publish(key, value) {
    if (store)
        store.setGlobalVar(PLUGIN_ID, key, value);
}

function current(key, fallback) {
    return store ? store.getGlobalVar(PLUGIN_ID, key, fallback) : fallback;
}

function pluginDir() {
    return store?.availablePlugins[PLUGIN_ID]?.pluginDirectory ?? "";
}

// `status` needs no privileges, and the copy shipped with the plugin also reports
// which version of the helper is installed, so it works before installing too.
function refresh() {
    if (!proc)
        return;
    proc.runCommand("grubTheme.status", ["python3", "-I", pluginDir() + "/system/dms-grub-theme", "status"], (output, exitCode) => {
        if (exitCode !== 0) {
            publish("status", null);
            return;
        }
        try {
            publish("status", JSON.parse(output));
        } catch (e) {
            publish("status", null);
        }
    }, 300);
}

function helperPath() {
    return current("status", null)?.installed?.path ?? "";
}

// Privileged commands go through pkexec; stderr is folded into stdout to show
// why a command failed.
function runPrivileged(id, command, callback) {
    if (!proc || current("busy", false))
        return false;
    publish("busy", true);
    publish("error", "");
    proc.runCommand(id, ["sh", "-c", "exec pkexec \"$@\" 2>&1", "sh"].concat(command), (output, exitCode) => {
        publish("busy", false);
        if (exitCode !== 0 && exitCode !== PKEXEC_DISMISSED)
            publish("error", output.trim() || ("exit code " + exitCode));
        if (callback)
            callback(exitCode);
        refresh();
    }, 0, proc.noTimeout);
    return true;
}

// Installing asks for the password through polkit's ordinary exec action
function runInstaller(action, callback) {
    runPrivileged("grubTheme." + action, ["/bin/sh", pluginDir() + "/system/install.sh", action], callback);
}

// The dark variant whatever the desktop uses: GRUB runs before anything lights the screen
function paletteFrom(colorsJson) {
    try {
        const data = JSON.parse(colorsJson);
        const scheme = (data.colors ?? data).dark ?? data.colors ?? data;
        const palette = {};
        for (const role of ROLES) {
            if (!/^#[0-9a-fA-F]{6}$/.test(scheme[role] ?? ""))
                return null;
            palette[role] = scheme[role].toLowerCase();
        }
        return palette;
    } catch (e) {
        return null;
    }
}

// What the theme should look like, in the shape the helper reports in `applied`;
// a theme drawn by an older helper is drawn again
function sameTheme(wanted, applied, renderer) {
    if (!applied || applied.renderer !== renderer)
        return false;
    return JSON.stringify(wanted.colors) === JSON.stringify(applied.colors) && wanted.size === applied.size && wanted.fade === (applied.fade === true) && wanted.timeoutText === applied.timeoutText && wanted.hintsText === applied.hintsText;
}

function apply(wanted) {
    const colors = ROLES.map(role => role + "=" + wanted.colors[role]);
    const fade = wanted.fade ? ["--fade"] : [];
    return runPrivileged("grubTheme.apply", [helperPath(), "apply", "--size", wanted.size].concat(fade, ["--timeout-text", wanted.timeoutText, "--hints-text", wanted.hintsText], colors));
}

function setMenuTimeout(seconds) {
    return runPrivileged("grubTheme.config", [helperPath(), "config", "--timeout", String(seconds)]);
}
