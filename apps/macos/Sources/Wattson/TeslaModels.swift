import Foundation

struct TeslaTokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

struct EnergySiteSummary {
    let energySiteId: Int
}

/// GET /api/1/products returns a mix of vehicles and energy sites; only the
/// latter carry energy_site_id, so it's optional here and filtered below.
struct RawProduct: Decodable {
    let energySiteId: Int?

    enum CodingKeys: String, CodingKey {
        case energySiteId = "energy_site_id"
    }
}

/// Shape of GET /api/1/energy_sites/{id}/live_status — power in watts.
struct LiveStatus: Decodable {
    let solarPower: Double
    let percentageCharged: Double
    let batteryPower: Double
    let loadPower: Double
    let gridPower: Double

    enum CodingKeys: String, CodingKey {
        case solarPower = "solar_power"
        case percentageCharged = "percentage_charged"
        case batteryPower = "battery_power"
        case loadPower = "load_power"
        case gridPower = "grid_power"
    }
}

struct FleetAPIEnvelope<T: Decodable>: Decodable {
    let response: T
}
