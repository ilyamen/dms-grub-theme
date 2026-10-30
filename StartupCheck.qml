import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("grubTheme.depCheck", ["sh", "-c", "[ -d /etc/grub.d ] || exit 3; command -v update-grub && command -v grub-mkfont && command -v pkexec && python3 -c 'import PIL'"], (stdout, exitCode) => {
            if (exitCode === 0) {
                done(null);
                return;
            }
            if (exitCode === 3) {
                done({
                    "title": I18n.trFor("grubTheme", "GRUB is not installed"),
                    "details": I18n.trFor("grubTheme", "This plugin themes the GRUB boot menu and needs GRUB with /etc/grub.d and update-grub.")
                });
                return;
            }
            done({
                "title": I18n.trFor("grubTheme", "python3-pil, grub-mkfont and pkexec are required"),
                "details": I18n.trFor("grubTheme", "The theme is drawn with Pillow, its fonts are made with grub-mkfont, and it is written to /boot through polkit. Install python3-pil, grub-common and polkit, then re-enable the plugin.")
            });
        });
    }
}
