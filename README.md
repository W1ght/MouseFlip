# MouseFlip

原生 macOS 菜单栏工具：反转普通鼠标滚轮，保留触控板滚动方向。

## 使用

1. 按下方开发说明构建应用，将 `dist/MouseFlip.app` 拖到“应用程序”文件夹，然后打开。
2. 点击“授权并打开辅助功能设置”，在“系统设置 → 隐私与安全性 → 辅助功能”中开启 MouseFlip。如果列表没有它，点击 `+` 添加应用。
3. 授权后应用会自动开始监听。点击菜单栏鼠标图标查看状态、启用或暂停、选择垂直／水平反转。默认启用垂直反转，水平保持原方向。
4. 用外接鼠标和触控板各滚动一次。设置窗口的事件计数可辅助确认：鼠标应增加“已反转”，触控板应增加“保留”。计数是事件数量，不是手势数量。

应用反转的是 macOS 当前传入的方向。无需改动系统“自然滚动”。退出应用立即停止修改；应用不会修改系统滚动设置。建议先退出其他滚动修改工具，避免叠加反转。

## 支持范围

- macOS 13 及以上；当前已验证 Apple Silicon 构建；Intel 版本需在相应机器上重新编译和验证。
- 普通 USB／蓝牙鼠标的离散滚轮事件；垂直和水平可分别控制。
- 连续滚动、手势阶段、惯性阶段事件均原样放行。
- **不是通过硬件设备 ID 判断鼠标。Magic Mouse 和将鼠标转换为连续事件的平滑滚动驱动，首版不会反转。** 非标准驱动若将触控板转换为离散事件，也可能影响识别。
- 不处理光标移动、键盘、点击；不联网、不保存输入事件。
- 没有开机自启功能。如需自启，可自行将应用加入 macOS 登录项。

构建脚本生成本地临时签名应用，没有 Developer ID 签名及 Apple 公证。源码可审查和重新编译。授权后如依然显示等待权限，请退出并重新打开；移动应用或重新编译后可能需要重新授权。

## 开发

需要 Xcode 或带 Swift 的 Command Line Tools。

```sh
git clone https://github.com/W1ght/MouseFlip.git
cd MouseFlip
swift test
./script/build_and_run.sh --verify
```

构建脚本输出 `dist/MouseFlip.app`；默认构建并启动，`--build-only` 仅构建。提供 `--debug`、`--logs` 和 `--verify`。包内 `ScrollCore` 负责事件判定与变换，`MouseFlip` 为应用入口。

API 参考：[Apple CGEventField](https://developer.apple.com/documentation/coregraphics/cgeventfield)、[Apple CGEvent](https://developer.apple.com/documentation/coregraphics/cgevent)。

自动化测试覆盖离散滚轮的三种数值表示、双轴开关、暂停、连续事件与惯性保护、修饰键保留、鼠标移动放行和异常值保护。真实硬件效果仍需用户授权后实际操作验证。
