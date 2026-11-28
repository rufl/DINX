# DINX Fish defaults are shared by live, installed and newly created users.
set -gx SHELL /bin/fish

if not set -q TERMINAL
    set -gx TERMINAL deetty
end
if not set -q EDITOR
    set -gx EDITOR dintor
end
if not set -q VISUAL
    set -gx VISUAL $EDITOR
end
if not set -q XDG_CURRENT_DESKTOP
    set -gx XDG_CURRENT_DESKTOP river
end
set -gx DINX_COLOR_SCHEME dark
set -gx DINTOR_THEME prefer-dark
set -gx QT_STYLE_OVERRIDE fusion
set -gx XCURSOR_THEME Adwaita
set -gx XCURSOR_SIZE 24

if status is-interactive
    set -g fish_greeting
    alias ll 'ls -alF'
    alias la 'ls -A'
end
