import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let credentialStore = CredentialStore()
    private var poller: LiveStatusPoller?

    private let connectItem = NSMenuItem(title: "Connect Powerwall…", action: #selector(connect), keyEquivalent: "")
    private let disconnectItem = NSMenuItem(title: "Disconnect", action: #selector(disconnect), keyEquivalent: "")
    private let dropdownView = StatusDropdownView()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = HouseChargeIcon.make(
            percentage: 0,
            isCharging: false,
            isDischarging: false,
            solarPower: 0,
            isSolarActive: false,
            gridPower: 0,
            isGridImporting: false,
            isGridExporting: false,
            loadPower: 0
        )
        statusItem.menu = buildMenu()

        // Only one Powerwall is supported right now, so once connected
        // there's nothing more for "Connect" to do — replace it with
        // "Disconnect" instead of showing both.
        setConnected(credentialStore.load() != nil)

        if let credentials = credentialStore.load() {
            startPolling(with: credentials)
        }
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        connectItem.target = self
        disconnectItem.target = self

        let dropdownItem = NSMenuItem()
        dropdownItem.view = dropdownView
        dropdownItem.isEnabled = false

        menu.addItem(connectItem)
        menu.addItem(.separator())
        menu.addItem(dropdownItem)
        menu.addItem(.separator())
        menu.addItem(disconnectItem)
        menu.addItem(withTitle: "Quit Wattson", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func setConnected(_ connected: Bool) {
        connectItem.isHidden = connected
        disconnectItem.isHidden = !connected
    }

    @objc private func connect() {
        dropdownView.showConnecting()
        AuthFlow.startLogin()
    }

    @objc private func disconnect() {
        poller?.stop()
        poller = nil
        credentialStore.clear()
        setConnected(false)
        statusItem.button?.image = HouseChargeIcon.make(
            percentage: 0,
            isCharging: false,
            isDischarging: false,
            solarPower: 0,
            isSolarActive: false,
            gridPower: 0,
            isGridImporting: false,
            isGridExporting: false,
            loadPower: 0
        )
        dropdownView.showDisconnected()
    }

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
            let url = URL(string: urlString)
        else { return }

        Task {
            do {
                let credentials = try await AuthFlow.handleCallback(url: url)
                credentialStore.save(credentials)
                setConnected(true)
                startPolling(with: credentials)
            } catch {
                dropdownView.showError("Error: \(error.localizedDescription)")
            }
        }
    }

    private func startPolling(with credentials: StoredCredentials) {
        poller?.stop()
        let poller = LiveStatusPoller(credentials: credentials, credentialStore: credentialStore)
        poller.onUpdate = { [weak self] status in
            self?.render(status)
        }
        poller.onError = { [weak self] message in
            self?.dropdownView.showError("Error: \(message)")
        }
        poller.start()
        self.poller = poller
    }

    private func render(_ status: LiveStatus) {
        // Tesla's `battery_power` is signed from the battery's own point of
        // view: positive means power leaving the battery (discharging into
        // the home), negative means power entering it (charging) — the
        // opposite of `grid_power`'s "positive = flowing into the site"
        // convention, which is easy to mix up.
        let isCharging = status.batteryPower < -50
        let isDischarging = status.batteryPower > 50
        let isSolarActive = status.solarPower > 50
        let isGridImporting = status.gridPower > 50
        let isGridExporting = status.gridPower < -50

        statusItem.button?.image = HouseChargeIcon.make(
            percentage: status.percentageCharged,
            isCharging: isCharging,
            isDischarging: isDischarging,
            solarPower: status.solarPower,
            isSolarActive: isSolarActive,
            gridPower: status.gridPower,
            isGridImporting: isGridImporting,
            isGridExporting: isGridExporting,
            loadPower: status.loadPower
        )
        dropdownView.update(with: status)
    }
}
