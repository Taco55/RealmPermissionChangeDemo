import Foundation
import RealmSwift

class User: Object {
    public dynamic var username: String?
    public dynamic var email: String?
 
    public dynamic var sharedServerPath: String?

    
    var realmUrl: URL? {
        if let sharedServerPath = sharedServerPath {
            return HostConstants.syncServerURL.appendingPathComponent("\(sharedServerPath)/\(HostConstants.appPath)")
        } else {
            return nil
        }
    }
    
    var sharedRealmConfiguration: Realm.Configuration? {
        let user = Realm.Configuration.defaultConfiguration.syncConfiguration!.user
        if let realmUrl = realmUrl {
            
            return Realm.Configuration(syncConfiguration: SyncConfiguration(user: user, realmURL: realmUrl), objectTypes: [Dog.self, User.self])
        } else {
            return nil
        }
    }
    

}


class Dog: Object {
    public dynamic var name: String?

    public dynamic var owner: User?


}
