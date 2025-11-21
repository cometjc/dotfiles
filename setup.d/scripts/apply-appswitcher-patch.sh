#!/bin/bash
# vim: set et fenc=utf-8 ff=unix sts=4 sw=4 ts=8 :

FILE_PATH="/usr/share/cinnamon/js/ui/appSwitcher/appSwitcher.js"
PATCH_FILE="$(dirname "$(realpath "$0")")/appSwitcher.patch"
NEW_LINE="windows = windows.filter(w => w.get_monitor() === global.screen.get_current_monitor())"

if [[ -f "$FILE_PATH" ]]; then
    if grep -qF "$NEW_LINE" "$FILE_PATH"; then
        exit 0
    else
        if sudo cat "$PATCH_FILE" | sudo patch "$FILE_PATH"; then
            exit 0
        else
            exit 1
        fi
    fi
else
    exit 1
fi
