import UIKit
import RealmSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    // Define some arbitrary test users
    let user1 = Credentials(username: "user1", password: "user1", email: "user1@123.nl")
    let user2 = Credentials(username: "user2", password: "user2", email: "user2@123.nl")
    
    var currentUser: User? {
        return (try! Realm()).objects(User.self).first
    }
    
    //
    // Indicate whether a user has already been registered. 
    // This is only used to illustrate the issue with changing permissions, and assumes that the app is started with empty UserDefaults and an empty Realm Object Server.
    //
    var user1created: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "user1Available")
        }
        set(user) {
            UserDefaults.standard.set(user, forKey: "user1Available")
        }
    }

    var user2created: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "user2Available")
        }
        set(user) {
            UserDefaults.standard.set(user, forKey: "user2Available")
        }
    }


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        self.window?.rootViewController = UIViewController()
        self.window?.makeKeyAndVisible()
        
        // If user was already logged in, logout
        if let realmUser = SyncUser.current {
            realmUser.logOut()
        }

        // Determine whether user should be logged in or registered
        print(String(format: "%@ user 1 \n%@ user 2", user1created ? "Login" : "Register", user2created ? "Login" : "Register"))
        
        Authenticate.authenticate(with: user1, register: !user1created) { error in
            guard error == nil else {
                if case AppError.userAlreadyCreated(_) = error! {
                    print("Error: this demo app assumes empty UserDefaults and an empty Realm Object Server at start. Probably users were already registered.")
                    print("Please empty UserDefaults/remove app and reset Realm ObjectServer and compile app again.")
                } else {
                    print(error!);
                }
                return
            }
            
            self.user1created = true
            
            //
            // Share Realm of user1 with user2
            //
            
            // Create Token
            Authenticate.shareUsersDefaultRealm() { (token, error) in
                guard let token = token else {  print("\n****\n\(error!)\n****\n"); return }

                // Logout user1 so that user2 is able to accept the PermissionOffer token
                SyncUser.current!.logOut()
                
                // Authenticate with user2 and generate PermissionOfferResponse using token
                Authenticate.authenticate(with: self.user2, register: !self.user2created) { error in
                    guard error == nil else { print("\n****\n\(error!)\n****\n"); return }

                    self.user2created = true

                    Authenticate.acceptShareToken(token, forUser: SyncUser.current!) { sharedRealmURL in
                        
                        if let sharedRealmURL = sharedRealmURL {
                        
                            let components = sharedRealmURL.components(separatedBy: "/")
                            let userIdToShareWith = components[3]
                            
                            try! Realm().write {
                                self.currentUser!.sharedServerPath = userIdToShareWith
                            }
                            
                            // Do something with shared data
                            print("\n****\nOpen shared Realm of user1 with the path that is stored in Realm of user2 (this url is similar to the generated url by PermissionOfferResponse):")
                            print(self.currentUser!.realmUrl!)
                            print("\nIt appears that this only works when a PermissionOffereResponse is processed once. The second time a PermissionOffferResponse is processed an assertion error occurs. Why?????\n****\n")
                            let sharedRealm = try! Realm(configuration: self.currentUser!.sharedRealmConfiguration!)

                            print("\n****\nRetrieve dogs of user1:")
                            let sharedDogs = sharedRealm.objects(Dog.self)
                            print("Number of dogs: \(sharedDogs.count)")
                            print("\nWhy is number of dogs zero???\n****\n")
                        } else {
                            print("Sharing data did not succeed")
                        }
                    }
                }
            }
        }
        return true
    }


    func shareRealmUser1WithUser2() {
        
    }
    
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }


}

