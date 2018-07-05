//
//  AppDelegate.swift
//  NetworkSwitcher
//
//  Created by Erkan Ugurlu [Dijital Inovasyon Atolyesi] on 26.06.2018.
//  Copyright © 2018 Ervanux. All rights reserved.
//

import Cocoa
import SystemConfiguration
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
        if sender.title == "Toogle" {
            self.changeServiceOrder()
        } else {
            self.setSpesificService(title: sender.title)
        }
    }

    func constructMenu() {
        let menu = NSMenu()

        guard let activeName = self.getActiveName() else {
            showPopup(text: "No active name")
            return
        }

        if let button = statusItem.button {
            if activeName.contains("iPhone") || activeName.contains("iPad") {
                button.image = NSImage(named:NSImage.Name("hotspot"))
            } else {
                button.image = NSImage(named:NSImage.Name(activeName))
            }

            //            button.action = #selector(setWifi(_:))
        }

        guard let result = self.getAllServiceNames() else {
            showPopup(text:"No service name")
            return
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
                showPopup(text: "Auth error")
                return nil
            }

            self.preferences = SCPreferencesCreateWithAuthorization(nil, self.appName as CFString, nil, authRef)!
        } else {
            self.preferences = SCPreferencesCreate(nil, self.appName as CFString, nil)!
        }

        return self.preferences
    }

    func commitPref(preferences : SCPreferences){

        guard SCPreferencesLock(preferences, true),
            SCPreferencesCommitChanges(preferences),
            SCPreferencesApplyChanges(preferences),
            SCPreferencesUnlock(preferences)
            else {
                showPopup(text: "Lock : \(SCCopyLastError())")
                self.preferences = nil
                return
        }

    }

    func getActiveName() -> String? {
        guard let preferences = SCPreferencesCreate(nil, appName as CFString, nil),
            let networkSet = SCNetworkSetCopyCurrent(preferences),
            let order = SCNetworkSetGetServiceOrder(networkSet),
            let networkService = SCNetworkServiceCopy(preferences, (order as NSArray)[0] as! CFString),
            let name = SCNetworkServiceGetName(networkService)
            else {
                showPopup(text: "Setup problem")
                return nil
        }

        return name as String
    }

    func changeServiceOrder(){
        guard let preferences = self.getAuthorizedPreferenceRef(),
            let networkSet = SCNetworkSetCopyCurrent(preferences),
            let order = SCNetworkSetGetServiceOrder(networkSet),
            let mutableOrder  = (order as NSArray).mutableCopy() as? NSMutableArray
            else {
                showPopup(text: "Setup problem")
                return
        }

        let lastObjectIndex = CFArrayGetCount(order) - 1

        let lastObject = mutableOrder.object(at: lastObjectIndex)
        mutableOrder.removeObject(at: lastObjectIndex)
        mutableOrder.insert(lastObject , at: 0)

        guard SCNetworkSetSetServiceOrder(networkSet, mutableOrder) else {
            showPopup(text: "Couldn't set new order")
            return
        }

        self.commitPref(preferences: preferences)
        self.constructMenu()
    }

    func setSpesificService(title:String) {
        guard let preferences = self.getAuthorizedPreferenceRef(),
            let networkSet = SCNetworkSetCopyCurrent(preferences),
            let order = SCNetworkSetGetServiceOrder(networkSet),
            let mutableOrder  = (order as NSArray).mutableCopy() as? NSMutableArray,
            let getSelectedServiceId = self.getIdOfNetworkService(with: title, preferences: preferences)
            else {
                showPopup(text: "Setup problem")
                return
        }

        let indexOfTargetService = mutableOrder.index(of: getSelectedServiceId)
        let obj = mutableOrder.object(at: indexOfTargetService)
        mutableOrder.removeObject(at: indexOfTargetService)
        mutableOrder.insert(obj , at: 0)

        guard SCNetworkSetSetServiceOrder(networkSet, mutableOrder) else {
            showPopup(text: "Couldn't set new order")
            return
        }

        self.commitPref(preferences: preferences)
        self.constructMenu()
    }

    func getNetworkLocationNames() -> [String]? {
        guard let preferences = SCPreferencesCreate(nil, self.appName as CFString, nil),
            let networkSetArray = SCNetworkSetCopyAll(preferences)
            else {
                showPopup(text:"No Names")
                return nil
        }

        let length = CFArrayGetCount(networkSetArray)
        var names = [String]()
        for index in 0...length-1 {
            let networkSet = unsafeBitCast(CFArrayGetValueAtIndex(networkSetArray, index), to: SCNetworkSet.self)
            guard let name = SCNetworkSetGetName(networkSet) else {
                continue
            }

            names.append(name as String)

        }

        return names
    }

    func getIdOfNetworkService(with targetName : String, preferences: SCPreferences) -> String? {
        guard let networkSet = SCNetworkSetCopyCurrent(preferences),
            let networkServices = SCNetworkSetCopyServices(networkSet)
            else {
                showPopup(text:"No preferences")
                return nil
        }

        let length = CFArrayGetCount(networkServices)
        for index in 0...length-1 {
            let networkService = unsafeBitCast(CFArrayGetValueAtIndex(networkServices, index), to: SCNetworkService.self)

            guard let name = SCNetworkServiceGetName(networkService) else {
                continue
            }

            if targetName == name as String {
                guard let serviceID = SCNetworkServiceGetServiceID(networkService) else {
                    continue
                }

                return serviceID as String
            }
        }

        return nil
    }

    func getAllServiceNames() -> [String]? {

        guard let preferences = SCPreferencesCreate(nil, appName as CFString, nil),
            let networkSet = SCNetworkSetCopyCurrent(preferences),
            let networkServices = SCNetworkSetCopyServices(networkSet)
            else {
                showPopup(text:"No preferences")
                return nil
        }

        let length = CFArrayGetCount(networkServices)
        var names = [String]()
        for index in 0...length-1 {
            let networkService = unsafeBitCast(CFArrayGetValueAtIndex(networkServices, index), to: SCNetworkService.self)
            guard let name = SCNetworkServiceGetName(networkService) else {
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
            showPopup(text: "Auth : \(error)")
            return nil
        }

        return authref
    }

}

extension AppDelegate {

    @discardableResult
    func showPopup(title: String = "", text: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        //        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

}
