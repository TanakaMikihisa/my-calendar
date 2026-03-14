import Foundation
import CoreLocation

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

    func currentLocation() async -> CLLocation? {
        await withCheckedContinuation { cont in
            self.continuation = cont
            manager.delegate = self
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
                startResumeTimeout()
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
                startResumeTimeout()
            case .denied, .restricted:
                cont.resume(returning: nil)
                continuation = nil
            @unknown default:
                cont.resume(returning: nil)
                continuation = nil
            }
        }
    }

    ///  continuation が一度も resume されない場合のリーク防止（必ず1回だけ resume）
    private func startResumeTimeout() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            resumeWith(nil)
        }
    }

    private func resumeWith(_ location: CLLocation?) {
        guard continuation != nil else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }
}

extension DefaultLocationRepository: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor [weak self] in
            self?.resumeWith(locations.last)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor [weak self] in
            self?.resumeWith(nil)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.requestLocation()
            case .denied, .restricted:
                self.resumeWith(nil)
            default:
                break
            }
        }
    }
}
