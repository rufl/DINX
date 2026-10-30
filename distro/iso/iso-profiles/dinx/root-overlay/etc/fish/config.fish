# DINX Fish defaults are shared by live, installed and newly created users.
set -gx SHELL /bin/fish

if not set -q TERMINAL
    set -gx TERMINAL dinx-terminal
end
if not set -q EDITOR
    set -gx EDITOR nocted
end
if not set -q VISUAL
    set -gx VISUAL $EDITOR
end
if not set -q XDG_CURRENT_DESKTOP
    set -gx XDG_CURRENT_DESKTOP Aqueous
end
if not set -q DINX_COLOR_SCHEME
    set -gx DINX_COLOR_SCHEME dark
end
if not set -q NOCTED_THEME
    set -gx NOCTED_THEME prefer-dark
end
if not set -q GTK_THEME
    set -gx GTK_THEME DINX:dark
end
if not set -q QT_QPA_PLATFORMTHEME
    set -gx QT_QPA_PLATFORMTHEME qt6ct
end
if not set -q XCURSOR_THEME
    set -gx XCURSOR_THEME Adwaita
end
if not set -q XCURSOR_SIZE
    set -gx XCURSOR_SIZE 24
end

if status is-interactive
    set -g fish_greeting
    alias ll 'ls -alF'
    alias la 'ls -A'
end
