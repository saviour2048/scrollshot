import Foundation
import CoreLocation

/// 一次性取当前位置 + 反查地名，给记录页「添加地点」用。
@MainActor
final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    /// 抓取结果。
    struct Place {
        var latitude: Double
        var longitude: Double
        var name: String?
    }

    enum State: Equatable {
        case idle
        case requesting
        case denied
        case failed
    }

    @Published private(set) var state: State = .idle

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var continuation: CheckedContinuation<Place?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    /// 请求一次定位；用户拒绝或失败时返回 nil。
    func fetch() async -> Place? {
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted {
            state = .denied
            return nil
        }

        state = .requesting
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            if status == .notDetermined {
                // 先请授权，拿到结果后在 didChangeAuthorization 里再 requestLocation。
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { await self.finishGeocoding(location) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { await self.finish(nil, state: .failed) }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .denied, .restricted:
                self.finish(nil, state: .denied)
            case .authorizedWhenInUse, .authorizedAlways:
                // 刚授权时如果还在等结果，主动再请求一次。
                if self.continuation != nil { manager.requestLocation() }
            default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func finishGeocoding(_ location: CLLocation) async {
        let placemark = try? await geocoder.reverseGeocodeLocation(location).first
        let name = placemark.map(Self.describe)
        finish(Place(latitude: location.coordinate.latitude,
                     longitude: location.coordinate.longitude,
                     name: name),
               state: .idle)
    }

    private func finish(_ place: Place?, state: State) {
        self.state = state
        continuation?.resume(returning: place)
        continuation = nil
    }

    /// 把 placemark 拼成尽量精确的短地名：优先 POI / 街道+门牌，再带上所在区域。
    private static func describe(_ p: CLPlacemark) -> String {
        // 最具体的一项：POI 名，或「街道 门牌号」
        let street = [p.thoroughfare, p.subThoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        let specific = p.name ?? (street.isEmpty ? nil : street)

        // 区域上下文：街区 / 城区
        let area = p.subLocality ?? p.locality

        let parts = [specific, area]
            .compactMap { $0 }
            .reduce(into: [String]()) { acc, next in
                if !acc.contains(next) { acc.append(next) }
            }
        return parts.isEmpty ? "已记录的位置" : parts.prefix(2).joined(separator: " · ")
    }
}
