# 候选音频包：木质玩具 + 纸笔

本目录中的 `candidates/*.wav` 是第一轮游戏音效素材，由 `scripts/audio_controller.gd` 统一接入游戏事件。

| 文件 | 建议场景 |
| --- | --- |
| `metal_mark_01.wav` / `metal_mark_02.wav` | 低亮度、短尾音的软金属落笔声，标记普通 X；两个轻微音高版本保持同一触感 |
| `paper_erase.wav` | 与落 X 响度和时长接近的轻纸面擦除声，取消普通 X |
| `wood_correct.wav` | 正确放置小狮子皇冠 |
| `wood_correct_final.wav` | 最后一只小狮子的短确认，给完整通关旋律留出空间 |
| `wood_hint.wav` | 使用逻辑提示 |
| `paper_clear.wav` | 多次橡皮擦纸，使用免费清除 |
| `wood_victory_v2.wav` | 与棋盘 2.3 秒庆祝时间轴同步的通关结算 |
| `wood_ui_tap.wav` | 普通轻量 UI 点击候选 |
| `wood_wrong_heart.wav` | 错误皇冠与红心损失合并反馈，避免两段高音量音效相互覆盖 |
| `crown_reveal.wav` | 皇冠直找揭示，强于普通正确放置但弱于通关 |
| `block_pickup_01.wav` / `block_pickup_02.wav` | 拼块超过拖动阈值后拿起，按块大小微调音高 |
| `block_snap.wav` | 拖动进入新的合法吸附点，带独立节流 |
| `block_place_small.wav` / `medium` / `large` | 小、中、大块成功落位，块越大声音越沉 |
| `block_reject.wav` | 无效释放或控制器拒绝放置 |
| `block_return.wav` | 已放方块返回托盘空槽 |
| `block_region_complete.wav` | 一个待拼颜色区域的全部方块完成 |
| `block_deadlock.wav` | 拼块死局确认 |
| `block_revive.wav` | 自动放回最后一块并解除死局 |
| `block_assembly_complete.wav` | 全部拼块完成并进入 0.88 秒压平转换 |
| `block_clear.wav` | 一次清除所有已放置方块 |
| `result_cheerful.wav` | EXCELLENT 专用欢快音乐；短尾卡林巴主旋律、大三度回应与强弱交替的低木质节拍形成轻快弹跳感，不使用沙锤、刷奏或擦奏噪声，后段主动留白给金币音效 |
| `coin_arrive.wav` / `coin_reel.wav` / `coin_settle.wav` | 阻尼金币落槽、单次系统选择器式滚轮刻度和低频停止锁定；刻度由实际数字步进事件驱动 |

技术规格：`44.1kHz / 16-bit / mono WAV`。生成脚本为 `tools/generate_audio_sfx.py`，固定随机种子，重复运行可得到一致结果。

重新生成：

```bash
python3 tools/generate_audio_sfx.py --output assets/audio/candidates
```

页面脚本只调用语义化播放方法，音频加载、随机变体、滑动/吸附节流和并发播放统一由音效控制器处理。运行时分为 `GameplaySFX`、`UISFX` 和 `CelebrationSFX` 三组播放器池，普通操作不得截断通关或拼块完成的尾音。

EXCELLENT 结算延迟加载 `result_cheerful.wav`，并依次执行“音乐与约 4.8 秒撒花同步开始，花瓣从顶部向下飘至小狮子处渐隐 → 立即飞币并播放阻尼落槽声 → 最后一枚到达后立即滚动数字，每个真实可视步播放一次短选择器刻度 → 最后一格播放低频锁定并淡出音乐”。视觉阶段之间不插入人工空白，滚轮刻度按照 Tween 的实际减速节奏触发，不使用与画面脱节的固定连续录音。GOOD 不播放庆祝音乐。所有素材由同一生成脚本使用固定种子生成，不依赖外部音乐版权。

庆祝音乐不叠加沙锤、刷奏、擦奏或带通噪声节拍，避免手机扬声器把高频颗粒放大成不舒服的周期性摩擦声。
