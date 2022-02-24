//
//  main.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/4.
//

import AppKit

#if DEBUG
NSLog("INFO  DEBUG mode is enabled")
#endif

let app = OutletMacApp()
// Need this code to launch the app, since I'm not using a storyboard
NSApplication.shared.delegate = app
//NSApplication.shared.mainMenu = AppMainMenu()
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
