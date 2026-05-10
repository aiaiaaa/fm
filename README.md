# X.FM HarmonyOS App

从 Taro 小程序版本迁移而来的鸿蒙原生应用（ArkTS + ArkUI，Stage 模型）。

## 工程结构

```
fm/
├── AppScope/                       # 应用级配置
│   ├── app.json5
│   └── resources/base/
│       ├── element/string.json
│       └── media/app_icon.svg
├── entry/                          # HAP 入口模块
│   ├── src/main/
│   │   ├── ets/
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets     # UIAbility 入口（沉浸式状态栏）
│   │   │   ├── services/
│   │   │   │   └── RadioPlayer.ets      # AVPlayer 封装，对应 BackgroundAudioManager
│   │   │   └── pages/
│   │   │       └── Index.ets            # 主页面（对应 index.tsx）
│   │   ├── resources/
│   │   └── module.json5                  # 声明 audioPlayback 后台模式、网络权限
│   ├── build-profile.json5
│   ├── hvigorfile.ts
│   └── oh-package.json5
├── build-profile.json5
├── hvigorfile.ts
└── oh-package.json5
```

## 小程序 → 鸿蒙 能力映射

| 原 Taro 代码                                   | 鸿蒙实现                                                                 |
|-----------------------------------------------|--------------------------------------------------------------------------|
| `Taro.BackgroundAudioManager`                 | `@ohos.multimedia.media` 的 `AVPlayer`（原生支持 HLS/m3u8）               |
| `protocol = 'hls'` + `.m3u8`                  | `AVPlayer` 设置 `url` 后自动识别 HLS                                     |
| `onWaiting/onPlay/onPause/onError`            | `avPlayer.on('stateChange')` + `on('error')`                             |
| 后台继续播放（`BackgroundAudioManager`）        | `module.json5` 中配置 `"backgroundModes": ["audioPlayback"]` +          |
|                                               | `ohos.permission.KEEP_BACKGROUND_RUNNING`                                |
| `useState / useEffect`                        | `@State` / `aboutToAppear` / `aboutToDisappear`                         |
| JSX + SCSS (View/Text/className)              | ArkUI 声明式（Column/Row/Stack/Text）+ 链式属性                          |
| CSS 流星/星星 keyframes                        | `animateTo` + `Curve.EaseInOut` + `PlayMode.Alternate`                  |
| 音波律动 15 bars CSS 动画                       | `setInterval` 驱动 `@State rhythmHeights` 的 `animateTo`                 |
| `Taro.getSystemInfoSync().statusBarHeight`    | `window.getLastWindow().getWindowAvoidArea(TYPE_SYSTEM).topRect.height` |
| 胶囊按钮避让                                    | 鸿蒙无胶囊，改为沉浸式布局 + 顶部 44vp 导航                              |
| `Taro.showToast`                              | `@ohos.promptAction` 的 `showToast`                                     |

## 两个直播源

```ts
const RADIO_URLS = {
  cn: 'https://ngcdn001.cnr.cn/live/zgzs/index.m3u8',
  en: 'https://koe.bbg.fm/channels/2/playlist.m3u8'
};
```

## 运行

1. 用 DevEco Studio 5.0+ 打开工程根目录
2. 等待 `ohpm install` 完成（IDE 会自动触发）
3. 连接真机或启动模拟器，点 Run 即可

> 真机运行需要签名配置：在 DevEco 中 `File → Project Structure → Signing Configs` 自动签名一次即可。

## 权限说明

- `ohos.permission.INTERNET` — 访问网络直播流
- `ohos.permission.GET_NETWORK_INFO` — 网络状态（可选，用于断网提示扩展）
- `ohos.permission.KEEP_BACKGROUND_RUNNING` + `backgroundModes: audioPlayback` — 锁屏/切后台继续播放

## 与原代码的等价行为

- **点击播放**：首次或从停止态 → `AVPlayer.reset()` → 设 `url` → `prepare` → `play`
- **再次播放修复**：对应原代码 `stop() + 重置 src` 的修复 —— 鸿蒙版本在 `play()` 中若当前 state 非 paused 时同样会走一次 `load()`，避免某些情况下无法再次播放
- **切换语言**：stop 当前流 → 如在播放中则立即加载新流
- **错误处理**：通过 `promptAction.showToast` 弹提示
