import Foundation
import RealmSwift

public struct Credentials {
    internal var username: String
    internal var password: String
    internal var email: String?
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
        self.email = nil
    }
    
    public init(username: String, password: String, email: String) {
        self.username = username
        self.password = password
        self.email = email
    }
}

class Authenticate {

    static var realm: Realm { return try! Realm() }
    static var notificationToken: NotificationToken!
    static var userNotificationToken: NotificationToken!
    static var shareOfferNotificationToken: NotificationToken!
    static var shareResponseNotificationToken: NotificationToken!

    class func authenticate(with credentials: Credentials, register: Bool, completionHandler: @escaping (AppError?) -> Void)->Void {
        
        SyncUser.logIn(with: SyncCredentials.usernamePassword(username: credentials.username, password: credentials.password, register: register), server: HostConstants.syncAuthURL) { realmUser, error in
            
            if let error = error as? NSError {
                completionHandler(AppError.serverError(description: error.localizedDescription))
                return
            }
            
            DispatchQueue.main.async {
                guard let realmUser = realmUser else {
                    fatalError(String(describing: error))
                }
                
                // Set new Realm for logged in User
                self.setRealm(for: realmUser)
                
                // Seed database for new user
                if register {
                    print("New user \(credentials.username) registered: seed new database with data")
                    
                    let user = User()
                    user.username = credentials.username
                    user.email = credentials.email
                    
                    let dog = Dog()
                    dog.name = String(format: "%@_dog",credentials.username)
                    dog.owner = user
                    
                    try! realm.write {
                        realm.add(user)
                        realm.add(dog)
                    }
                }
                completionHandler(nil)
            }
            
        }
    }
    
    class func setRealm(for realmUser: SyncUser) {
        
        // Configure Realm for SyncUser
        let configuration = Realm.Configuration(
            inMemoryIdentifier: "inMemoryRealm",
            syncConfiguration: SyncConfiguration(user: realmUser, realmURL: HostConstants.realmURL),
            
            schemaVersion: 1,
            migrationBlock: { migration, oldSchemaVersion in
                if (oldSchemaVersion < 1) {
                }
        }
        )
        Realm.Configuration.defaultConfiguration = configuration
        
        self.userNotificationToken = self.realm.objects(Dog.self).addNotificationBlock { _ in
            // Update user info
            print("UI should be updated with new dogs")
        }
    }
    
    deinit {
        Authenticate.notificationToken.stop()
        Authenticate.userNotificationToken.stop()
        Authenticate.shareOfferNotificationToken.stop()
        Authenticate.shareResponseNotificationToken.stop()
    }
    
    class func shareUsersDefaultRealm(completionHandler: @escaping (String?) -> Void)->Void {
        let syncConfig = Realm.Configuration.defaultConfiguration.syncConfiguration!
        let shareOffer = SyncPermissionOffer(realmURL: syncConfig.realmURL.absoluteString, expiresAt: nil, mayRead: true, mayWrite: true, mayManage: false)
        
        // Save PermissionOffer to user's management Realm
        let managementRealm = try! syncConfig.user.managementRealm()
        try! managementRealm.write { managementRealm.add(shareOffer) }
        
        print("\nShare token, ID: \(shareOffer.id)\n")
 
        let offerResults = managementRealm.objects(SyncPermissionOffer.self).filter("id = %@", shareOffer.id)
        self.shareOfferNotificationToken = offerResults.addNotificationBlock { changes in
            guard case let offer = offerResults.first,
                offer?.status == .success,
                let token = offer?.token else {
                    return
            }
            
            print("PermissionOffer generated a token: \(token)")
            completionHandler(token)
        }
    }

    class func acceptShareToken(_ token: String, forUser user: SyncUser, completionHandler: @escaping (String?) -> Void)->Void {
        
        // Save PermissionOfferResponse to user's management Realm
        let managementRealm = try! user.managementRealm()
        let response = SyncPermissionOfferResponse(token: token)
        try! managementRealm.write { managementRealm.add(response) }
        
        // Wait for server to process
        let responseResults = managementRealm.objects(SyncPermissionOfferResponse.self).filter("id = %@", response.id)
        self.shareResponseNotificationToken = responseResults.addNotificationBlock { changes in // acceptShareNotificationToken
            
            guard case let response = responseResults.first,
                response?.status == .success,
                let realmURL = response?.realmUrl else {
                    return
            }

            print("\nPermissionOfferResponse successful and generated realm URL: \(realmURL)\n")
            
            completionHandler(realmURL)
        }
    }
    
    class func printUserInfo() {
        let syncConfig = Realm.Configuration.defaultConfiguration.syncConfiguration!
        let managementRealm = try! syncConfig.user.managementRealm()
        
        print("\n-------------------------------")
        print("User info")
        print("ID of current SyncUser: \(SyncUser.current?.identity ?? "no Realm")")
        print("Default Realm: \(syncConfig.realmURL.absoluteString)")
        print("User management Realm: \(managementRealm.configuration.syncConfiguration?.realmURL.absoluteString ?? "no Realm")")
        print("-------------------------------\n")
    }
    
    
    
}

