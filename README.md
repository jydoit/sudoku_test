# color king（Godot MVP）

一款竖屏休闲逻辑谜题原型。玩家需要在彩色区域棋盘上找出小狮子，同时满足每行、每列、每个颜色区域各一个小狮子，且小狮子不能八方向相邻。

## 当前版本改动

本仓库基于 `jydoit/sudoku_test` 扩展，当前版本主要做了这些更新：

### 2026-07-23 主要更新

- 重新统一 PRD、UI 规范、项目约束和 README，清理旧的皇冠、清除/撤销、金币复活、旧色板和旧提示样式描述。
- 棋盘 UI 按最新规则落地：白色底板，10 色亮色板，棋盘最外框不画深色线，不同颜色区域之间不画深色线，所有格子之间保留白色格间距，并加重底纹可见度。
- 已确认小狮子、提示小狮子、开局小狮子和错误红 X 全部锁定；普通 X 仍可单击或滑动取消。
- 正式关卡提示改为半透明白灰蒙层：提示相关格和已有标记保持正常亮度，非提示区域不可点击，不显示解释文案，不加高亮框、不闪烁。
- 补齐反馈表现：正确找到小狮子有弹性出现动效，错误红 X 有短震动反馈，停顿思考约 8 秒后已出现的小狮子会轻微摇头。
- 重新生成 Android 调试包：`builds/color_king-debug.apk`。

### 累计功能更新

- App 名称和首页主视觉更新为 `color king`
- 首页改为与关卡结果页一致的蓝色主色系，突出胜利小狮子主视觉、开始关卡和新人引导入口
- 关卡页保留核心棋盘规则，并提供返回首页、金币、红心、帮助、设置和选关入口
- 棋盘底色为白色；棋盘最外缘不使用深色边框，不同颜色区域之间无深色分割线，所有格子之间保留白色格间距，并为 10 个颜色加入更明显的底纹
- 正式关卡底部只显示“小狮子”和“提示”两个道具按钮
- 正式关卡按标准答案判定小狮子尝试；非答案格会扣除红心并标记不可修改的红色 X
- 失败页返回首页后，再次点击开始关卡会重新开始当前关卡，恢复红心并清空本次失败局的错误红 X
- 小狮子视觉统一使用戴皇冠的小狮子贴图，正确小狮子、提示小狮子、开局小狮子和结算页使用同一角色体系
- 小狮子和提示按钮：用户各初始 3 次，次数最低显示 `×0`；免费次数用完后点击会弹出购买金币 / 观看激励广告获取积分入口，不直接扣金币
- 正式关卡提示使用整盘半透明白灰浮层弱化非提示空格；新手教程的相邻与行列排除不加蒙层，同阶段全部合法格显示金色细边并支持连续滑动标记 X
- 正式关卡提示不显示解释文字，只通过棋盘可操作范围表达，提示目标只包含可画普通 X 的非小狮子格
- 新手教程道具计数不显示无限；非教学阶段为空，引导点击提示或小狮子时显示 `×1`，点击后显示 `×0`
- 关卡结果页改为蓝色整屏奖励页：顶部显示“太棒了！/ 第 X 关 已完成”，中部显示胜利小狮子，底部保留“下一关”和“主菜单”
- 关卡失败页沿用蓝色整屏结构，中部显示失败小狮子，提供“重新挑战”和“返回首页”
- 金币经济由关卡尺寸、开局提示小狮子、错误次数和后续道具获取入口共同决定
- 新增多语言、统一游戏内弹窗、音效反馈、Noto Sans 字体和 UI 设计规范
- 关卡结果页不显示排行榜、奖励进度栏和广告位
- 默认关卡扩展到 1670 个，覆盖 5×5 到 9×9 唯一解关卡
- 关卡均标记难度：新手、普通、困难、专家
- 每关预置 `hintSteps` 和完整 `solveSteps`，标记为 `no_guess`，用于记录无需猜测的逻辑解题路径
- 关卡页顶部提供选关入口，使用每页 20 关、每行 5 个的大触控数字宫格，并以数据 `levelId` 统一列表、标题和存档编号
- 增加内置关卡编辑器，可编辑关卡名称、提示文字、颜色区域和答案点位
- 增加编辑器入口按钮，可从主界面进入编辑器
- 更新冒烟测试，覆盖关卡数据结构、答案合法性、唯一解和无猜解题路径检查
- 新增编辑器冒烟测试，验证编辑器加载、涂色和答案模式切换

## 当前版本改动

本仓库基于 `jydoit/sudoku_test` 扩展，当前版本主要做了这些更新：

- 关卡页保留原棋盘规则，并提供返回首页入口
- 默认关卡从 5 个扩展到 50 个，全部为 6×6 唯一解关卡
- 50 个关卡均标记难度：新手、普通、困难、专家
- 每关预置 `hintSteps` 和完整 `solveSteps`，标记为 `no_guess`，用于记录无需猜测的逻辑解题路径
- 顶部增加关卡下拉选择，方便调试和快速切换关卡
- 增加内置关卡编辑器，可编辑关卡名称、提示文字、颜色区域和答案点位
- 增加编辑器入口按钮，可从主界面进入编辑器
- 更新冒烟测试，覆盖 50 关数据结构、答案合法性、唯一解和无猜解题路径检查
- 新增编辑器冒烟测试，验证编辑器加载、涂色和答案模式切换

## 运行

项目基于 **Godot 4.7**。使用 Godot Project Manager 导入根目录的 `project.godot`，然后点击运行即可。

macOS 也可以直接执行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --editor --path .
```

无界面启动检查：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5
```

完整冒烟测试：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tests/smoke_test.gd
```

## 项目规范入口

新建 Codex 对话、接手开发或发布前，先读取这些文件：

- `AGENTS.md`：项目管控规则、分支规则、必读文档、测试与 UI 验收要求。
- `docs/PRODUCT_REQUIREMENTS.md`：PRD、玩法、经济、关卡、提示、发布前回归清单。
- `docs/UI_DESIGN_GUIDE.md`：UI 规范、棋盘视觉标准、结果页规范、打包/发布前 UI 视觉验收标准。
- `docs/CODEX_TODO.md`：后续待办和仍需优化的事项。
- `docs/VERSION_HISTORY.md`：已完成的功能进展、问题修复、验证结果和重要流程变化。
- `tools/capture_ui_screenshots.gd`：生成 540×960 移动端尺寸 UI 截图的验收脚本。

涉及产品方案、UI、玩法逻辑、经济、关卡、提示、音效或动效的变更，必须先对照 PRD、UI 规范、README 和项目约束文件，向用户说明影响范围并得到确认；修改后同步更新这些文档，完成测试和截图验收后再打包。

每次代码改动后至少运行核心冒烟测试和新手教程冒烟测试：

```bash
HOME=/private/tmp/color_king_smoke /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/smoke_test.gd
HOME=/private/tmp/color_king_tutorial /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/tutorial_smoke_test.gd
```

发布前可使用统一入口运行核心、教程和编辑器测试，并生成可留档报告：

```bash
tools/run_release_validation.sh
```

统一入口同时运行当前存档重启恢复和旧版本存档迁移测试；测试日志中的 GDScript
断言或解析错误会被视为失败，不再只依赖 Godot 进程退出码。

如需同时生成 540×960 视觉回归截图：

```bash
tools/run_release_validation.sh --visual
```

PRD 第 8 节按功能模块维护稳定测试用例编号；自动测试、视觉截图和 Android
真机报告必须引用这些编号。Godot 截图、Android 模拟器和真机是三个独立验证层级，
正式发布必须留存本次 APK 校验值及真机或认可云真机的验证证据。

涉及 UI 改动时，还需要按 `docs/UI_DESIGN_GUIDE.md` 的验收清单生成运行截图；移动端尺寸截图可用：

```bash
HOME=/private/tmp/color_king_ui_capture /Applications/Godot.app/Contents/MacOS/Godot --display-driver macos --rendering-driver opengl3 --resolution 540x960 --path . --script tools/capture_ui_screenshots.gd
```

Android 真机验收需要手机开启开发者选项和 USB 调试，并连接到电脑后确认：

```bash
/Users/shingo_mac/Documents/Codex/android_toolchain/android-sdk/platform-tools/adb devices
```

如果要做自动安卓模拟器验收，需要 Android SDK 的 `emulator` 组件、一个 Android 系统镜像，并用 `avdmanager` 创建 AVD。当前本机工具链已安装 `adb`、build-tools、platform android-35、emulator、Android 30 Google APIs x86_64 系统镜像，并创建了 `color_king_api30` AVD。JDK 路径为 `/Users/shingo_mac/Documents/Codex/android_toolchain/jdk/jdk-17.0.19+10/Contents/Home`。

本地模拟器使用 x86_64 系统镜像，Android 调试包需要同时启用 `arm64-v8a` 和 `x86_64`。真机安装主要使用 `arm64-v8a`，模拟器自动验收使用 `x86_64`。

启动当前自动验收模拟器：

```bash
ANDROID_HOME=/Users/shingo_mac/Documents/Codex/android_toolchain/android-sdk ANDROID_SDK_ROOT=/Users/shingo_mac/Documents/Codex/android_toolchain/android-sdk JAVA_HOME=/Users/shingo_mac/Documents/Codex/android_toolchain/jdk/jdk-17.0.19+10/Contents/Home /Users/shingo_mac/Documents/Codex/android_toolchain/android-sdk/emulator/emulator -avd color_king_api30 -no-window -no-audio -no-boot-anim -gpu swiftshader_indirect -no-snapshot-save
```

## 已实现

- 竖屏移动端 UI：首页、关卡页、新手引导、提示交互和通关结果页
- 休闲闯关首页：`color king` 主视觉、当前关卡入口和新人引导入口
- JSON 关卡加载，内置 1670 个 5×5 到 9×9 唯一解关卡
- 棋盘交互：单击标记/取消排除 X，双击尝试小狮子；确认的小狮子会锁定，非标准答案格会扣除红心并标记不可修改的红色 X
- 移动端棋盘输入使用自定义触控防抖：单击不会误触发双击，Android 兼容鼠标重复事件不会重复执行操作
- 隐藏的兼容撤销逻辑也不会移除任何锁定小狮子或错误红 X；新手教程不再进入旧撤销/清除教学流程
- 棋盘视觉：白色底板、整数像素对齐，10 色明亮色板，棋盘外缘不画深色边框，不同颜色区域之间无深色分割线，所有格子之间保留白色格间距，并带更明显的底纹
- 行、列、颜色区域和八方向相邻的即时冲突提示
- 正式关卡按展示关卡序号分配红心：第 1-10 关 3 个，第 11-30 关 2 个，第 31 关起 1 个；红心归零时先停顿 1.5 秒展示最后一个错误红 X，再显示失败页
- 小狮子直找和提示道具：各初始 3 次，显示次数最低为 `×0`；免费次数耗尽后点击会弹出购买金币 / 观看激励广告获取积分入口，不直接扣金币使用
- 教学提示、通关奖励、下一关、重新挑战和主菜单回流
- 正式关卡提示只给出当前可排除的非小狮子格，玩家单击目标格画普通 X 推进棋盘
- 提示支持候选锁定、成组锁定、反证排除和直接冲突排除
- 提示时非提示空格被白灰浮层弱化且不可点击，提示相关格和已有标记保持正常亮度
- 结果页：通关和失败都使用蓝色整屏反馈；通关可进入下一关或主菜单，失败可重新挑战或返回首页，返回首页后再次开始会重新挑战当前关
- 本地保存当前关卡、棋盘、金币、提示次数、小狮子直找次数、经济统计和完成记录
- 多语言与字体：随包发布 Noto Sans SC 和 Noto Sans Arabic，支持中文、英文、法语、拉丁语和阿拉伯语 RTL
- 音效反馈：普通 X、取消、正确小狮子、错误小狮子、红心损失、提示、小狮子直找和通关均有轻量音效
- 内置关卡编辑器，支持调整区域和答案点位
- 预留主题入口；棋盘和关卡结构支持任意 N×N 扩展

## 代码结构

```text
AGENTS.md                  项目协作、文档和测试规则
data/levels.json           关卡配置
docs/PRODUCT_REQUIREMENTS.md 产品需求文档与回归测试清单
docs/CODEX_TODO.md         Codex 后续优化待办记录
docs/VERSION_HISTORY.md    功能进展、问题修复和验证记录
scenes/main.tscn           主场景
scenes/level_editor.tscn   关卡编辑器场景
scripts/main.gd            UI、游戏状态、规则、存档与通关流程
scripts/game_board.gd      自绘响应式棋盘与点击反馈
scripts/coin_economy.gd    金币奖励、道具价格和经济统计
scripts/dialog_controller.gd 统一游戏内弹窗
scripts/localization_controller.gd 多语言与 RTL 控制
scripts/audio_controller.gd 音效反馈控制
scripts/ui_tokens.gd       共享 UI、棋盘和动效设计参数
scripts/level_editor.gd    关卡编辑器逻辑
scripts/level_store.gd     JSON 加载与基础数据校验
tests/smoke_test.gd        核心流程冒烟测试
tests/editor_smoke_test.gd 编辑器冒烟测试
```

新增关卡时在 `data/levels.json` 中加入配置即可。`solution` 用于提示系统和正式关卡的小狮子尝试判定；通关仍要求玩家摆放满足行、列、颜色区域和相邻规则。
