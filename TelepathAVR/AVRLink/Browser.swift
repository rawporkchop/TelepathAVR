//
//  Browser.swift
//  Telepathy
//
//  Created by Oliver Larsson on 7/10/24.
//

import Foundation
import Network

final class Browser: ObservableObject
{
    private var serviceType = "_http._tcp."
    
    var browser: NWBrowser
    @Published var endpoints: Set<SimpleEndpoint> {
        didSet {
            saveEndpoints()
        }
    }
    
    init() {
        browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: .tcp)
        
        // Load endpoints from UserDefaults on initialization
        if let data = UserDefaults.standard.data(forKey: "savedEndpoints") {
            do {
                endpoints = try JSONDecoder().decode(Set<SimpleEndpoint>.self, from: data)
            } catch {
                print("Error decoding endpoints:", error.localizedDescription)
                endpoints = []
            }
        } else {
            endpoints = []
        }
    }

    private func saveEndpoints() {
        do {
            let data = try JSONEncoder().encode(Array(endpoints))
            UserDefaults.standard.set(data, forKey: "savedEndpoints")
        } catch {
            print("Error encoding endpoints:", error.localizedDescription)
        }
    }
    
    func start() {
        doBrowse()
        browser.start(queue: DispatchQueue.main)
    }
    func restart() {
        endpoints = []
        browser = NWBrowser(for: .bonjour(type: serviceType.isEmpty ? "_heos-audio._tcp." : serviceType, domain: nil), using: .tcp)
        start()
    }
    func close() {
        browser.cancel()
    }
    
    private func doBrowse() {
        browser.browseResultsChangedHandler = { (results, changes) in
            for result in results {
                switch result.endpoint {
                case .service(let service):
                    self.findDNS(domain: service.domain, type: service.type, name: service.name) { resolvedHostName in
                        if let hostName = resolvedHostName {
                            self.endpoints.insert(SimpleEndpoint(name: service.name, localDNS: hostName))
                        } else {
                            print("Failed to resolve host name")
                        }
                    }
                    
                default:
                    assertionFailure("Unexpected endpoint type")
                }
            }
            
            for change in changes {
                switch change {
                case .added(let added):
                    switch added.endpoint {
                    case .service(let service):
                        self.findDNS(domain: service.domain, type: service.type, name: service.name) { resolvedHostName in
                            if let hostName = resolvedHostName {
                                self.endpoints.insert(SimpleEndpoint(name: service.name, localDNS: hostName))
                            } else {
                                print("Failed to resolve host name")
                            }
                        }
                    default:
                        assertionFailure("Unexpected endpoint type")
                    }
                default:
                    break
                }
            }
        }
    }
    
    private func findDNS(domain: String, type: String, name: String, completion: @escaping (String?) -> Void) {
        let service = NetService(domain: domain, type: type, name: name)
        
        BonjourResolver.resolve(service: service) { result in
            switch result {
            case .success(let hostName):
                completion(hostName)  // Call the completion handler with the hostName
            case .failure(let error):
                completion(nil)  // Call the completion handler with nil
                print("error resolving hostName: \(error)")
            }
        }
    }
}

final class BonjourResolver: NSObject, NetServiceDelegate {
    typealias CompletionHandler = (Result<(String), Error>) -> Void
    @discardableResult
    static func resolve(service: NetService, completionHandler: @escaping CompletionHandler) -> BonjourResolver {
        precondition(Thread.isMainThread)
        let resolver = BonjourResolver(service: service, completionHandler: completionHandler)
        resolver.start()
        return resolver
    }
    
    private init(service: NetService, completionHandler: @escaping CompletionHandler) {
        // We want our own copy of the service because we’re going to set a
        // delegate on it but `NetService` does not conform to `NSCopying` so
        // instead we create a copy by copying each property.
        let copy = NetService(domain: service.domain, type: service.type, name: service.name)
        self.service = copy
        self.completionHandler = completionHandler
    }
    
    deinit {
        // If these fire the last reference to us was released while the resolve
        // was still in flight.  That should never happen because we retain
        // ourselves on `start`.
        assert(self.service == nil)
        assert(self.completionHandler == nil)
        assert(self.selfRetain == nil)
    }
    
    private var service: NetService? = nil
    private var completionHandler: (CompletionHandler)? = nil
    private var selfRetain: BonjourResolver? = nil
    
    private func start() {
        precondition(Thread.isMainThread)
        guard let service = self.service else { fatalError() }
        service.delegate = self
        service.resolve(withTimeout: 5.0)
        // Form a temporary retain loop to prevent us from being deinitialised
        // while the resolve is in flight.  We break this loop in 'stop(with:)'.
        selfRetain = self
    }
    
    func stop() {
        self.stop(with: .failure(CocoaError(.userCancelled)))
    }
    
    private func stop(with result: Result<(String), Error>) {
        precondition(Thread.isMainThread)
        self.service?.delegate = nil
        self.service?.stop()
        self.service = nil
        let completionHandler = self.completionHandler
        self.completionHandler = nil
        completionHandler?(result)
        
        selfRetain = nil
    }
    
    func netServiceDidResolveAddress(_ sender: NetService) {
        let hostName = sender.hostName!
        self.stop(with: .success((hostName)))
    }
    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        let code = (errorDict[NetService.errorCode]?.intValue)
            .flatMap { NetService.ErrorCode.init(rawValue: $0) }
            ?? .unknownError
        let error = NSError(domain: NetService.errorDomain, code: code.rawValue, userInfo: nil)
        self.stop(with: .failure(error))
    }
}
