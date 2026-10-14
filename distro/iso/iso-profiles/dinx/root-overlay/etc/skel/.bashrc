# DINX keeps the recovery shell predictable and free of framework hooks.
if [ -r /etc/profile.d/dinx.sh ]; then
    . /etc/profile.d/dinx.sh
fi

case $- in
    *i*)
        PS1='\[\e[1;36m\]\u@\h\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ '
        alias ll='ls -alF'
        alias la='ls -A'
        ;;
esac
