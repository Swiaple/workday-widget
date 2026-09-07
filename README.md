# 打卡时间（Workday Widget）

一款轻量的原生 macOS 桌面工时小组件。设置当天的上班时间后，它会根据用户保存的标准工时计算预计下班时间，并持续显示当日进度、加班状态和历史记录。

**当前版本：3.3（Build 10）**  
**最低系统：macOS 13.0**  
**开源协议：MIT**

项目使用 Objective-C 与 AppKit 编写，不依赖第三方框架，也不需要 Xcode 工程文件。

## 功能

- 点击小组件设置当天的上班时间，拖动可调整位置。
- 自定义标准工作时长；保存一次后会持续使用，直到再次修改。
- 显示预计下班时间与实时工时进度。
- 标准工时使用绿色进度；进入加班后，红色进度与状态圆点会随加班时长逐渐加深。
- 点击下班时按当下时间保存实际下班时间和总工时。
- 月度工作记录、每日详情以及绿色/红色工时热力图。
- 支持修改历史记录、跨午夜班次和忘记下班后的补录。
- 历史记录持久保存，并保留上一份数据备份。
- 支持系统毛玻璃、清晰自定义图片和模糊图片背景；图片可裁剪与缩放。
- 记住小组件最后所在的显示器及屏内位置。
- 弹窗始终在小组件所在显示器打开，并以平滑淡入动画显示。
- 桌面层级显示，不会长期遮挡其他应用窗口。

## 构建

### 环境要求

- macOS 13.0 或更高版本
- Xcode Command Line Tools

如未安装命令行工具，可执行：

```bash
xcode-select --install
```

在项目根目录执行：

```bash
zsh scripts/build.sh
```

构建完成后，应用位于：

```text
build/打卡时间.app
```

直接运行：

```bash
open "build/打卡时间.app"
```

构建脚本会使用本机工具链编译应用，并进行本机临时签名；它不是用于公开分发的 Developer ID 签名或公证版本。

## 安装与开机启动

应用无需 DMG。可以把构建后的 `打卡时间.app` 拖入当前用户的 `~/Applications`，或系统的 `/Applications` 文件夹。

最简单的开机启动方式是在 macOS 的“系统设置 → 通用 → 登录项”中添加“打卡时间”。项目也提供了一个可选的 LaunchAgent 示例：

```text
Resources/local.codex.workday-widget.plist
```

该示例通过应用名称启动，不包含开发者电脑的绝对路径。若修改应用名称或 Bundle Identifier，需要同步修改此文件和 `Resources/Info.plist`。

## 使用方式

- 左键单击空白区域：设置上班时间。
- 拖动空白区域：移动小组件；拖动不会触发设置窗口。
- 单击日历图标：查看月度工作记录。
- 右键单击小组件：打开工作计划、下班打卡、记录和更多设置。
- “更多小组件设置”：选择、裁剪、缩放背景图片，并切换原图或模糊毛玻璃效果。

## 数据与隐私

应用完全在本地运行，不上传工时或背景图片。

工作记录保存在：

```text
~/Library/Application Support/打卡时间/work-records.json
~/Library/Application Support/打卡时间/work-records.backup.json
```

自定义背景图片保存在同一应用支持目录。工作计划、背景模式和小组件位置使用 macOS `NSUserDefaults` 保存。

若要彻底重置数据，请先退出应用并自行备份，再删除上述应用支持目录及该应用的用户默认设置。

## 项目结构

```text
workday-widget/
├── LICENSE
├── README.md
├── Resources/
│   ├── Info.plist
│   └── local.codex.workday-widget.plist
├── Sources/WorkdayWidget/
│   ├── main.m
│   ├── HistoryWindowController.*
│   ├── WidgetSettings.*
│   ├── WindowStyling.*
│   └── WorkRecordStore.*
├── Tests/
│   ├── WidgetSettingsTests.m
│   └── WorkRecordStoreTests.m
└── scripts/
    └── build.sh
```

主要代码职责：

- `main.m`：小组件窗口、交互、进度显示和菜单。
- `WorkRecordStore`：工作记录的读取、保存、备份与日期逻辑。
- `WidgetSettings`：计划工时、自定义背景和持久化设置。
- `HistoryWindowController`：月度记录、热力图和记录编辑。
- `WindowStyling`：弹窗毛玻璃样式、多显示器定位与显示动画。

## 测试

当前包含记录存储和设置持久化测试。可在项目根目录分别编译运行：

```bash
store_test_dir="$(mktemp -d /tmp/workday-widget-store.XXXXXX)"
clang -fobjc-arc -O -framework Foundation \
  -I Sources/WorkdayWidget \
  Tests/WorkRecordStoreTests.m \
  Sources/WorkdayWidget/WorkRecordStore.m \
  -o "$store_test_dir/tests"
CFFIXED_USER_HOME="$store_test_dir/home" "$store_test_dir/tests"

settings_test_dir="$(mktemp -d /tmp/workday-widget-settings.XXXXXX)"
clang -fobjc-arc -O -framework Cocoa \
  -I Sources/WorkdayWidget \
  Tests/WidgetSettingsTests.m \
  Sources/WorkdayWidget/WidgetSettings.m \
  -o "$settings_test_dir/tests"
CFFIXED_USER_HOME="$settings_test_dir/home" "$settings_test_dir/tests"
```

测试使用临时用户目录，不会读取或覆盖实际工时记录。

## 分享源码

可以直接压缩整个 `workday-widget` 文件夹分享。为了让压缩包更干净，建议不要包含本机构建产物：

```text
build/
.build-cache/
.DS_Store
```

接收者解压后运行 `zsh scripts/build.sh` 即可在自己的电脑上重新构建和修改。若通过 Git 分享，项目内的 `.gitignore` 已排除这些本地文件。

## 版本号

应用版本的唯一来源是 `Resources/Info.plist`：

- `CFBundleShortVersionString`：对用户显示的版本号，当前为 `3.3`。
- `CFBundleVersion`：内部构建号，当前为 `10`。

发布新版本时，请同步更新本节顶部显示的版本信息。

## 许可证

本项目采用 [MIT License](LICENSE)。你可以自由使用、复制、修改和分发本项目，包括商业用途；再分发时需保留原版权声明和许可文本。软件按现状提供，不附带任何形式的担保。
