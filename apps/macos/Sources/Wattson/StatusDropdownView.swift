import AppKit

/// A single labeled value row (icon, label, right-aligned value) used for
/// Solar/Grid/Consumption in the dropdown — a smaller, text-based echo of
/// the same color language used in the menu bar icon itself.
@MainActor
private final class MetricRow: NSView {
    private let iconView = NSImageView()
    private let labelField: NSTextField
    private let valueField = NSTextField(labelWithString: "")
    private let symbolName: String

    init(symbolName: String, label: String) {
        self.symbolName = symbolName
        self.labelField = NSTextField(labelWithString: label)
        super.init(frame: .zero)
        setupLayout()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        iconView.translatesAutoresizingMaskIntoConstraints = false
        labelField.translatesAutoresizingMaskIntoConstraints = false
        valueField.translatesAutoresizingMaskIntoConstraints = false

        labelField.font = .systemFont(ofSize: 12)
        labelField.textColor = .secondaryLabelColor
        valueField.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        valueField.alignment = .right

        addSubview(iconView)
        addSubview(labelField)
        addSubview(valueField)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 16),
            iconView.heightAnchor.constraint(equalToConstant: 16),

            labelField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 6),
            labelField.centerYAnchor.constraint(equalTo: centerYAnchor),

            valueField.trailingAnchor.constraint(equalTo: trailingAnchor),
            valueField.centerYAnchor.constraint(equalTo: centerYAnchor),
            valueField.leadingAnchor.constraint(greaterThanOrEqualTo: labelField.trailingAnchor, constant: 8),

            heightAnchor.constraint(equalToConstant: 20),
        ])
    }

    func update(label: String? = nil, value: String, color: NSColor) {
        if let label {
            labelField.stringValue = label
        }
        valueField.stringValue = value
        valueField.textColor = color

        let configuration = NSImage.SymbolConfiguration(pointSize: 12, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        iconView.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
    }
}

/// The full dropdown content: a header (house icon + charge % + a short
/// state description) followed by Solar / Grid / Consumption rows. Set as
/// the `view` of a single disabled NSMenuItem in place of several plain
/// text items.
@MainActor
final class StatusDropdownView: NSView {
    private let houseImageView = NSImageView()
    private let percentField = NSTextField(labelWithString: "--%")
    private let subtitleField = NSTextField(labelWithString: "Not connected")
    private let solarRow = MetricRow(symbolName: "sun.max.fill", label: "Solar")
    private let gridRow = MetricRow(symbolName: "bolt.horizontal.fill", label: "Grid")
    private let consumptionRow = MetricRow(symbolName: "arrowtriangle.right.fill", label: "Consumption")

    private static let houseIconSize: CGFloat = 32

    init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 118))
        setupLayout()
        showDisconnected()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        translatesAutoresizingMaskIntoConstraints = false
        houseImageView.translatesAutoresizingMaskIntoConstraints = false
        percentField.translatesAutoresizingMaskIntoConstraints = false
        subtitleField.translatesAutoresizingMaskIntoConstraints = false
        solarRow.translatesAutoresizingMaskIntoConstraints = false
        gridRow.translatesAutoresizingMaskIntoConstraints = false
        consumptionRow.translatesAutoresizingMaskIntoConstraints = false

        houseImageView.imageScaling = .scaleNone

        // Regular weight, not semibold — a bold percentage read as
        // visually heavier than the house icon's thin 1.4pt outline, an
        // imbalance a couple points of extra size doesn't fix on its own.
        percentField.font = .systemFont(ofSize: 24, weight: .regular)
        subtitleField.font = .systemFont(ofSize: 12)
        subtitleField.textColor = .secondaryLabelColor

        let divider = NSBox()
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.boxType = .separator

        addSubview(houseImageView)
        addSubview(percentField)
        addSubview(subtitleField)
        addSubview(divider)
        addSubview(solarRow)
        addSubview(gridRow)
        addSubview(consumptionRow)

        let sidePadding: CGFloat = 18
        let rowGap: CGFloat = 10

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 240),

            houseImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sidePadding),
            houseImageView.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            houseImageView.widthAnchor.constraint(equalToConstant: Self.houseIconSize),
            houseImageView.heightAnchor.constraint(equalToConstant: Self.houseIconSize),

            percentField.leadingAnchor.constraint(equalTo: houseImageView.trailingAnchor, constant: 12),
            percentField.topAnchor.constraint(equalTo: houseImageView.topAnchor, constant: -2),
            percentField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -sidePadding),

            subtitleField.leadingAnchor.constraint(equalTo: percentField.leadingAnchor),
            subtitleField.topAnchor.constraint(equalTo: percentField.bottomAnchor, constant: 2),
            subtitleField.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -sidePadding),

            divider.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sidePadding),
            divider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidePadding),
            divider.topAnchor.constraint(equalTo: houseImageView.bottomAnchor, constant: 18),

            solarRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sidePadding),
            solarRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidePadding),
            solarRow.topAnchor.constraint(equalTo: divider.bottomAnchor, constant: 14),

            gridRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sidePadding),
            gridRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidePadding),
            gridRow.topAnchor.constraint(equalTo: solarRow.bottomAnchor, constant: rowGap),

            consumptionRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: sidePadding),
            consumptionRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -sidePadding),
            consumptionRow.topAnchor.constraint(equalTo: gridRow.bottomAnchor, constant: rowGap),
            consumptionRow.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
        ])
    }

    func showDisconnected() {
        percentField.stringValue = "--%"
        subtitleField.stringValue = "Not connected"
        houseImageView.image = HouseChargeIcon.makeHouseOnly(percentage: 0, isCharging: false, size: Self.houseIconSize)
        let dim = NSColor.secondaryLabelColor
        solarRow.update(value: "--", color: dim)
        gridRow.update(label: "Grid", value: "--", color: dim)
        consumptionRow.update(value: "--", color: dim)
    }

    func showConnecting() {
        subtitleField.stringValue = "Connecting…"
    }

    func showError(_ message: String) {
        subtitleField.stringValue = message
    }

    func update(with status: LiveStatus) {
        let charge = Int(status.percentageCharged.rounded())
        // See AppDelegate.render — `battery_power` is signed from the
        // battery's own point of view: positive = discharging, negative =
        // charging.
        let isCharging = status.batteryPower < -50
        let isDischarging = status.batteryPower > 50
        let isSolarActive = status.solarPower > 50
        let isGridImporting = status.gridPower > 50
        let isGridExporting = status.gridPower < -50

        percentField.stringValue = "\(charge)%"
        subtitleField.stringValue = isCharging ? "Charging" : (isDischarging ? "Discharging" : "Idle")

        houseImageView.image = HouseChargeIcon.makeHouseOnly(
            percentage: status.percentageCharged,
            isCharging: isCharging,
            isDischarging: isDischarging,
            size: Self.houseIconSize
        )

        solarRow.update(
            value: "\(HouseChargeIcon.formatKW(status.solarPower)) kW",
            color: isSolarActive ? .systemYellow : .secondaryLabelColor
        )

        if isGridExporting {
            gridRow.update(label: "Exporting", value: "\(HouseChargeIcon.formatKW(abs(status.gridPower))) kW", color: .systemGreen)
        } else if isGridImporting {
            gridRow.update(label: "Importing", value: "\(HouseChargeIcon.formatKW(abs(status.gridPower))) kW", color: .systemRed)
        } else {
            gridRow.update(label: "Grid", value: "0.0 kW", color: .secondaryLabelColor)
        }

        consumptionRow.update(value: "\(HouseChargeIcon.formatKW(status.loadPower)) kW", color: .systemRed)
    }
}
