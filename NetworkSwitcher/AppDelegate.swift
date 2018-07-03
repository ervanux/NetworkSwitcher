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
//    let listParam = "listlocations" // "listallnetworkservices"
//    let ordernetworkservices = "ordernetworkservices"
//    let switchtolocation = "switchtolocation"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(named:NSImage.Name("StatusBarButtonImage"))
            //            button.action = #selector(setWifi(_:))
        }
        constructMenu()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

extension AppDelegate {

    @objc func switchLocation(_ sender: NSMenuItem) {
        self.changeServiceOrder()
    }

    func constructMenu() {
        let menu = NSMenu()

        guard let result = self.getCurrentNetworkSetServicesNames() else {
//            print("No result")
            return
        }

        for item in result {
            menu.addItem(NSMenuItem(title: String(item), action: #selector(AppDelegate.switchLocation(_:)), keyEquivalent: ""))
        }

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Toogle", action: #selector(AppDelegate.switchLocation(_:)), keyEquivalent: "Ç"))
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

        guard let authRef = self.getAuthRef() else {
            dialogOKCancel(question: "OK", text: "Auth error")
            return nil
        }

        if ( geteuid() != 0 ) {
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

        let mutableOrder : NSMutableArray = (order as NSArray).mutableCopy() as! NSMutableArray

        let obj = mutableOrder.object(at: 1)
        mutableOrder.removeObject(at: 1)
        mutableOrder.insert(obj , at: 0)
        print("Initial Order:",order)
        print("Changed Order:",mutableOrder)

        assert(SCNetworkSetSetServiceOrder(networkSet, mutableOrder) == true)

        self.commitPref(preferences: preferences)

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

        let preferences = SCPreferencesCreate(nil, appName as CFString, nil)!

        guard let networkSet = SCNetworkSetCopyCurrent(preferences) else {
            fatalError("No")
        }

        print("CurrentSetName:",SCNetworkSetGetName(networkSet)!)

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
