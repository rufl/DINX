# DINX shell defaults are deliberately small so recovery TTYs remain usable.
# Fish is the DINX login shell; keep this POSIX fallback for recovery and non-Fish callers.
export SHELL=/bin/fish
export TERMINAL="${TERMINAL:-dinx-terminal}"
export EDITOR="${EDITOR:-nocted}"
export VISUAL="${VISUAL:-$EDITOR}"
export XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-Aqueous}"
export DINX_COLOR_SCHEME="${DINX_COLOR_SCHEME:-dark}"
export NOCTED_THEME="${NOCTED_THEME:-prefer-dark}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"
export XCURSOR_THEME="${XCURSOR_THEME:-Adwaita}"
export XCURSOR_SIZE="${XCURSOR_SIZE:-24}"
