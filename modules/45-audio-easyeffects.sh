#!/bin/bash
# Module: audio-easyeffects — the EasyEffects sound profile (equalizer,
# convolver with the Dolby impulse responses, limiter, autogain, multiband
# compressor, bass enhancer) plus the PipeWire tweak that stops the analog
# speakers from suspending between sounds.
#
# EasyEffects here is the Flatpak build, so its config does NOT live in
# ~/.config/easyeffects — it lives under ~/.var/app/<app-id>/. Native
# (packaged) installs use the XDG paths instead, so the module picks the
# target from how EasyEffects is actually installed.

register_module audio-easyeffects "EasyEffects sound profile (EQ, Dolby convolver) + PipeWire tweaks" off on

EE_APP_ID="com.github.wwmm.easyeffects"

ee_is_flatpak() {
    flatpak info "$EE_APP_ID" &>/dev/null
}

# Prefer wherever EasyEffects already is; on PikaOS default to the Flatpak
# layout, which is the packaging that actually ships a current version there.
ee_use_flatpak() {
    ee_is_flatpak && return 0
    command -v easyeffects &>/dev/null && return 1
    [[ "$CDOTS_OS" == pika ]]
}

ee_config_dir() {
    if ee_use_flatpak; then
        echo "$HOME/.var/app/$EE_APP_ID/config/easyeffects"
    else
        echo "$HOME/.config/easyeffects"
    fi
}

ee_data_dir() {
    if ee_use_flatpak; then
        echo "$HOME/.var/app/$EE_APP_ID/data/easyeffects"
    else
        echo "$HOME/.local/share/easyeffects"
    fi
}

mod_audio_easyeffects_packages() {
    case "$CDOTS_OS" in
        arch) echo easyeffects ;;
        pika) ee_use_flatpak && echo flatpak || echo easyeffects ;;
    esac
}

# The autoload rule is named after the PipeWire sink it applies to, which is
# how we know which device this profile was captured on.
ee_target_sink() {
    local f
    for f in "$SCRIPT_DIR/configs/easyeffects/data/autoload/output/"*.json; do
        [[ -f "$f" ]] || continue
        basename "$f" | sed 's/:.*//'
        return 0
    done
}

mod_audio_easyeffects_deploy() {
    local config_dir data_dir src rel
    config_dir="$(ee_config_dir)"
    data_dir="$(ee_data_dir)"

    ensure_dir "$config_dir/db" "$data_dir/output" "$data_dir/irs" "$data_dir/autoload/output"

    # Plugin settings (equalizer curve, convolver choice, limiter, ...)
    for src in "$SCRIPT_DIR/configs/easyeffects/db/"*; do
        [[ -f "$src" ]] || continue
        deploy "$src" "$config_dir/db/$(basename "$src")"
    done

    # Presets, impulse responses, and the per-device autoload rule
    for rel in output irs autoload/output; do
        for src in "$SCRIPT_DIR/configs/easyeffects/data/$rel/"*; do
            [[ -f "$src" ]] || continue
            deploy "$src" "$data_dir/$rel/$(basename "$src")"
        done
    done

    # Keep the analog speakers awake — without this the amp powers down
    # between sounds and clips the start of the next one.
    deploy "$SCRIPT_DIR/configs/wireplumber/51-no-suspend-speakers.conf" \
           "$HOME/.config/wireplumber/wireplumber.conf.d/51-no-suspend-speakers.conf"

    deploy_rendered "$SCRIPT_DIR/configs/autostart/easyeffects-service.desktop" \
                    "$HOME/.config/autostart/easyeffects-service.desktop" render_easyeffects_autostart
}

# The stock entry launches the Flatpak; rewrite it for a native install.
render_easyeffects_autostart() {
    if ee_use_flatpak; then
        cat
    else
        sed 's|^Exec=.*|Exec=easyeffects --gapplication-service|'
    fi
}

mod_audio_easyeffects_post() {
    local sink
    sink="$(ee_target_sink)"

    if ee_use_flatpak && ! ee_is_flatpak; then
        if [[ "$DRY_RUN" == 1 ]]; then
            dry "Would install the EasyEffects flatpak ($EE_APP_ID)"
        elif ! command -v flatpak &>/dev/null; then
            warn "flatpak not available — install EasyEffects yourself: flatpak install flathub $EE_APP_ID"
        else
            info "Installing EasyEffects (flatpak)..."
            if flatpak install -y --user flathub "$EE_APP_ID" &>>"$PKG_LOG"; then
                journal flatpak "$EE_APP_ID"
                ok "EasyEffects installed"
            else
                warn "flatpak install failed — run manually: flatpak install flathub $EE_APP_ID (details: $PKG_LOG)"
            fi
        fi
    fi

    # The equalizer/convolver settings are captured for one specific output.
    # On any other machine the autoload rule simply never fires, which looks
    # like "the presets did nothing" — so say so up front.
    if [[ -n "$sink" && "$DRY_RUN" != 1 ]]; then
        # `grep -q` here would SIGPIPE pactl and, under pipefail, warn every
        # time — including when the sink is present. Drain the pipe instead.
        if command -v pactl &>/dev/null && ! pactl list short sinks 2>/dev/null | grep -F "$sink" >/dev/null; then
            warn "This profile autoloads for the sink '$sink', which isn't on this machine — open EasyEffects and pick the preset for your own output device"
        fi
    fi

    [[ "$DRY_RUN" == 1 ]] || info "EasyEffects reads these files at startup — restart it (or log out and back in) to hear the change"
    return 0
}
