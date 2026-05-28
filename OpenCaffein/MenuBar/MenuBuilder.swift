import AppKit

@MainActor
final class MenuBuilder {
    weak var target: AnyObject?
    var startAction: Selector?
    var screensaverAction: Selector?
    var preferencesAction: Selector?
    var aboutAction: Selector?
    var quitAction: Selector?

    func build(currentDuration: CaffeineDuration?) -> NSMenu {
        let menu = NSMenu()

        let startItem = NSMenuItem(title: "Start Caffeine for", action: nil, keyEquivalent: "")
        startItem.submenu = makeDurationSubmenu(current: currentDuration)
        menu.addItem(startItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "Start Screensaver", action: screensaverAction))
        menu.addItem(makeItem(title: "Preferences…", action: preferencesAction, key: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "About Open Caffein", action: aboutAction))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(makeItem(title: "Quit", action: quitAction, key: "q"))
        return menu
    }

    private func makeDurationSubmenu(current: CaffeineDuration?) -> NSMenu {
        let submenu = NSMenu()
        for preset in CaffeineDuration.standardPresets {
            let item = NSMenuItem(title: preset.displayName, action: startAction, keyEquivalent: "")
            item.representedObject = preset
            item.target = target
            if let current, current == preset { item.state = .on }
            submenu.addItem(item)
        }
        submenu.addItem(NSMenuItem.separator())
        let custom = NSMenuItem(title: "Custom…", action: startAction, keyEquivalent: "")
        custom.representedObject = "custom"
        custom.target = target
        submenu.addItem(custom)
        return submenu
    }

    private func makeItem(title: String, action: Selector?, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }
}
