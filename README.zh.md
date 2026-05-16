# hello-its-me

[English](./README.md) | **中文** | [更新日志](https://github.com/SeanLearningAccount/hello-its-me/releases)

为 Claude Code 添加音效提醒：完成任务、需要授权、出错时分别播放对应音效。基于 Claude Code 官方的 hooks 机制实现。

---

## 这是什么

hello-its-me 响应 Claude Code 的四种事件，并播放对应音效：

| 菜单显示名 | settings.json 中的 hook 名 | 触发时机 |
|---|---|---|
| **Notification** | `Notification` | 空闲提醒——约 60 秒无操作后触发一次 |
| **Permission** | `PermissionRequest` | Claude Code 需要你确认操作，例如"Do you want to proceed?" |
| **Complete** | `Stop` | Claude 完成一次回答 |
| **Error** | `StopFailure` | Claude 异常终止 |

> 说明：本项目在菜单和文档中使用 **Complete / Error** 作为更直观的展示名，对应到 Claude Code 官方的 hook 名分别是 `Stop` 和 `StopFailure`。如果你直接查看 `~/.claude/settings.json`，看到的是后者。

音效通过 macOS 自带的 `afplay` 播放，与系统其它音频共享输出通道。

---

## 安装

### 前提条件

- **macOS**（暂不支持其它系统）
- **Claude Code** 已安装：https://github.com/anthropics/claude-code
- **zsh**（macOS 默认 shell）。安装脚本会在 `~/.zshrc` 注册命令
- **python3**（安装脚本依赖）。macOS 通常已自带；如提示找不到，运行 `xcode-select --install`
- **推荐安装 sox**（用于读取音频时长，详见下方"关于 sox"）：
  ```bash
  brew install sox
  ```

### 步骤

1. 获取代码：clone 或下载这个 repo 到本地，进入项目目录。

2. 执行安装脚本：
   ```bash
   bash install.sh
   ```
   过程中会列出可选音效，依次为三种事件试听并选择。

3. 让 `its-me` 命令生效：
   ```bash
   source ~/.zshrc
   ```
   或新开一个终端窗口。

### 安装做了什么

安装脚本只动以下三处，每处修改前都会备份为 `.bak.<时间戳>`：

- **创建** `~/.claude-sounds/`，把默认音效文件复制进去
- **修改** `~/.claude/settings.json`，注册四个 hook。如果你已有 `Notification`、`PermissionRequest`、`Stop` 或 `StopFailure` 的 hook 配置，会被覆盖（修改前会先备份）。
- **修改** `~/.zshrc`，添加 `its-me` 命令别名

> **注意**：`play.sh` 保留在项目目录里。安装完成后如果移动或删除项目文件夹，hook 会静默失效。重新运行 `bash install.sh` 可以恢复。

完全可逆。卸载会清理主体内容，操作前创建的备份文件会保留，卸载完成后终端会提示具体位置。

---

## 使用

### 启动菜单

```bash
its-me
```

显示如下：

```
  hello, it's me
  ─────────────────────

  Current sounds:
    Notification → notification-2.wav
    Complete     → complete-3.wav
    Error        → error-1.wav

    1. Test sounds
    2. Change sounds
    3. How to add custom sound
    0. Exit

    u. Uninstall

  Select:
```

顶部 **Current sounds** 显示当前各事件绑定的音效文件名。

### 切换音效

选择 `2. Change sounds` → 选择要修改的事件 → 在列表中选择音效预览 → 按 `y` 确认。

修改即时写入 `~/.claude/settings.json`，下一次事件触发就生效，不需要重启 Claude Code。

### 添加自定义音效

把音频文件放进：

```
~/.claude-sounds/
```

支持 **WAV** 和 **MP3**。文件名没有强制要求，但建议按用途加前缀，方便管理：

- `notification-*.wav` — 通知类
- `complete-*.wav` — 完成类
- `error-*.wav` — 错误类

放进去后，进入 `2. Change sounds` 就能看到新音效，选用即可。

---

## 工作原理

### Claude Code 的 hooks 机制

Claude Code 在特定事件发生时（例如完成回答、需要权限确认），会执行 `~/.claude/settings.json` 里 `hooks` 字段配置的命令。这是官方提供的扩展点。

hello-its-me 把四种事件分别绑到同一个播放脚本，只是传不同的音效文件参数：

```json
{
  "hooks": {
    "Notification":     [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/notification.wav" }] }],
    "PermissionRequest":[{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/notification.wav" }] }],
    "Stop":             [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/complete.wav" }] }],
    "StopFailure":      [{ "matcher": "", "hooks": [{ "type": "command", "command": "bash /path/to/play.sh /path/to/error.wav" }] }]
  }
}
```

### play.sh 做的事

收到事件后，`scripts/play.sh` 会：

1. 调用 `scripts/detect-duration.sh` 检测音频时长（依赖 sox 或 ffmpeg，见下节）
2. 如果时长 ≤ 3 秒：**播放两次**，中间间隔 0.3 秒（短音效播一次容易听漏）
3. 如果时长 > 3 秒：**播放一次**
4. 使用 macOS 自带的 `afplay` 播放，每次最长播放 4 秒。超过 4 秒的音效会被截断——这是有意为之，避免通知音效过长。

---

## 关于 sox

### 为什么需要

`play.sh` 要判断"这个音效要不要重复播两次"，就必须知道它的时长。读取音频时长这件事 macOS 自带工具做不到，需要外部工具。本项目支持两种：

- **`soxi`**（来自 sox 包）— 推荐
- **`ffprobe`**（来自 ffmpeg 包）— 备选

只要装了其中任意一个，duration 检测就能正常工作。

### 不装会怎样

`detect-duration.sh` 会回退到硬编码值 `999`（表示"很长"），所以**所有音效都只会播放一次，不会播放两次**。

如果你选用的音效本来就 > 3 秒，或者你不需要播放两次的效果，可以不装。否则建议装 sox。

### sox 还是 ffmpeg

| | sox | ffmpeg |
|---|---|---|
| 安装体积 | ≈ 5 MB | ≈ 80 MB 起，外加大量依赖 |
| 用途 | 专门处理音频，本项目只用它读时长 | 通用音视频处理工具，本项目仅用到时长读取功能 |
| 推荐场景 | 系统里**没**装 ffmpeg | 系统里**已**装 ffmpeg |

如果你已经装了 ffmpeg，不必再装 sox；本项目会自动 fallback 到 ffprobe。否则装 sox 更轻：

```bash
brew install sox
```

---

## 已知问题 / Troubleshooting

### 音效被背景音乐盖过

如果同时有其他软件在播放音频，音效可能会听不清楚。
建议选择更响亮的音效，或暂时调低背景音乐音量。

### 完全没声音

按以下顺序排查：

1. **系统音量**：确认未静音，音量足够。
2. **试听菜单**：运行 `its-me` → `1. Test sounds`。如果这里能响，说明音频文件和播放脚本都正常，问题在 Claude Code 的 hooks 配置。
3. **直接调用脚本**：
   ```bash
   bash scripts/play.sh ~/.claude-sounds/complete-3.wav
   ```
   如果脚本能响，但 Claude Code 触发不响，检查 `~/.claude/settings.json` 里 `hooks` 字段是否被其它工具覆盖。
4. **重装**：再跑一次 `bash install.sh`，安装脚本会重新引导你为三种事件选择音效，并覆盖现有配置（旧配置会备份为 `.bak.<时间戳>`）。

---

## 卸载

```bash
its-me
```

选择 `u. Uninstall`，会移除：

- `~/.claude-sounds/` 整个目录
- `~/.claude/settings.json` 里本项目添加的四个 hook（其它字段不动）
- `~/.zshrc` 里的 `its-me` 别名

修改前同样会先备份为 `.bak.<时间戳>`。

### 备用方式

如果 `its-me` 命令已不可用（例如别名已被手动删除），进入本项目目录，直接运行卸载脚本：

```bash
bash uninstall.sh
```

### 清理备份文件

卸载完成后，安装和卸载过程中创建的备份文件会保留在系统里，终端会列出它们的具体路径。如不需要，可以手动删除：

```bash
rm ~/.claude/settings.json.bak.* ~/.zshrc.bak.*
```

这些文件以 `.` 开头，在 Finder 里默认不可见。如需用 Finder 操作，按 `Cmd + Shift + G` 前往 `~/.claude` 和 `~` 目录，再按 `Cmd + Shift + .` 显示隐藏文件，找到所有 `.bak.*` 文件删除即可。

---

## License

MIT
