//
//  Dispatcher.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-02.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import Foundation

typealias ListenerID = String
typealias ParamDict = [String: AnyObject]
typealias Listener = (ParamDict) -> Void

/**
 CLASS Dispatcher

 Mimics the functionality of PyDispatcher, with some simplifications/improvments. It's simple enough that I just wrote my own code.
 */
class Dispatcher {
  var signalListenerDict = [UInt32: [ListenerID: Listener]]()

  func addListener(signal: Signal, listenerID: ListenerID, _ listener: @escaping Listener) throws {
    var listenerDict: [ListenerID: Listener]? = self.signalListenerDict[signal.rawValue]
    if listenerDict == nil {
      listenerDict = [:]
      self.signalListenerDict[signal.rawValue] = listenerDict
    }

    if listenerDict!.updateValue(listener, forKey: listenerID) != nil {
      NSLog("Warning: overwriting listener '\(listenerID)' for signal '\(signal)'")
    }
  }

  func removeListener(signal: Signal, listenerID: ListenerID) throws {
    if var listenerDict: [ListenerID: Listener] = self.signalListenerDict[signal.rawValue] {
      if listenerDict.removeValue(forKey: listenerID) != nil {
        NSLog("Removed listener '\(listenerID)' for signal '\(signal)'")
        return
      }
    }
    NSLog("Warning: could not remove listener '\(listenerID)' for signal '\(signal)': not found")
  }

  func sendSignal(signal: Signal, params: ParamDict?, listenerID: ListenerID?) {
    if let listenerDict: [ListenerID: Listener] = self.signalListenerDict[signal.rawValue] {
      let paramsForSure = params ?? [:]
      if listenerID == nil {
        for (mappedListenerID, listener) in listenerDict {
          NSLog("Calling listener '\(mappedListenerID)' for signal '\(signal)'")
          listener(paramsForSure)
        }
      } else {
        if let listener = listenerDict[listenerID!] {
          NSLog("Calling unitary listener '\(listenerID!)' for signal '\(signal)'")
          listener(paramsForSure)
        } else {
          NSLog("Cannot send signal: could not find unitary listener '\(listenerID!)' for signal '\(signal)'")
        }
      }
    }
  }
}
