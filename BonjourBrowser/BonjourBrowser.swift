//
//  BonjourBrowser.swift
//  BonjourBrowser
//
//  Created by Sebastian Kruschwitz on 20.04.16.
//  Copyright © 2016 seb. All rights reserved.
//

import Foundation

public protocol BonjourBrowserDelegate: class {
    
    func didStartSearching(browser: BonjourBrowser)
    
    func didStopSearching(browser: BonjourBrowser)
    
    /**
     Will be called when a service disappeared or is not available.
     
     - parameter browser:  FBServiceBrowser that is responsible for the browsing operation.
     - parameter services: NSNetService instances that were removed.
     */
    func browser(browser: BonjourBrowser, didRemoveServices services: [NetService])
}

extension BonjourBrowserDelegate {
    
    func didStartSearching(browser: BonjourBrowser) {
        // optional
    }
    
    func didStopSearching(browser: BonjourBrowser) {
        // optional
    }
    
    func browser(browser: BonjourBrowser, didRemoveServices services: [NetService]) {
        // optional
    }
}

public class BonjourBrowser: NSObject {
    
    public weak var delegate: BonjourBrowserDelegate?
    
    /// Will be set to true when a search is running.
    public var searching = false
    
    private var searchCompletion: ((_ services: [NetService]?) -> Void)?
    
    public enum Result {
        case Success((host: String, port: Int))
        case Failure(Error)
    }
    public enum BonjourError: Error {
        case ResolveFailure
    }
    private var resolveCompletion: ((_ result: Result) -> Void)?
    
    private var domainBrowser: NetServiceBrowser?
    private let serviceIdentifier: String!
    private var receivedServices = [NetService]()
    private var removedServices = [NetService]()
    
    private let timeout = 10
    private var elapsedTime = 0
    private var timer: Timer?
    
    
    //MARK: - Init
    
    public init(identifier: String) {
        
        serviceIdentifier = identifier
    }
    
    //MARK: - Public accessors/actions
    
    public func browse(completion: @escaping (_ services: [NetService]?) -> Void) {
        
        startTimeoutTimer()
        
        self.searchCompletion = completion
        
        if domainBrowser != nil {
            domainBrowser!.stop()
        }
        
        domainBrowser = NetServiceBrowser()
        domainBrowser!.delegate = self
        
        receivedServices.removeAll()
        
        domainBrowser?.searchForServices(ofType: serviceIdentifier, inDomain: "local.")
    }
    
    /**
     Stop browsing for services
     */
    public func stop() {
 
        domainBrowser?.stop()
    }
    
    public func resolveService(service: NetService, completion: @escaping (_ result: Result) -> Void) {
        
        self.resolveCompletion = completion
        
        service.delegate = self
        service.resolve(withTimeout: 10)
    }
    
    
    //MARK: - Timer
    
    private func startTimeoutTimer() {
        
        timer?.invalidate()
        
        elapsedTime = 0
        
        timer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(firedTimeoutTimer(timer:)), userInfo: nil, repeats: true)
    }
    
    @objc private func firedTimeoutTimer(timer: Timer) {
        
        elapsedTime += 1
        
        if elapsedTime >= timeout {
            stopSearching()
            stop()
            
            searchCompletion?(nil)
        }
    }
    
    //MARK: - Searching
    
    private func stopSearching() {
        searching = false
        
        timer?.invalidate()
        timer = nil
    }
    
}

extension BonjourBrowser: NetServiceBrowserDelegate {

    public func netServiceBrowserWillSearch(_ browser: NetServiceBrowser) {
        searching = true
        delegate?.didStartSearching(browser: self)
    }
    
    public func netServiceBrowserDidStopSearch(_ browser: NetServiceBrowser) {
        stopSearching()
        delegate?.didStopSearching(browser: self)
    }

    public func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        print(errorDict)
        stopSearching()
        delegate?.didStopSearching(browser: self)
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        if !receivedServices.contains(service) {
            receivedServices.append(service)
        }
        
        if moreComing == false {
            stopSearching()
            searchCompletion?(receivedServices)
        }
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        if let index = receivedServices.firstIndex(of: service) {
            receivedServices.remove(at: index)
        }
        
        removedServices.append(service)
        
        if moreComing == false {
            delegate?.browser(browser: self, didRemoveServices: removedServices)
            
            removedServices.removeAll()
        }
    }
    
}

extension BonjourBrowser: NetServiceDelegate {
    
    public func netServiceDidResolveAddress(_ sender: NetService) {
        let result = Result.Success((host: sender.hostName!, port: sender.port))
        self.resolveCompletion?(result)
    }
    
    public func netService(sender: NetService, didNotResolve errorDict: [String : NSNumber]) {
        
        var details = [String: String]()
        details[NSLocalizedDescriptionKey] = "Error resolving service"
        let error = NSError(domain: "\(String(describing: errorDict[NetService.errorDomain]))", code: (errorDict[NetService.errorCode]?.intValue)!, userInfo: details)
        print(error)
        
        sender.stop()
        
        self.resolveCompletion?(Result.Failure(BonjourError.ResolveFailure))
    }
}

