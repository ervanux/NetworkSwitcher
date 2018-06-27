//
//  AppDelegate.swift
//  NetworkSwitcher
//
//  Created by Erkan Ugurlu [Dijital Inovasyon Atolyesi] on 26.06.2018.
//  Copyright © 2018 Ervanux. All rights reserved.
//

import Cocoa
import SystemConfiguration

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

    @objc func changeOrder(_ sender: Any?) {
        var args = [ordernetworkservices]
        let list = self.listNetwork()
        for item in list.reversed() {
            args.append(item)
        }

        admin()
        let result = self.bash(command: "networksetup", arguments: args)
        print(args)
        print(result)

        print("\n", self.listNetwork())

    }

    @objc func switchLocation(_ sender: Any?) {
//        let la = LAContext()
//        la.evaluatePolicy(LAPolicy.deviceOwnerAuthentication, localizedReason: "Password") { (result, error) in


        var args = [self.switchtolocation]
        let list = self.listNetwork()
        args.append(list.last!)
        admin()

        let output = self.bash(command: "networksetup", arguments: args)
        print(args)
        print(output)

        print("\n", self.listNetwork())
//        }


    }

    func listNetwork() -> [String] {
        let result = self.bash(command: "networksetup", arguments: [listParam])
        let list = result.split(separator: "\n").map{ String($0) }
        //        list.remove(at: 0)
        return list
    }


    func constructMenu() {
        let menu = NSMenu()

        let result = self.getNetworkNames()
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

    func getNetworkNames() -> [String] {
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

}

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

