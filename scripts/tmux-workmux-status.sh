#!/usr/bin/env bash

set -euo pipefail

window_id="${1:?window_id is required}"
# prefix: entry arrow + optional icon sub-badge, leave bg=tab_bg for the label
# suffix: exit arrow back to #262626 gap
mode="${2:-prefix}"
# tab_bg: background for the window name area (non-current: #3a3a3a, current: #7f9a69)
tab_bg="${3:-#3a3a3a}"

status="$(tmux show-options -wqv -t "$window_id" @workmux_status 2>/dev/null || true)"

# U+E0B0 powerline right-pointing filled triangle
sep=$'\xee\x82\xb0'

# Icon badge colour — separate from tab_bg so the name area keeps its own colour.
case "$status" in
    '🤖') icon_bg="#f4a261" ;;
    '💬') icon_bg="#ffd166" ;;
    '✅') icon_bg="#7bd88f" ;;
    *) icon_bg="" ;;
esac

case "$mode" in
    prefix)
        if [[ -n "$icon_bg" ]]; then
            # gap(#262626) → icon_bg: dark arrow pointing into icon colour
            printf '#[fg=#262626,bg=%s]%s' "$icon_bg" "$sep"
            # icon: dark bold text on icon_bg
            printf '#[fg=#262626,bold]%s' "$status"
            # icon_bg → tab_bg: icon colour retreats into name area
            printf '#[nobold,fg=%s,bg=%s]%s' "$icon_bg" "$tab_bg" "$sep"
        else
            # No icon: gap(#262626) → tab_bg directly
            printf '#[fg=#262626,bg=%s]%s' "$tab_bg" "$sep"
        fi
        ;;
    suffix)
        # tab_bg → gap(#262626): name area retreats into dark gap
        printf '#[fg=%s,bg=#262626]%s' "$tab_bg" "$sep"
        ;;
esac
