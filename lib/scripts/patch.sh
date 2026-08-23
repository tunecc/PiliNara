#!/usr/bin/env bash
# patch.sh — lib/scripts/patch.ps1 的 iOS shell 移植版 + 本地 iOS 26 隔离
# 给没装 PowerShell(pwsh) 的环境用,行为对齐 patch.ps1 的 iOS 分支:
#   1. 给 PiliPlus 仓库应用 iOS 仓库内 patch(bottom_sheet_ios_piliplus / geetest_ios)
#   2. 给 Flutter SDK 本体应用 lib/scripts 下的全部 iOS patch
#   3. 给 ~/.pub-cache 里的插件源码应用 iOS 26 API 隔离 patch(本机 Xcode 16.4 专用)
#
# 用法: bash lib/scripts/patch.sh ios
# 前置: 需先 flutter pub get(生成 ios/Flutter/Generated.xcconfig,下载 pub-cache 包)
# 幂等: 重复运行安全,已应用的 patch 会自动跳过

set -uo pipefail

platform="${1:-ios}"
if [ "$platform" != "ios" ]; then
  echo "仅支持 ios(本 fork 只维护 iOS 本地构建): $platform"
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

# 从 Generated.xcconfig 读 FLUTTER_ROOT(与 Podfile 同样的做法)
xcconfig="ios/Flutter/Generated.xcconfig"
if [ ! -f "$xcconfig" ]; then
  echo "错误: $xcconfig 不存在,请先运行 flutter pub get"
  exit 1
fi
flutter_root="$(grep '^FLUTTER_ROOT=' "$xcconfig" | cut -d= -f2-)"
if [ -z "$flutter_root" ] || [ ! -d "$flutter_root" ]; then
  echo "错误: 无法定位 FLUTTER_ROOT($flutter_root)"
  exit 1
fi
echo "Flutter SDK: $flutter_root"

applied=0
skipped=0

apply() { # apply <patch路径> <工作目录> <描述>
  local patch_file="$1" workdir="$2" desc="$3"
  if (cd "$workdir" && git apply --check "$patch_file" 2>/dev/null); then
    (cd "$workdir" && git apply "$patch_file")
    echo "  applied   $desc"
    applied=$((applied + 1))
  else
    echo "  skip      $desc(已应用或上下文变化)"
    skipped=$((skipped + 1))
  fi
}

# apply_pub:对 ~/.pub-cache 里的非 git 包用 patch 命令(无 a/b 前缀,-p0)
apply_pub() { # apply_pub <patch路径> <包目录> <描述>
  local patch_file="$1" pkgdir="$2" desc="$3"
  if [ ! -d "$pkgdir" ]; then
    echo "  skip      $desc(包不存在:$pkgdir,请先 flutter pub get)"
    skipped=$((skipped + 1))
    return
  fi
  if (cd "$pkgdir" && patch --dry-run --forward -p0 < "$patch_file" >/dev/null 2>&1); then
    (cd "$pkgdir" && patch --forward -p0 < "$patch_file")
    echo "  applied   $desc"
    applied=$((applied + 1))
  else
    echo "  skip      $desc(已应用或版本不匹配)"
    skipped=$((skipped + 1))
  fi
}

# ── 1. PiliPlus 仓库内 patch(iOS 必需) ──────────────────────────
echo "[1/3] 仓库内 patch:"
for p in bottom_sheet_ios_piliplus geetest_ios; do
  apply "$repo_root/lib/scripts/$p.patch" "$repo_root" "$p.patch"
done

# ── 2. Flutter SDK 本体 patch(与 patch.ps1 的 iOS 集合一致) ────
echo "[2/3] Flutter SDK patch:"
sdk_patches=(
  # 全平台通用
  modal_barrier text_selection mouse_cursor image_anim layout_builder
  navigation_drawer popup_menu fab null_safety_for_selectable_region
  selectable_region editable_text text_field scroll_position scrollable
  scrollable_gesture draggable_scrollable_sheet scaffold text text_painter
  sliver refresh_indicator
  # iOS 专属
  scroll_view bottom_sheet_ios_flutter navigator
)
for p in "${sdk_patches[@]}"; do
  apply "$repo_root/lib/scripts/$p.patch" "$flutter_root" "$p.patch"
done

# ── 3. pub-cache 插件 iOS 26 API 隔离(本机 Xcode 16.4 专用) ──────────
echo "[3/3] pub-cache iOS 26 隔离:"
# device_info_plus 13.0.0 的 iOS 插件调用 NSProcessInfo.isiOSAppOnVision(iOS 26 API),
# 本机 iOS 18.5 SDK 无此 selector → 注释掉该块,固定 isiOSAppOnVision=NO。
dip_pkg="$(find "$HOME/.pub-cache" -maxdepth 3 -type d -name 'device_info_plus-13.0.0' 2>/dev/null | head -1)"
apply_pub "$repo_root/lib/scripts/device_info_ios26_isolate.patch" "$dip_pkg" "device_info_plus-13.0.0 iOS26"

echo ""
echo "完成: applied=$applied skipped=$skipped"
echo "SDK 改动文件数: $(git -C "$flutter_root" status --short 2>/dev/null | wc -l | tr -d ' ')"
echo "提示: 要还原 SDK,运行 git -C '$flutter_root' reset --hard"
