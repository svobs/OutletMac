//
//  SignalDispatcher.swift
//  OutletMac
//
//  Created by Matthew Svoboda on 2021-02-02.
//  Copyright © 2021 Ibotta. All rights reserved.
//
import Foundation

/** "ListenerID" is equivalent to a PyDispatch "sender" */
typealias ListenerID = String
typealias ParamDict = [String: AnyObject]
typealias Callback = (ParamDict) -> Void
typealias SenderID = String

/**
 CLASS DispatchListener
 */
class DispatchListener {
  let _id: ListenerID
  let _dispatcher: SignalDispatcher
  var _subscribedSignals = [Signal]()

  init(_ id: ListenerID, _ dispatcher: SignalDispatcher) {
    self._id = id
    self._dispatcher = dispatcher
  }

  func subscribe(signal: Signal, _ callback: @escaping Callback, whitelistSenderID: SenderID? = nil) throws {
    let filterCriteria = SignalFilterCriteria(whitelistSenderID: whitelistSenderID)
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
  // maybe more stuff in future

  init(whitelistSenderID: SenderID? = nil) {
    self.whitelistSenderID = whitelistSenderID
  }

  func matches(_ senderID: SenderID?) -> Bool {
    if whitelistSenderID == nil || senderID == nil {
      return true
    } else {
      return senderID! == whitelistSenderID!
    }
  }
}

fileprivate class Subscription {
  let callback: Callback
  let filterCriteria: SignalFilterCriteria?

  init(_ callback: @escaping Callback, filterBy filterCriteria: SignalFilterCriteria? = nil) {
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
    var subscriberDict: [ListenerID: Subscription]? = self.signalListenerDict[signal]
    if subscriberDict == nil {
      subscriberDict = [:]
      self.signalListenerDict[signal] = subscriberDict
    }

    if subscriberDict!.updateValue(subscription, forKey: listenerID) != nil {
      NSLog("Warning: overwriting listener '\(listenerID)' for signal '\(signal)'")
    }
  }

  fileprivate func unsubscribe(signal: Signal, listenerID: ListenerID) throws {
    if var subscriberDict: [ListenerID: Subscription] = self.signalListenerDict[signal] {
      if subscriberDict.removeValue(forKey: listenerID) != nil {
        NSLog("Removed listener '\(listenerID)' from signal '\(signal)'")
        return
      }
    }
    NSLog("Warning: could not remove listener '\(listenerID)' from signal '\(signal)': not found")
  }

  func sendSignal(signal: Signal, params: ParamDict?, senderID: SenderID?) {
    if let subscriberDict: [ListenerID: Subscription] = self.signalListenerDict[signal] {
      let paramsForSure = params ?? [:]
      for (subID, subscriber) in subscriberDict {
        if subscriber.matches(senderID) {
          NSLog("Calling listener \(subID) for signal '\(signal)'")
          subscriber.callback(paramsForSure)
        } else {
          NSLog("Listener \(subID) does not match signal '\(signal)'")
        }
      }
    }
  }
}
