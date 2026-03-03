import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - A2AAuthentication

/// A2Aクライアントの認証設定
public enum A2AAuthentication: Sendable {
    /// Bearer トークン認証
    case bearer(String)

    /// APIキー認証
    case apiKey(headerName: String, value: String)

    /// カスタムヘッダー
    case headers([String: String])

    /// 認証なし
    case none

    /// URLRequestに認証情報を適用
    internal func apply(to request: inout URLRequest) {
        switch self {
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey(let headerName, let value):
            request.setValue(value, forHTTPHeaderField: headerName)
        case .headers(let headers):
            for (name, value) in headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
        case .none:
            break
        }
    }
}
