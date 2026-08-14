# 候选音效包：木质玩具 + 纸笔

本目录中的 `candidates/*.wav` 是第一轮游戏音效素材，由 `scripts/audio_controller.gd` 统一接入游戏事件。

| 文件 | 建议场景 |
| --- | --- |
| `metal_mark_01.wav` / `metal_mark_02.wav` | 短促、干净的小金属敲击声，标记普通 X，随机使用两个版本 |
| `paper_erase.wav` | 橡皮擦纸，取消普通 X |
| `wood_correct.wav` | 正确放置小狮子皇冠 |
| `wood_correct_final.wav` | 最后一只小狮子的短确认，给完整通关旋律留出空间 |
| `wood_wrong.wav` | 错误放置反馈 |
| `wood_heart_lost.wav` | 失去一颗红心 |
| `wood_hint.wav` | 使用逻辑提示 |
| `paper_clear.wav` | 多次橡皮擦纸，使用免费清除 |
| `wood_victory_v2.wav` | 与棋盘 2.3 秒庆祝时间轴同步的通关结算；旧版 `wood_victory.wav` 保留作对照 |
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
| `result_lion_nature_v2.wav` | 原创生成的 4.2 秒结算短曲；卡林巴、木琴和轻木质打击按“小狮子出现—金币飞入—余额滚动—温暖落点”形成起伏旋律 |
| `result_tutorial_soft.wav` | 教程完成的 2.35 秒柔和简版，不使用成功页完整奖励乐句 |
| `coin_arrive.wav` / `coin_reel.wav` / `coin_settle.wav` | 金币飞入落点、余额滚筒和最终停止确认；飞入声最多三次 |

技术规格：`44.1kHz / 16-bit / mono WAV`。生成脚本为 `tools/generate_audio_sfx.py`，固定随机种子，重复运行可得到一致结果。

重新生成：

```bash
python3 tools/generate_audio_sfx.py --output assets/audio/candidates
```

页面脚本只调用语义化播放方法，音频加载、随机变体、滑动/吸附节流和并发播放统一由音效控制器处理。运行时分为 `GameplaySFX`、`UISFX` 和 `CelebrationSFX` 三组播放器池，普通操作不得截断通关或拼块完成的尾音。

成功结算背景音乐约 `4.2s`，单次播放且不循环；教程完成使用独立柔和简版，失败和死局保持安静。成功页由金币余额滚筒的 `roll_finished` 事件触发两段式淡出：第一段从当前增益继续下降，绝不先反向增响，再用约 `0.6s` 缓慢消失；离开结算页时统一提前淡出。素材由同一生成脚本使用固定种子生成，不依赖外部音乐版权。
