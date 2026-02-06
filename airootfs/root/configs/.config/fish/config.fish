
# Create aliases
# alias cat="bat"
alias ls="lsd"

# TODO: Replace journal aliases after switching to OpenRC

# Display critical errors
alias syslog_emerg="sudo dmesg --level=emerg,alert,crit"

# Output common errors
alias syslog="sudo dmesg --level=err,warn"

# Print logs from x server
alias xlog='grep "(EE)\|(WW)\|error\|failed" ~/.local/share/xorg/Xorg.0.log'

# Remove archived journal files until the disk space they use falls below 100M
alias vacuum="journalctl --vacuum-size=100M"

# Make all journal files contain no data older than 2 weeks
alias vacuum_time="journalctl --vacuum-time=2weeks"

set -U fish_greeting
set fish_color_command green
set -gx EDITOR micro
set -gx VISUAL micro
set -g fish_key_bindings fish_default_key_bindings

if status is-interactive
    # Commands to run in interactive sessions can go here
    atuin init fish | awk '{ if ($0 ~ /^bind -M insert -k up _atuin_bind_up/) print "bind -M insert up _atuin_bind_up"; else print $0 }' | source
end
