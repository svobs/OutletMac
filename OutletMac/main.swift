//
//  main.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 21/3/4.
//  Copyright © 2021 Ibotta. All rights reserved.
//

import AppKit

// Need this code to luanch the app, since I'm not using a storyboard
let appDelegate = OutletMacApp()
let menu = AppMenu()
NSApplication.shared.mainMenu = menu
NSApplication.shared.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
