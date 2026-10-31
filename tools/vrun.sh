#!/bin/bash
# Run Godot with a real window inside a private virtual KWin (works when the desktop does not deliver frames).
# usage: tools/vrun.sh <godot args...>      (Vulkan Forward+; default scene res://scenes/main.tscn)
inner=$(mktemp /tmp/vrunXXXX.sh)
cat > "$inner" <<EOF
#!/bin/bash
exec flatpak run --socket=wayland --env=WAYLAND_DISPLAY=\$WAYLAND_DISPLAY org.godotengine.Godot --display-driver wayland --rendering-method forward_plus --path $(dirname "$0")/.. $@
EOF
chmod +x "$inner"
timeout ${VRUN_TIMEOUT:-120} kwin_wayland --virtual --no-lockscreen --width 1280 --height 720 --socket wl-arena-$$ "$inner"
rm -f "$inner"
