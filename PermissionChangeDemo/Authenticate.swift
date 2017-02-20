//
//  Authenticate.swift
//  Meal2day
//
//  Created by Taco Kind on 12-11-16.
//  Copyright © 2016 Taco Kind. All rights reserved.
//

import Foundation
import RealmSwift
import SharedKitApiSafe
import SharedControlsKit
import FoodContainerKit
import SharedKit


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

class Test: Object {
    
    public dynamic var name: String?

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
                print(error)
                switch error.code {
                case -1004: completionHandler(AppError.serverError)
                default: completionHandler(AppError.otherErrorLogin(description: error.localizedDescription))
                }
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
                    
                    UserModel.shared.createOrUpdateUser(user)
                    SeedData.shared.seed()
                }


                completionHandler(nil)
            }
            
        }
    }
    
    class func setRealm(for realmUser: SyncUser) {
        
        // Configure Realm for user
        let configuration = Realm.Configuration(
            inMemoryIdentifier: "inMemoryRealm",
            syncConfiguration: SyncConfiguration(user: realmUser, realmURL: HostConstants.realmURL),
            
            schemaVersion: 13,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < 12) {
                    // Nothing to do! Realm will automatically detect new properties and removed properties
                }
        }
        )
        // Set this as the configuration used for the default Realm
        Realm.Configuration.defaultConfiguration = configuration
        
        // Notify when Realm changes
        self.notificationToken = self.realm.addNotificationBlock { _ in
            // Update Realm
            NotificationCenter.default.post(name: NotificationName.foodContainerDataChanged, object: nil)
        }
       
        self.userNotificationToken = self.realm.objects(User.self).addNotificationBlock { _ in
            // Update user info
            NotificationCenter.default.post(name: NotificationName.userInfoChanged, object: nil)
        }
        
        // Print user info
        printUserInfo()
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
        
        // Wait for server to process
        let offerResults = managementRealm.objects(SyncPermissionOffer.self).filter("id = %@", shareOffer.id)
        self.shareOfferNotificationToken = offerResults.addNotificationBlock { changes in // let shareOfferNotificationToken
            
            guard case let .update(change, _, _, _) = changes,
                let offer = change.first,
                offer.status == .success,
                let token = offer.token else { return } // completionHandler(nil);
            
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
            
            let response: SyncPermissionOfferResponse
            if case let .update(change, _, _, _) = changes, let theResponse = change.first {
                response = theResponse
            } else if case let .initial(change) = changes, let theResponse = change.first {
                response = theResponse
            } else {
                return
            }

            guard response.status == .success, let realmURL = response.realmUrl else { completionHandler(nil); return }
            
            print("PermissionOfferResponse successful and generated realm URL: \(realmURL)")
            
            completionHandler(realmURL)
        }
    }
    
    
    
    class func printUserInfo() {
        let syncConfig = Realm.Configuration.defaultConfiguration.syncConfiguration!
        
        let managementRealm = try! syncConfig.user.managementRealm()
        
        print("\n")
        print("-------------------------------")
        print("User info")
        print("ID of current SyncUser: \(SyncUser.current?.identity ?? "geen")")
        print("Default Realm: \(syncConfig.realmURL.absoluteString)")
        print("User management Realm: \(managementRealm.configuration.syncConfiguration?.realmURL.absoluteString ?? "geen")")
        print("-------------------------------")
        print("\n")


        
    }
    
    class func syncData() {
        
        let defaultRealm = try! Realm()
        
        let foodContainers = defaultRealm.objects(FoodContainer.self)
        print("Number of foodContainers in default Realm: \(foodContainers.count)")
        
        let currentUser = UserModel.shared.readCurrentUser()
        
        print("Shared server path")
        print(currentUser.sharedServerPath)

        if let sharedRealm = try! UserModel.shared.readCurrentUser().sharedRealm() {
            print("\nShared Realm Path:")
            print(sharedRealm.configuration.syncConfiguration!.realmURL)
            print("\n")
            
            let foodContainersSharedRealm = sharedRealm.objects(FoodContainer.self)
            print("Number of foodContainers in shared Realm: \(foodContainersSharedRealm.count)")
            
            try! defaultRealm.write {
                // Add shared foodContainers to default Realm
                foodContainersSharedRealm.forEach{ defaultRealm.add($0) }
            }
            
        }
        print("Number of foodContainers in default Realm after adding shared FoodContainers: \(foodContainers.count)")
        
    }
    
    
    
    
    /**
     syncOff indicates whether a token should be request with the ability to communicate with the backend API
     */
    class func demoLogin(syncOff: Bool = false, completionHandler: @escaping (AppError?) -> Void)->Void {
        
        let currentUser = User()
        currentUser.username = "mister"
        currentUser.firstName = "demo"
        currentUser.lastName = "user"
        currentUser.email = "demo@meal2data.com"
        
        SharedService.shared.loggedInUserId = currentUser.uuid
        try! SharedService.shared.setDefaultRealmForUser()
        
        SeedData.shared.seed()
        UserModel.shared.createUser(currentUser)

        completionHandler(nil)

        
        
    }
    
    
}

func openShareURL(_ url: URL) {
    
    if let syncUser = SyncUser.current {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000)) {
            
            Messages.question(title: "Gegevens delen", message: "Gebruiker met e-mail adres xxx wil gegevens gezamelijk beheren. Druk op Ok om te bevestigen.") { okButton in
                
                if okButton {
                    print("open url: \(url)")
                    let token = url.absoluteString
                        .replacingOccurrences(of: "whatsinthefreezer://", with: "")
                        .replacingOccurrences(of: "/", with: ":")
                    
                    Authenticate.acceptShareToken(token, forUser: syncUser) { sharedRealmURL in
                        
                        if let sharedRealmURL = sharedRealmURL {
                            
                            print("ready to save sharedRealmURL")
                            // Save sharedRealmURL
                            print(sharedRealmURL)
                            
                            let components = sharedRealmURL.components(separatedBy: "/")
                            let userIdToShareWith = components[3]

                            try! Realm().write {
                                UserModel.shared.readCurrentUser().sharedServerPath = userIdToShareWith
                            }

                            Authenticate.syncData()
                        } else {
                            Messages.warning(title: "Waarschuwing", message: "Het is niet gelukt om gegevens te delen")
                        }
                    }
                    //try! SyncUser.current?.acceptShareToken(token)
                } else {
                    return
                }
            }
        }
    } else {
        Messages.info(title: "Inloggen vereist", message: "Log eerst in om gegevens te delen.")
    }
}




