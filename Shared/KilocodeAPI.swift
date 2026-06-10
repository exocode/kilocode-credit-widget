import Foundation

/// Client für die Kilo-Gateway-API (api.kilo.ai).
/// Endpoints und Response-Formen verifiziert gegen Kilo-Org/kilocode
/// (packages/kilo-gateway/src/api/profile.ts, device-auth.ts).
enum KilocodeAPI {
    // MARK: - Balance

    /// `GET /api/profile/balance` → `{"balance": 42.5}` (USD)
    static func fetchBalance(token: String) async throws -> CreditSnapshot {
        let url = AppConstants.apiBaseURL.appendingPathComponent("profile/balance")
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            break
        case 401, 403:
            throw APIError.unauthorized
        default:
            throw APIError.http(http.statusCode)
        }

        struct BalanceResponse: Decodable { let balance: Double }
        guard let decoded = try? JSONDecoder().decode(BalanceResponse.self, from: data) else {
            throw APIError.unexpectedPayload
        }
        return CreditSnapshot(balanceUSD: decoded.balance, fetchedAt: .now)
    }

    // MARK: - Device-Auth

    struct DeviceAuthCode: Decodable {
        let code: String
        let verificationUrl: String
        let expiresIn: Int?
    }

    enum DeviceAuthState {
        case pending
        case approved(token: String)
        case denied
        case expired
    }

    /// `POST /api/device-auth/codes` startet den Browser-Login-Flow.
    static func startDeviceAuth() async throws -> DeviceAuthCode {
        let url = AppConstants.apiBaseURL.appendingPathComponent("device-auth/codes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...201).contains(http.statusCode) else {
            throw APIError.invalidResponse
        }
        guard let decoded = try? JSONDecoder().decode(DeviceAuthCode.self, from: data) else {
            throw APIError.unexpectedPayload
        }
        return decoded
    }

    /// `GET /api/device-auth/codes/{code}`: 202 = pending, 200 = approved,
    /// 403 = denied, 410 = expired.
    static func pollDeviceAuth(code: String) async throws -> DeviceAuthState {
        let url = AppConstants.apiBaseURL.appendingPathComponent("device-auth/codes/\(code)")
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        switch http.statusCode {
        case 200:
            struct Approved: Decodable { let token: String }
            guard let decoded = try? JSONDecoder().decode(Approved.self, from: data) else {
                throw APIError.unexpectedPayload
            }
            return .approved(token: decoded.token)
        case 202:
            return .pending
        case 403:
            return .denied
        case 410:
            return .expired
        default:
            throw APIError.http(http.statusCode)
        }
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case unauthorized
    case http(Int)
    case unexpectedPayload

    var errorDescription: String? {
        let t = L10n.current
        switch self {
        case .invalidResponse:
            return t.invalidResponse
        case .unauthorized:
            return t.unauthorized
        case .http(let code):
            return String(format: t.serverError, code)
        case .unexpectedPayload:
            return t.unexpectedPayload
        }
    }
}
