import CoreLocation
import Foundation

// MARK: - Protocol

protocol LocationRepositoryProtocol {
    /// 現在地を取得（1回だけ）。権限なし・取得失敗時は nil
    func currentLocation() async -> CLLocation?
}

// MARK: - CLLocationManager 実装

@MainActor
final class DefaultLocationRepository: NSObject, LocationRepositoryProtocol {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    func currentLocation() async -> CLLocation? {
        // 実行中の待ちがある場合は先に解放（二重待ち・クラッシュ防止）
        resumeContinuation(returning: nil)

        return await withCheckedContinuation { cont in
            self.continuation = cont

            switch manager.authorizationStatus {
            case .notDetermined:
                // 結果は locationManagerDidChangeAuthorization で受け取り、許可後に requestLocation
                manager.requestWhenInUseAuthorization()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                resumeContinuation(returning: nil)
            @unknown default:
                resumeContinuation(returning: nil)
            }
        }
    }

    /// `continuation` があれば1回だけ `resume` し、直後に `nil` にして二重再開を防ぐ
    private func resumeContinuation(returning location: CLLocation?) {
        continuation?.resume(returning: location)
        continuation = nil
    }
}

extension DefaultLocationRepository: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                resumeContinuation(returning: nil)
            case .notDetermined:
                break
            @unknown default:
                resumeContinuation(returning: nil)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            self?.resumeContinuation(returning: locations.last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        #if DEBUG
            print("⚠️ 位置情報取得エラー: \(error.localizedDescription)")
        #endif
        Task { @MainActor [weak self] in
            self?.resumeContinuation(returning: nil)
        }
    }
}
