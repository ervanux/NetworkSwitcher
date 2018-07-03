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

    let statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.squareLength)
    let listParam = "listlocations" // "listallnetworkservices"
    let ordernetworkservices = "ordernetworkservices"
    let switchtolocation = "switchtolocation"

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
        self.setNetworkLocation(location: sender.title)
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

    func setNetworkLocation(location:String){
        guard let preferences = SCPreferencesCreate(nil, "Erkan" as CFString, nil) else {
            fatalError("No")
        }

        //        SCPreferencesLock(preferences, true)

        guard let networkSet = SCNetworkSetCopyCurrent(preferences) else {
            fatalError("No set")
        }
        guard let order = SCNetworkSetGetServiceOrder(networkSet) else {
            fatalError("No order")
        }

        print("Network Set:",SCNetworkSetGetName(networkSet))

        let mutableOrder : NSMutableArray = (order as NSArray).mutableCopy() as! NSMutableArray

        let obj = mutableOrder.object(at: 1)
        mutableOrder.removeObject(at: 1)
        mutableOrder.insert(obj , at: 0)
        print("Initial Order:",order)
        print("Changed Order:",mutableOrder)

        assert(SCNetworkSetSetServiceOrder(networkSet, mutableOrder) == true)

        //        let la = LAContext()
        //
        //        la.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Evaluate") { (result, error) in
        //            if error != nil {
        //                print("LA error :", error)
        //                return
        //            }

        //        assert(SCPreferencesUnlock(preferences) == true)
        DispatchQueue.main.async {
            if !SCPreferencesCommitChanges(preferences) {
                print("Error:",SCCopyLastError())
            }

            if !SCPreferencesApplyChanges(preferences) {
                print("Error:",SCCopyLastError())
            }
        }
        //        }



        //        }


    }

    func getNetworkLocationNames() -> [String] {
        guard let preferences = SCPreferencesCreate(nil, "Erkan" as CFString, nil) else {
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
            //            let order = SCNetworkSetGetServiceOrder(networkSet)
            //        let a = SCNetworkInterfaceCopyAll()

            names.append(name as String)

        }

        return names
    }


    func getCurrentNetworkSetServicesNames() -> [String]? {
        let appName = "io.ervanux.NetworkSwitcher"
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

        var preferences : SCPreferences
        if ( geteuid() != 0 ) {
            preferences = SCPreferencesCreateWithAuthorization(nil, appName as CFString, nil, authref)!;
        } else {
            preferences = SCPreferencesCreate(nil, appName as CFString, nil)!
        }
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


            if (name as String).contains("iPhone") {
                assert(SCNetworkServiceRemove(networkService) == true)

                guard SCPreferencesLock(preferences, true) else {
                    let error = SCCopyLastError()
                    print(error)
                    dialogOKCancel(question: "OK", text: "Lock : \(error)")
                    return nil
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
                    return nil
                }

            }

            names.append(name as String)

        }

        return names
    }

    func admin() -> OSStatus {

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

        return status
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

/**
 extension AppDelegate {

 func shell(launchPath: String, arguments: [String]) -> String {

 let task = Process()
 task.launchPath = launchPath
 task.arguments = arguments

 let pipe = Pipe()
 task.standardOutput = pipe
 task.launch()

 let data = pipe.fileHandleForReading.readDataToEndOfFile()
 let output = String(data: data, encoding: String.Encoding.utf8)!
 if output.count > 0 {
 //remove newline character.
 let lastIndex = output.index(before: output.endIndex)
 return String(output[output.startIndex ..< lastIndex])
 }
 return output
 }

 func admin() {

 let rightname = "sys.openfile.readonly./tmp/cantread.txt"

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

 }

 func bash(command: String, arguments: [String]) -> String {
 let whichPathForCommand = shell(launchPath: "/bin/bash", arguments: [ "-l", "-c", "which \(command)" ])
 return shell(launchPath: whichPathForCommand, arguments: arguments)
 }

 }

 **/
