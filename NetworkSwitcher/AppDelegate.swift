//
//  AppDelegate.swift
//  NetworkSwitcher
//
//  Created by Erkan Ugurlu [Dijital Inovasyon Atolyesi] on 26.06.2018.
//  Copyright © 2018 Ervanux. All rights reserved.
//

import Cocoa
import SystemConfiguration
//import LocalAuthentication
import Security.Authorization

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    let appName = "io.ervanux.NetworkSwitcher"
    var preferences : SCPreferences?
    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        constructMenu()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

extension AppDelegate {

    @objc @IBAction func switchLocation(_ sender: NSMenuItem) {
        self.changeServiceOrder()
    }

    func constructMenu() {
        let menu = NSMenu()

        guard let activeName = self.getActiveName() else {
            fatalError("No active name")
        }

        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name(activeName))
            //            button.action = #selector(setWifi(_:))
        }

        guard let result = self.getCurrentNetworkSetServicesNames() else {
            fatalError("No service name")
        }

        for item in result {
            var title = String(item)
            if title == activeName {
                title = "✔︎ " + title
            }
            menu.addItem(NSMenuItem(title:title , action: #selector(AppDelegate.switchLocation(_:)), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toogle", action: #selector(AppDelegate.switchLocation(_:)), keyEquivalent: ""))
//        menu.addItem(NSMenuItem(title: "Toogle", action: #selector(AppDelegate.switchLocation(_:)), keyEquivalent: "Ç"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: ""))

        statusItem.menu = menu
        
    }
}

extension AppDelegate {

    func getAuthorizedPreferenceRef() -> SCPreferences? {

        guard self.preferences == nil else {
            return self.preferences
        }

        if geteuid() != 0 {
            guard let authRef = self.getAuthRef() else {
                dialogOKCancel(question: "OK", text: "Auth error")
                return nil
            }

            self.preferences = SCPreferencesCreateWithAuthorization(nil, self.appName as CFString, nil, authRef)!
        } else {
            self.preferences = SCPreferencesCreate(nil, self.appName as CFString, nil)!
        }

        return self.preferences
    }

    func commitPref(preferences : SCPreferences){

        guard SCPreferencesLock(preferences, true) else {
            let error = SCCopyLastError()
            print(error)
            dialogOKCancel(question: "OK", text: "Lock : \(error)")
            return
        }

        if !SCPreferencesCommitChanges(preferences) {
            let error = SCCopyLastError()
            print(error)
            dialogOKCancel(question: "OK", text: "Commit : \(error)")
        }

        if !SCPreferencesApplyChanges(preferences) {
            let error = SCCopyLastError()
            print(error)
            dialogOKCancel(question: "OK", text: "Apply : \(error)")
        }

        guard SCPreferencesUnlock(preferences) else {
            let error = SCCopyLastError()
            print(error)
            dialogOKCancel(question: "OK", text: "Unlock : \(error)")
            return
        }
    }

    func getActiveName() -> String? {
        guard let preferences = SCPreferencesCreate(nil, self.appName as CFString, nil) else {
            fatalError("No preference")
        }

        guard let networkSet = SCNetworkSetCopyCurrent(preferences) else {
            fatalError("No set")
        }

        guard let order = SCNetworkSetGetServiceOrder(networkSet) else {
            fatalError("No order")
        }

        guard let networkService = SCNetworkServiceCopy(preferences, (order as NSArray)[0] as! CFString) else {
            fatalError("No service")
        }

        guard let name = SCNetworkServiceGetName(networkService) else {
            fatalError("No name")
        }

        return name as String
    }

    func changeServiceOrder(){
        guard let preferences = self.getAuthorizedPreferenceRef() else {
            dialogOKCancel(question: "OK", text: "Preferences couln't created")
            return
        }

        guard let networkSet = SCNetworkSetCopyCurrent(preferences) else {
            fatalError("No set")
        }
        guard let order = SCNetworkSetGetServiceOrder(networkSet) else {
            fatalError("No order")
        }

        guard let mutableOrder  = (order as NSArray).mutableCopy() as? NSMutableArray else {
            fatalError("Mutablity error")
        }

        let obj = mutableOrder.object(at: 1)
        mutableOrder.removeObject(at: 1)
        mutableOrder.insert(obj , at: 0)
        print("Initial Order:",order)
        print("Changed Order:",mutableOrder)

        assert(SCNetworkSetSetServiceOrder(networkSet, mutableOrder) == true)

        self.commitPref(preferences: preferences)
        self.constructMenu()
    }

    func getNetworkLocationNames() -> [String] {

        guard let preferences = SCPreferencesCreate(nil, self.appName as CFString, nil) else {
            fatalError("No")
        }

        guard let networkSetArray = SCNetworkSetCopyAll(preferences) else {
            fatalError("No")
        }

        let length = CFArrayGetCount(networkSetArray)
        var names = [String]()
        for index in 0...length-1 {
            let networkSet = unsafeBitCast(CFArrayGetValueAtIndex(networkSetArray, index), to: SCNetworkSet.self)
            guard let name = SCNetworkSetGetName(networkSet) else {
                print("no name")
                continue
            }

            names.append(name as String)

        }

        return names
    }

    func getCurrentNetworkSetServicesNames() -> [String]? {

        guard let preferences = SCPreferencesCreate(nil, appName as CFString, nil) else {
            fatalError("No preferences")
        }

        guard let networkSet = SCNetworkSetCopyCurrent(preferences) else {
            fatalError("No")
        }

//        guard let name = SCNetworkSetGetName(networkSet) else {
//            fatalError("No name")
//        }

        guard let networkServices = SCNetworkSetCopyServices(networkSet) else {
            fatalError("No")
        }

        let length = CFArrayGetCount(networkServices)
        var names = [String]()
        for index in 0...length-1 {
            let networkService = unsafeBitCast(CFArrayGetValueAtIndex(networkServices, index), to: SCNetworkService.self)

            guard let name = SCNetworkServiceGetName(networkService) else {
                print("no name")
                continue
            }

            names.append(name as String)

        }

        return names
    }

    func getAuthRef() -> AuthorizationRef? {

        let rightname = "com.apple.SystemConfiguration"

        var status: OSStatus

        var authref: AuthorizationRef?
        let flags = AuthorizationFlags([.interactionAllowed, .extendRights, .preAuthorize])
        status = AuthorizationCreate(nil, nil, flags, &authref)
        assert(status == errAuthorizationSuccess)

        var item = AuthorizationItem(name: rightname, valueLength: 0, value: nil, flags: 0)
        var rights = AuthorizationRights(count: 1, items: &item)
        status = AuthorizationCopyRights(authref!, &rights, nil, flags, nil)
        assert(status == errAuthorizationSuccess)

        var token = AuthorizationExternalForm()
        status = AuthorizationMakeExternalForm(authref!, &token)
        assert(status == errAuthorizationSuccess)

        guard status == errAuthorizationSuccess  else {
            print(status)
            let error = SCCopyLastError()
            print(error)
            dialogOKCancel(question: "OK", text: "Auth : \(error)")
            return nil
        }

        return authref
    }

}

extension AppDelegate {

    @discardableResult
    func dialogOKCancel(question: String, text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = question
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

}
