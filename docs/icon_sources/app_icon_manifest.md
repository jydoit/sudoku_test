# color king 应用图标资源清单

更新时间：2026-08-30

## 设计来源

产品评审确认的母版原图固化为 `docs/icon_sources/app_icon_reference.png`：上方是不带狮子鬃毛轮廓的彩色拼块皇冠，左下为小狮子抬手争取皇冠，背景使用蓝天、放射光芒和暖色中心光晕。正式 SVG 必须保持该母版的主体轮廓、比例、裁切、表情、拼块结构、颜色和立体材质，不允许只保留概念后重新画成另一套扁平形状。

`tools/extract_app_icon_foreground.swift` 使用 macOS Vision 的前景实例蒙版分离母版中的皇冠和角色，并按垂直质心稳定输出上方皇冠与下方狮子；`tools/build_app_icon_vectors.py` 使用 VTracer `1.0.0-alpha.3` 和固化参数，把合并主体、皇冠及狮子分别转换为纯路径 SVG，再用确定性的 SVG 渐变、光芒与闪光重建背景。母版 PNG 与三份中间提取图都不嵌入最终 SVG，也由 Android 导出过滤器排除。

## 交付资源

| 文件 | 用途 | 透明策略 |
| --- | --- | --- |
| `assets/icon.svg` | 完整合成图、旧版图标、商店预览源 | 背景完全不透明 |
| `assets/icon_foreground.svg` | Android 自适应图标前景 | 画布透明，只包含角色、皇冠和对象投影 |
| `assets/icon_background.svg` | Android 自适应图标背景 | 蓝天渐变铺满且完全不透明 |
| `assets/icon_monochrome.svg` | Android 主题图标前景 | 透明画布上的单色轮廓与必要负形 |

## 固化约束

- 统一使用 `0 0 1254 1254` 母版视图坐标；Android 前景、背景和单色层使用 `432 x 432` 固有尺寸，完整合成图使用 `1024 x 1024` 固有尺寸。
- 不嵌入 PNG/JPEG，不使用 `<text>`，不提前绘制圆角蒙版。
- 前景透明是为了让 Android 启动器组合背景、执行视差和应用设备蒙版；不是降低整个图标的不透明度。
- 背景层不得含透明像素，避免圆形或动态图标缩放时露边。
- 彩色与单色自适应前景使用相同的双组构图：皇冠应用 `translate(333 221) scale(0.546)`，狮子应用 `translate(261 169) scale(0.7)`。皇冠完整轮廓以及狮子的眼睛、口鼻和手掌进入 Android 中央 `66 x 66dp` 安全圆；狮子身体底部继续越过 `72dp` 可见区边缘，让母版原始裁切线隐藏在系统蒙版外。完整合成图和背景层不应用这两项变换。
- 单色层单独设计，不能复用彩色图的透明度或灰度结果，但皇冠与狮子必须和彩色前景分别使用相同的双组安全区构图。
- `docs/icon_sources/app_icon_mask_preview.svg` 必须组合真实的自适应前景与背景，以 `108dp` 图层对应 `72dp` 可见蒙版的比例检查圆形、圆角方形和 Squircle，不能直接裁切 `assets/icon.svg` 冒充分层预览。
- 重建命令：`VTRACER_BIN=/absolute/path/to/vtracer python3 tools/build_app_icon_vectors.py`。VTracer 二进制版本固定为 `1.0.0-alpha.3`；执行后必须重新运行 Godot 导入、蒙版预览和 Release 导出验证。
