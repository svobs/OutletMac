//
//  main.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/4.
//

import AppKit

let app = OutletMacApp()
// Need this code to luanch the app, since I'm not using a storyboard
NSApplication.shared.mainMenu = AppMainMenu()
NSApplication.shared.delegate = app
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
