#!/usr/bin/env bash
# Renders the complete window status pill for one window:
#   [entry arrow] [icon badge] [label] [exit arrow]
# All tmux reads happen in one process, so there is no caching race between
# the prefix, label and suffix calls that previously used separate #() entries.

set -euo pipefail

window_id="${1:?window_id is required}"
# tab_bg: background for the window name area
# non-current: #3a3a3a   current: #7f9a69
tab_bg="${2:-#3a3a3a}"
# label_fg: text colour for the window name
# non-current: #a7c080   current: #262626
label_fg="${3:-#a7c080}"

# U+E0B0 powerline right-pointing filled triangle
sep=$'\xee\x82\xb0'

status="$(tmux show-options -wqv -t "$window_id" @workmux_status 2>/dev/null || true)"

# Resolve window name (fall back to cwd basename)
window_name="$(tmux display-message -p -t "$window_id" '#W' 2>/dev/null || true)"
if [[ -z "$window_name" ]]; then
    window_path="$(tmux display-message -p -t "$window_id" '#{pane_current_path}' 2>/dev/null || true)"
    window_name="${window_path##*/}"
    window_name="${window_name:0:8}"
fi

# Icon badge colour — separate from tab_bg so the name area keeps its own colour.
case "$status" in
    '🤖') icon_bg="#f4a261" ;;
    '💬') icon_bg="#ffd166" ;;
    '✅') icon_bg="#7bd88f" ;;
    *) icon_bg="" ;;
esac

# Entry: gap(#262626) → icon_bg → tab_bg
if [[ -n "$icon_bg" ]]; then
    # gap → icon badge
    printf '#[fg=#262626,bg=%s]%s' "$icon_bg" "$sep"
    # icon: dark bold text on icon_bg
    printf '#[fg=#262626,bold]%s' "$status"
    # icon → name area
    printf '#[nobold,fg=%s,bg=%s]%s' "$icon_bg" "$tab_bg" "$sep"
else
    # No icon: gap → name area directly
    printf '#[fg=#262626,bg=%s]%s' "$tab_bg" "$sep"
fi

# Label
printf '#[fg=%s,nobold]%s' "$label_fg" "$window_name"

# Exit: name area → gap
printf '#[fg=%s,bg=#262626]%s' "$tab_bg" "$sep"
