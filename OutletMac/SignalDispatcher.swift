//
//  SignalDispatcher.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-02.
//
import Foundation

/** "ListenerID" is equivalent to a PyDispatch "sender" */
typealias ListenerID = String
typealias SenderID = String
typealias SignalCallback = (SenderID, PropDict) throws -> Void
typealias ParamDict = [String: Any]

/**
 CLASS PropDict

 Basically a plain dictionary with a bunch of mechnaics to get around serialization issues for various types.
 Its keys must always be Strings, but its values can be stored at any type, with type conversion (if any) occurring when getters are called.
 This facilitates using values received via gRPC (which will usually be serialized as Strings), and also provides a convenient way to enforce
 type checking for whoever is doing the getting.
 */
class PropDict {
  private var _propertyDict: ParamDict
  init(_ propertyDict: ParamDict?) {
    self._propertyDict = propertyDict ?? [:]
  }

  func get(_ key: String) throws -> Any {
    let configVal: Any? = self._propertyDict[key]
    if configVal == nil {
      throw OutletError.invalidState("No value for key '\(key)'")
    } else {
      return configVal!
    }
  }

  func getString(_ key: String) throws -> String {
    let configVal: Any? = self._propertyDict[key]
    if configVal == nil {
      throw OutletError.invalidState("No value for key '\(key)'")
    } else {
      return configVal! as! String
    }
  }

  func getInt(_ key: String) throws -> Int {
    let val: Any = try self.get(key)
    if let intVal = val as? Int {
      return intVal
    } else if let strVal = val as? String {
      let intVal = Int(strVal)
      if intVal == nil {
        throw OutletError.invalidState("Failed to parse value '\(strVal)' as Bool for key '\(key)'")
      }
      return intVal!
    }
    throw OutletError.invalidState("Invalid type for value '\(val)' (expected Int) for key '\(key)'")
  }

  func getBool(_ key: String) throws -> Bool {
    let val: Any = try self.get(key)
    if let boolVal = val as? Bool {
      return boolVal
    } else if let strVal = val as? String {
      let boolVal = Bool(strVal)
      if boolVal == nil {
        throw OutletError.invalidState("Failed to parse value '\(strVal)' as Bool for key '\(key)'")
      }
      return boolVal!
    }
    throw OutletError.invalidState("Invalid type for value '\(val)' (expected Bool) for key '\(key)'")
  }
}

/**
 CLASS DispatchListener
 */
class DispatchListener {
  private let _id: ListenerID
  private let _dispatcher: SignalDispatcher
  private var _subscribedSignals = [Signal]()

  init(_ id: ListenerID, _ dispatcher: SignalDispatcher) {
    self._id = id
    self._dispatcher = dispatcher
  }

  func subscribe(signal: Signal, _ callback: @escaping SignalCallback, whitelistSenderID: SenderID? = nil, blacklistSenderID: SenderID? = nil) throws {
    let filterCriteria = SignalFilterCriteria(whitelistSenderID: whitelistSenderID, blacklistSenderID: blacklistSenderID)
    let sub = Subscription(callback, filterBy: filterCriteria)
    try self._dispatcher.subscribe(signal: signal, listenerID: self._id, sub)
  }

  /**
   TODO: put in destructor? Does Swift have those?
  */
  func unsubscribeAll() throws {
    for signal in self._subscribedSignals {
      try self._dispatcher.unsubscribe(signal: signal, listenerID: _id)
    }
    self._subscribedSignals.removeAll()
  }
}

fileprivate class SignalFilterCriteria {
  let whitelistSenderID: SenderID?
  let blacklistSenderID: SenderID?
  // maybe more stuff in future

  init(whitelistSenderID: SenderID? = nil, blacklistSenderID: SenderID? = nil) {
    self.whitelistSenderID = whitelistSenderID
    self.blacklistSenderID = blacklistSenderID
  }

  func matches(_ senderID: SenderID?) -> Bool {
    if senderID == nil {
      return true
    } else {
      if self.whitelistSenderID != nil {
        return senderID! == self.whitelistSenderID!
      } else if self.blacklistSenderID != nil {
        return senderID! != self.blacklistSenderID!
      } else {
        return true
      }
    }
  }
}

fileprivate class Subscription {
  let callback: SignalCallback
  let filterCriteria: SignalFilterCriteria?

  init(_ callback: @escaping SignalCallback, filterBy filterCriteria: SignalFilterCriteria? = nil) {
    self.callback = callback
    self.filterCriteria = filterCriteria
  }

  func matches(_ senderID: SenderID?) -> Bool {
    if self.filterCriteria == nil {
      return true
    } else {
      return self.filterCriteria!.matches(senderID)
    }
  }
}

/**
 CLASS SignalDispatcher

 Mimics the functionality of PyDispatcher, with some simplifications/improvments. It's simple enough that I just wrote my own code.
 */
class SignalDispatcher {
  fileprivate var signalListenerDict = [Signal: [ListenerID: Subscription]]()

  func createListener(_ id: ListenerID) -> DispatchListener {
    let listener = DispatchListener(id, self)
    return listener
  }


  fileprivate func subscribe(signal: Signal, listenerID: ListenerID, _ subscription: Subscription) throws {
    if self.signalListenerDict[signal] == nil {
      self.signalListenerDict[signal] = [:]
    }

    if self.signalListenerDict[signal]!.updateValue(subscription, forKey: listenerID) != nil {
      NSLog("WARN  Overwriting subscriber '\(listenerID)' for signal '\(signal)'")
    } else {
      NSLog("DEBUG Added subscriber '\(listenerID)' for signal '\(signal)'")
    }
  }

  fileprivate func unsubscribe(signal: Signal, listenerID: ListenerID) throws {
    if self.signalListenerDict[signal]?.removeValue(forKey: listenerID) != nil {
      NSLog("DEBUG Removed subscriber '\(listenerID)' from signal '\(signal)'")
      return
    }
    NSLog("WARN  Could not remove subscriber '\(listenerID)' from signal '\(signal)': not found")
  }

  func sendSignal(signal: Signal, senderID: SenderID, _ params: ParamDict? = nil) {
    NSLog("DEBUG Dispatcher: Sending signal \(signal)")
    if let subscriberDict: [ListenerID: Subscription] = self.signalListenerDict[signal] {
      let propertyList = PropDict(params)
      var countNotified = 0
      var countTotal = 0
      for (subID, subscriber) in subscriberDict {
        countTotal += 1
        if subscriber.matches(senderID) {
          countNotified += 1
          NSLog("DEBUG Dispatcher: Calling listener \(subID) for signal '\(signal)'")
          do {
            try subscriber.callback(senderID, propertyList)
          } catch {
            NSLog("ERROR While calling listener \(subID) for signal '\(signal)': \(error)")
          }
        } else {
          NSLog("DEBUG Listener \(subID) does not match signal '\(signal)'")
        }
      }

      NSLog("DEBUG Dispatcher: Sent signal \(signal) to \(countNotified) of \(countTotal) subscribers")
    } else {
      NSLog("DEBUG No subscribers found for signal \(signal)")
    }
  }
}
