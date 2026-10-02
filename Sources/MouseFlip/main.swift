import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    let monitor = ScrollMonitor()
    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var window: NSWindow?
    private var stateLabel: NSTextField?
    private var statsLabel: NSTextField?
    private let enabledItem = NSMenuItem(title: "启用鼠标滚轮反转", action: #selector(toggleEnabled), keyEquivalent: "")
    private let verticalItem = NSMenuItem(title: "反转垂直滚动", action: #selector(toggleVertical), keyEquivalent: "")
    private let horizontalItem = NSMenuItem(title: "反转水平滚动", action: #selector(toggleHorizontal), keyEquivalent: "")
    private let stateItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        // A second launch should reveal the existing instance rather than reverse twice.
        if let id = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: id)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: [.activateIgnoringOtherApps])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        defaults.register(defaults: ["enabled": true, "vertical": true, "horizontal": false])
        monitor.enabled = defaults.bool(forKey: "enabled")
        monitor.vertical = defaults.bool(forKey: "vertical")
        monitor.horizontal = defaults.bool(forKey: "horizontal")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "MouseFlip · 鼠标滚轮反转", action: nil, keyEquivalent: ""))
        menu.addItem(stateItem)
        menu.addItem(.separator())
        for item in [enabledItem, verticalItem, horizontalItem] { item.target = self; menu.addItem(item) }
        menu.addItem(.separator())
        add(menu, "设置与使用说明…", #selector(showSettings))
        add(menu, "打开辅助功能设置…", #selector(openPrivacy))
        menu.addItem(.separator())
        add(menu, "退出 MouseFlip", #selector(quit))
        statusItem.menu = menu
        monitor.refresh()
        updateUI()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.monitor.refresh()
            self?.updateUI()
        }
        if !AXIsProcessTrusted() || !defaults.bool(forKey: "hasShownHelp") {
            showSettings()
            defaults.set(true, forKey: "hasShownHelp")
        }
    }

    func add(_ menu: NSMenu, _ title: String, _ action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    private func updateUI() {
        let state: String
        if !AXIsProcessTrusted() { state = "等待辅助功能权限" }
        else if !monitor.running { state = monitor.failure ?? "监听尚未启动" }
        else if !monitor.enabled { state = "已暂停 · 所有滚动保持原样" }
        else if !monitor.vertical && !monitor.horizontal { state = "未选择反转方向" }
        else { state = "运行中 · 仅反转普通鼠标滚轮" }
        stateItem.title = state
        stateLabel?.stringValue = state
        statsLabel?.stringValue = "本次运行：已反转 \(monitor.reversedCount) 个事件，保留 \(monitor.preservedCount) 个事件"
        enabledItem.state = monitor.enabled ? .on : .off
        verticalItem.state = monitor.vertical ? .on : .off
        horizontalItem.state = monitor.horizontal ? .on : .off
        let symbol = !monitor.running ? "exclamationmark.circle" : (monitor.enabled ? "computermouse" : "pause.circle")
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "MouseFlip")
        statusItem.button?.toolTip = "MouseFlip：\(state)"
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(monitor.enabled, forKey: "enabled")
        defaults.set(monitor.vertical, forKey: "vertical")
        defaults.set(monitor.horizontal, forKey: "horizontal")
        updateUI()
    }
    @objc func toggleEnabled() { monitor.enabled.toggle(); save() }
    @objc func toggleVertical() { monitor.vertical.toggle(); save() }
    @objc func toggleHorizontal() { monitor.horizontal.toggle(); save() }
    @objc func quit() { NSApp.terminate(nil) }

    @objc func openPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openPrivacy()
    }

    @objc func showSettings() {
        if window == nil { makeWindow() }
        updateUI()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() {
        let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 410),
                             styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        panel.title = "MouseFlip"
        panel.isReleasedWhenClosed = false
        panel.center()
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor, constant: 30),
            stack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor, constant: -30),
            stack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor, constant: 28)
        ])
        func label(_ text: String, size: CGFloat = 14, bold: Bool = false) -> NSTextField {
            let view = NSTextField(wrappingLabelWithString: text)
            view.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
            view.translatesAutoresizingMaskIntoConstraints = false
            stack.addArrangedSubview(view)
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            return view
        }
        _ = label("鼠标反转，触控板照常", size: 25, bold: true)
        stateLabel = label("", size: 14, bold: true)
        _ = label("1. 点击下方按钮，允许 MouseFlip 使用辅助功能。\n2. 在菜单栏的鼠标图标中开启反转、选择方向。\n3. 用鼠标滚轮和触控板分别滚动，确认方向。")
        let button = NSButton(title: "授权并打开辅助功能设置", target: self, action: #selector(requestPermission))
        button.bezelStyle = .rounded
        stack.addArrangedSubview(button)
        let note = label("仅处理普通滚轮事件。Magic Mouse、部分平滑滚动驱动会保持原方向。建议先退出其他滚动修改软件。系统的“自然滚动”设置无需修改。", size: 12)
        note.textColor = .secondaryLabelColor
        statsLabel = label("", size: 12)
        statsLabel?.textColor = .secondaryLabelColor
        _ = label("关闭此窗口后仍在菜单栏运行；退出应用即可恢复原来的滚动行为。", size: 12)
        window = panel
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
        monitor.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
