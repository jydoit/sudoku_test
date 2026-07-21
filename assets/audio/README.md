# 候选音效包：木质玩具 + 纸笔

本目录中的 `candidates/*.wav` 是第一轮游戏音效素材，由 `scripts/audio_controller.gd` 统一接入游戏事件。

| 文件 | 建议场景 |
| --- | --- |
| `metal_mark_01.wav` / `metal_mark_02.wav` | 短促、干净的小金属敲击声，标记普通 X，随机使用两个版本 |
| `paper_erase.wav` | 橡皮擦纸，取消普通 X |
| `wood_correct.wav` | 正确放置小狮子皇冠 |
| `wood_wrong.wav` | 错误放置反馈 |
| `wood_heart_lost.wav` | 失去一颗红心 |
| `wood_hint.wav` | 使用逻辑提示 |
| `paper_clear.wav` | 多次橡皮擦纸，使用免费清除 |
| `wood_victory.wav` | 通关结算 |
| `wood_ui_tap.wav` | 普通轻量 UI 点击候选 |

技术规格：`44.1kHz / 16-bit / mono WAV`。生成脚本为 `tools/generate_audio_sfx.py`，固定随机种子，重复运行可得到一致结果。

重新生成：

```bash
python3 tools/generate_audio_sfx.py --output assets/audio/candidates
```

页面脚本只调用语义化播放方法，音频加载、随机变体、滑动节流和并发播放统一由音效控制器处理。
