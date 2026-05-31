import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// クライアントの認証方式。
public enum A2AAuthentication: Sendable {
    /// 認証なし。
    case none
    /// Bearer トークン（`Authorization: Bearer <token>`）。
    case bearer(String)
    /// API キー（任意ヘッダ）。
    case apiKey(header: String, value: String)
    /// 任意のカスタムヘッダ群。
    case headers([String: String])

    /// リクエストへ認証情報を付与。
    func apply(to request: inout URLRequest) {
        switch self {
        case .none:
            break
        case .bearer(let token):
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        case .apiKey(let header, let value):
            request.setValue(value, forHTTPHeaderField: header)
        case .headers(let headers):
            for (name, value) in headers {
                request.setValue(value, forHTTPHeaderField: name)
            }
        }
    }
}
