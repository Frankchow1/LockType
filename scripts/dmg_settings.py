# dmgbuild 配置：无需 Finder，直接写 .DS_Store 生成带背景图与图标布局的 dmg
# 由 build.sh 通过环境变量传入路径：DMG_APP / DMG_TXT / DMG_BG
import os

app_path = os.environ["DMG_APP"]
txt_path = os.environ["DMG_TXT"]
bg_path = os.environ.get("DMG_BG", "")

app_name = os.path.basename(app_path)   # LockType.app
txt_name = os.path.basename(txt_path)   # 首次打不开-点我看说明.txt

# ---- 镜像内容 ----
files = [app_path, txt_path]
symlinks = {"Applications": "/Applications"}

# ---- 格式 ----
format = "UDZO"
compression_level = 9

# ---- 窗口与图标布局（与背景图坐标对应）----
# 窗口内容区 640x480；坐标系原点左上，y 向下
window_rect = ((200, 120), (640, 480))
default_view = "icon-view"
icon_size = 96
text_size = 12
show_icon_preview = False
include_icon_view_settings = True
arrange_by = None

if bg_path and os.path.exists(bg_path):
    background = bg_path

icon_locations = {
    app_name: (155, 175),
    "Applications": (485, 175),
    txt_name: (320, 452),
}
