# dmgbuild settings for StillOnMac.dmg. make-dmg.sh passes:
#   -D app=<path to .app> -D background=<tiff/png> -D icon=<volume .icns>
# `defines` is provided by dmgbuild.
import os.path

application = defines.get("app", "build/StillOnMac.app")  # noqa: F821
appname = os.path.basename(application)

format = "UDZO"
filesystem = "HFS+"
size = None

files = [application]
symlinks = {"Applications": "/Applications"}

_icon = defines.get("icon")  # noqa: F821
if _icon and os.path.exists(_icon):
    icon = _icon

_background = defines.get("background")  # noqa: F821
background = _background if _background and os.path.exists(_background) else "builtin-arrow"

# Window: 600x400, icons only, no toolbar or sidebar.
window_rect = ((200, 120), (600, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = False
include_icon_view_settings = True

arrange_by = None
label_pos = "bottom"
text_size = 13
icon_size = 112
icon_locations = {
    appname: (150, 200),
    "Applications": (450, 200),
}
