#!/bin/bash
# Module: bar-pikabar — chill-dots' pikabar look, applied as a thin overlay on
# top of whichever pikabar the system already has.
#
# /usr/bin/pikabar hands quickshell one whole config tree and nothing else:
# ~/.config/pikabar-quickshell if that directory exists, /usr/share/pikabar
# otherwise. There is no include, no merge, no drop-in — so changing a single
# QML file means owning the entire tree.
#
# Vendoring all 4.9MB of upstream QML would freeze the bar at whatever pikabar
# version it was copied from, and quietly undo upstream fixes on every install.
# Instead this module seeds the fork from the *installed* /usr/share/pikabar and
# then overlays only the handful of files chill-dots actually changes:
#
#   * Bar/Bar.qml            — translucent bar background driven by
#                              Settings.barOpacity, plus a hairline bottom
#                              border so the bar stays defined over bright
#                              wallpapers
#   * Settings/Settings.qml  — declares the barOpacity property
#   * Settings/IconPalette.qml — a semantic status palette (battery green→red,
#                              wifi cyan→amber, and so on). Deliberately NOT in
#                              Theme.json: pikabar regenerates that file from
#                              the wallpaper on every change, so anything put
#                              there is lost within twenty minutes.
#   * Bar/Modules/*.qml, Widgets/Notification/NotificationIcon.qml
#                            — read their colours from IconPalette
#
# Because the overlay is QML patched against a specific upstream, the version it
# was written against is recorded below. A mismatch warns loudly rather than
# silently shipping files that may not fit.

register_module bar-pikabar "pikabar: translucent bar + semantic icon colours" na on

PIKABAR_SYS="/usr/share/pikabar"
PIKABAR_FORK="$HOME/.config/pikabar-quickshell"

# Upstream this overlay was diffed against. Bump it when re-syncing the QML —
# see "Re-syncing the pikabar overlay" in the README.
PIKABAR_OVERLAY_FOR="2.0.7-101pika1"

# The files chill-dots owns inside the fork, relative to the tree root.
PIKABAR_OVERLAY_FILES=(
    Bar/Bar.qml
    Bar/Modules/Battery.qml
    Bar/Modules/Bluetooth.qml
    Bar/Modules/Brightness.qml
    Bar/Modules/SystemInfo.qml
    Bar/Modules/Volume.qml
    Bar/Modules/Wifi.qml
    Settings/IconPalette.qml
    Settings/Settings.qml
    Widgets/Notification/NotificationIcon.qml
)

mod_bar_pikabar_deploy() {
    if [[ ! -d "$PIKABAR_SYS" ]]; then
        warn "No pikabar found at $PIKABAR_SYS — skipping the bar overlay"
        return 0
    fi

    pikabar_check_version
    pikabar_seed_fork || return 0

    local rel src
    for rel in "${PIKABAR_OVERLAY_FILES[@]}"; do
        src="$SCRIPT_DIR/configs/pikabar-quickshell/$rel"
        # An overlay file with no counterpart upstream is a re-sync that went
        # wrong; say so instead of writing a file quickshell may not load.
        if [[ ! -f "$PIKABAR_SYS/$rel" && "$rel" != Settings/IconPalette.qml ]]; then
            warn "$rel is not in this pikabar — the overlay may be out of date"
        fi
        deploy "$src" "$PIKABAR_FORK/$rel"
    done
}

mod_bar_pikabar_post() {
    [[ -d "$PIKABAR_SYS" ]] || return 0
    [[ "$DRY_RUN" == 1 ]] && return 0

    if pgrep -x quickshell >/dev/null 2>&1; then
        info "quickshell watches its QML and reloads it, so the bar should already have changed."
        info "  If it hasn't: pkill -x quickshell && setsid pikabar >/dev/null 2>&1 &"
    fi
    return 0
}

# ------------------------------------------------------------------ helpers ----

pikabar_version() {
    dpkg-query -W -f='${Version}' pikabar 2>/dev/null || true
}

pikabar_check_version() {
    local have
    have="$(pikabar_version)"
    [[ -z "$have" || "$have" == "$PIKABAR_OVERLAY_FOR" ]] && return 0
    warn "Overlay was written against pikabar $PIKABAR_OVERLAY_FOR, but $have is installed."
    warn "  Your existing files are backed up, so --rollback undoes this if the bar breaks."
}

# Seed ~/.config/pikabar-quickshell from the installed pikabar. Only ever done
# when the fork is absent — an existing fork is the user's, and the overlay
# files get backed up individually by deploy() rather than the tree being reset.
pikabar_seed_fork() {
    if [[ -d "$PIKABAR_FORK" ]]; then
        skip "pikabar fork already exists at ~/.config/pikabar-quickshell"
        return 0
    fi
    if [[ "$DRY_RUN" == 1 ]]; then
        dry "Would copy $PIKABAR_SYS ($(find "$PIKABAR_SYS" -type f 2>/dev/null | wc -l) files) to ~/.config/pikabar-quickshell"
        CHANGES=$((CHANGES + 1))
        return 0
    fi

    # created-tree, not 89 individual records: rollback removes the whole seeded
    # copy in one step, and only because this run is what created it.
    journal created-tree "$PIKABAR_FORK"
    mkdir -p "$PIKABAR_FORK"
    if ! cp -a "$PIKABAR_SYS/." "$PIKABAR_FORK/" 2>/dev/null; then
        err "Could not copy $PIKABAR_SYS into ~/.config/pikabar-quickshell"
        return 1
    fi
    CHANGES=$((CHANGES + 1))
    local ver
    ver="$(pikabar_version)"
    ok "Seeded ~/.config/pikabar-quickshell from pikabar ${ver:-(unknown version)}"
    return 0
}
