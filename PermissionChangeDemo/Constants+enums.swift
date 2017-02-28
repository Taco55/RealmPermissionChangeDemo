import Foundation

// Internal Functions
struct HostConstants {
    #if os(OSX)
    static let host = "127.0.0.1"
    #else
    static let host = "192.168.2.217" // "127.0.0.1"
    #endif
    
    // Realm constants
    static let appPath = "permissionchangedemo"
    static let syncServerURL = URL(string: "realm://\(host):9080/")!
    static let realmURL = syncServerURL.appendingPathComponent("~/\(appPath)")
    static let syncAuthURL = URL(string: "http://\(host):9080")!
}


public enum AppError: Error, CustomStringConvertible {
    case serverError(description: String)
    case syncPermissionOfferError(description: String)
    case userAlreadyCreated(description: String)
    
    public var description: String {
        switch self {
        case .serverError(let description): return "Server error: \(description)"
        case .userAlreadyCreated(let description): return "User is already created: \(description)"

        case .syncPermissionOfferError(let description): return "SyncPermissionOffer error: \(description)"
        }
    }
    
}
