//
//  SimpleEndpoint.swift
//  Telepathy
//
//  Created by Oliver Larsson on 7/14/24.
//

import SwiftUI

public struct SimpleEndpoint: Hashable, Identifiable, Codable {
    
    public static let demoReceiver: Self? = .init(name: "Demo Receiver", localDNS: "DEMO")

    public var id = UUID()
    let name: String
    let localDNS: String
    
    init(name: String, localDNS: String) {
        self.name = name
        self.localDNS = localDNS
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(localDNS)
    }
    public static func == ( lhs: Self, rhs: Self ) -> Bool {
//        print("equalit: \(lhs.localDNS == rhs.localDNS)")
        return lhs.localDNS == rhs.localDNS
    }
}

public final class SelectedReceiver: ObservableObject {
    
    static let shared = SelectedReceiver()
    
    @Published var receiver: SimpleEndpoint? {
        didSet {
            save()
            print("recevier changed")

        }
    }
    
    
    public func isDemo() -> Bool {
        return receiver?.localDNS == SimpleEndpoint.demoReceiver?.localDNS
    }

    
    public func save() {
        do {
            let data = try JSONEncoder().encode(receiver)
            UserDefaults.standard.set(data, forKey: "selectedReceiver")
        } catch {
            print("Error encoding endpoints:", error.localizedDescription)
        }
    }
    public func erase() {
        receiver = nil
    }
    
    public func change(to receiver: SimpleEndpoint?) {
        self.receiver = receiver
    }
    
    // Fetch current saved selectedReceiver
    private init() {
        if let data = UserDefaults.standard.data(forKey: "selectedReceiver") {
            do {
                receiver = try JSONDecoder().decode(SimpleEndpoint.self, from: data)
            } catch {
                print("Error decoding selectedReceiver:", error.localizedDescription)
                receiver = nil
            }
        } else {
            receiver = nil
        }
    }
    public func getReceiver() -> SimpleEndpoint? {
        return receiver
    }
}

extension Notification.Name {
    static let receiverChanged = Notification.Name("receiverChanged")
}
