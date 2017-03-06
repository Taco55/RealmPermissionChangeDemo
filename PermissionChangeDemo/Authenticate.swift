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

    class func authenticate(with credentials: Credentials, register: Bool, completionHandler: @escaping (AppError?) -> Void)->Void {
        
        SyncUser.logIn(with: SyncCredentials.usernamePassword(username: credentials.username, password: credentials.password, register: register), server: HostConstants.syncAuthURL) { realmUser, error in

            if let error = error as? NSError {
                if error.code == 611 {
                    completionHandler(AppError.userAlreadyCreated(description: error.localizedDescription))
                } else {
                    completionHandler(AppError.serverError(description: error.localizedDescription))
                }
                return
            }
            
            DispatchQueue.main.async {
                guard let realmUser = realmUser else { fatalError(String(describing: error)) }
                // Set new Realm for logged in User
                self.setRealm(for: realmUser)
                
                // Seed database for new user
                if register {
                    print("\nNew user \(credentials.username) registered: seed new database with data (i.e. a single dog is added for this example)")
                    
                    // Create user
                    let user = User()
                    user.username = credentials.username
                    user.email = credentials.email
                    
                    // Add dog and link to current user
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
    }
}

