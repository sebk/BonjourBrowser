//
//  BonjourBrowser.swift
//  BonjourBrowser
//
//  Created by Sebastian Kruschwitz on 20.04.16.
//  Copyright © 2016 seb. All rights reserved.
//

import Foundation

public protocol BonjourBrowserDelegate: class {
    
    func didStartSearching(browser browser: BonjourBrowser)
    
    func didStopSearching(browser browser: BonjourBrowser)
    
    /**
     Will be called when a service disappeared or is not available.
     
     - parameter browser:  FBServiceBrowser that is responsible for the browsing operation.
     - parameter services: NSNetService instances that were removed.
     */
    func browser(browser: BonjourBrowser, didRemoveServices services: [NSNetService])
}

extension BonjourBrowserDelegate {
    
    func didStartSearching(browser browser: BonjourBrowser) {
        // optional
    }
    
    func didStopSearching(browser browser: BonjourBrowser) {
        // optional
    }
    
    func browser(browser: BonjourBrowser, didRemoveServices services: [NSNetService]) {
        // optional
    }
}

public class BonjourBrowser: NSObject {
    
    public weak var delegate: BonjourBrowserDelegate?
    
    /// Will be set to true when a search is running.
    public var searching = false
    
    private var searchCompletion: ((services: [NSNetService]?) -> Void)?
    
    //public typealias ResolveCompletionType = (Result) -> Void
    public enum Result {
        case Success((host: String, port: Int))
        case Failure(Error)
    }
    public enum Error: ErrorType {
        case ResolveFailure
    }
    private var resolveCompletion: ((result: Result) -> Void)?
    
    private var domainBrowser: NSNetServiceBrowser?
    private let serviceIdentifier: String!
    private var receivedServices = [NSNetService]()
    private var removedServices = [NSNetService]()
    
    private let timeout = 10
    private var elapsedTime = 0
    private var timer: NSTimer?
    
    
    //MARK: - Init
    
    public init(identifier: String) {
        
        serviceIdentifier = identifier
    }
    
    //MARK: - Public accessors/actions
    
    public func browse(completion: (services: [NSNetService]?) -> Void) {
        
        startTimeoutTimer()
        
        self.searchCompletion = completion
        
        if domainBrowser != nil {
            domainBrowser!.stop()
        }
        
        domainBrowser = NSNetServiceBrowser()
        domainBrowser!.delegate = self
        
        receivedServices.removeAll()
        
        domainBrowser?.searchForServicesOfType(serviceIdentifier, inDomain: "local.")
    }
    
    /**
     Stop browsing for services
     */
    public func stop() {
 
        domainBrowser?.stop()
    }
    
    public func resolveService(service: NSNetService, completion: (result: Result) -> Void) {
        
        self.resolveCompletion = completion
        
        service.delegate = self
        service.resolveWithTimeout(10)
    }
    
    
    //MARK: - Timer
    
    private func startTimeoutTimer() {
        
        timer?.invalidate()
        
        elapsedTime = 0
        
        timer = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(BonjourBrowser.firedTimeoutTimer(_:)), userInfo: nil, repeats: true)
    }
    
    @objc private func firedTimeoutTimer(timer: NSTimer) {
        
        elapsedTime += 1
        
        if elapsedTime >= timeout {
            stopSearching()
            stop()
            
            searchCompletion?(services: nil)
        }
    }
    
    //MARK: - Searching
    
    private func stopSearching() {
        searching = false
        
        timer?.invalidate()
        timer = nil
    }
    
}

extension BonjourBrowser: NSNetServiceBrowserDelegate {

    public func netServiceBrowserWillSearch(browser: NSNetServiceBrowser) {
        
        searching = true
        
        delegate?.didStartSearching(browser: self)
    }
    
    public func netServiceBrowserDidStopSearch(browser: NSNetServiceBrowser) {
        
        stopSearching()
        
        delegate?.didStopSearching(browser: self)
    }
    
    public func netServiceBrowser(browser: NSNetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        
        print(errorDict)
        
        stopSearching()
        
        delegate?.didStopSearching(browser: self)
    }
    
    public func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
        
        if !receivedServices.contains(service) {
            receivedServices.append(service)
        }
        
        if moreComing == false {
            stopSearching()
            searchCompletion?(services: receivedServices)
        }
    }
    
    public func netServiceBrowser(browser: NSNetServiceBrowser, didRemoveService service: NSNetService, moreComing: Bool) {
        
        if let index = receivedServices.indexOf(service) {
            receivedServices.removeAtIndex(index)
        }
        
        removedServices.append(service)
        
        if moreComing == false {
            delegate?.browser(self, didRemoveServices: removedServices)
            
            removedServices.removeAll()
        }
    }
    
}

extension BonjourBrowser: NSNetServiceDelegate {
    
    public func netServiceDidResolveAddress(sender: NSNetService) {

        let result = Result.Success((host: sender.hostName!, port: sender.port))
        self.resolveCompletion?(result: result)
    }
    
    public func netService(sender: NSNetService, didNotResolve errorDict: [String : NSNumber]) {
        
        var details = [String: String]()
        details[NSLocalizedDescriptionKey] = "Error resolving service"
        let error = NSError(domain: "\(errorDict[NSNetServicesErrorDomain])", code: (errorDict[NSNetServicesErrorCode]?.integerValue)!, userInfo: details)
        print(error)
        
        sender.stop()
        
        self.resolveCompletion?(result: Result.Failure(Error.ResolveFailure))
    }
}

