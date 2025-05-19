//
//  Connection.swift
//  TelepathAVR
//
//  Created by Oliver Larsson on 1/17/25.
//

import Foundation
import Network
import SwiftUI


public enum Zone: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }
    
    case one, two, three
    var alias: String {
        switch self {
        case .one:
            return "Main"
        case .two:
            return "Zone 2"
        case .three:
            return "Zone 3"
        }
    }
    var index: Int {
        switch self {
        case .one: return 0
        case .two: return 1
        case .three: return 2
        }
    }
    var defaults: String {
        switch self {
        case .one: return "zone1"
        case .two: return "zone2"
        case .three: return "zone3"
        }
    }
}

enum InputDevice: String, CaseIterable, Identifiable {
    case select, cd, tuner, dvd, bd, tv
    case sat_cbl = "sat/cbl", mplay, game
    case hdradio, net, pandora
    case siriusxm, spotify, lastfm
    case flickr, iradio, server
    case favorites, aux1, aux2
    case aux3, aux4, aux5, aux6, aux7

    var id: Self { self }
}

public class Connection: ObservableObject {
    
    
    public struct Zones {
        var powered: Bool
        var muted: Bool
        var volume: Double
    }
    
    
    static let shared = Connection()
    @Published var isDemoActive: Bool = false
    
    // Receiver Properties
    @Published var powered: Bool = false
    @Published var max: Double? = nil
    @Published var z1: Zones? = nil
    @Published var z2: Zones? = nil
    @Published var z3: Zones? = nil
    var zones: [Zone?] = [nil, nil, nil]
    @Published var selectedInput: [InputDevice] = [.select, .select, .select]
    
    func updateZones() {
        if !self.zones.contains(.one)
            && z1 != nil
        { zones[0] = .one }
        else if z1 == nil { zones[0] = nil }
        if !self.zones.contains(.two)
            && z2 != nil
        { zones[1] = .two }
        else if z2 == nil { zones[1] = nil }
        if !self.zones.contains(.three)
            && z3 != nil
        { zones[2] = .three }
        else if z3 == nil { zones[2] = nil }
    }
    
    let port = NWEndpoint.Port(rawValue: UInt16(23))!
    @Published var isConnected = false
    
    private var connection: NWConnection?
    
    struct Queue<T> {
        private var elements: [T] = []
        private let queueLock = NSLock()  // Lock for thread safety

        mutating func enqueue(_ element: T) {
            queueLock.lock()
            defer { queueLock.unlock() }
            elements.append(element)
        }

        mutating func last() -> T? {
            queueLock.lock()
            defer {
                elements = []  // Clear elements after retrieving last
                queueLock.unlock()
            }
            return elements.last
        }

        var isEmpty: Bool {
            return elements.isEmpty
        }
    }
    
    private var z1Queue = Queue<String>()
    private var z2Queue = Queue<String>()
    private var z3Queue = Queue<String>()
    
    func enterDemoMode() {
        isDemoActive = true
        if isDemoActive {
            print("Started Demo Connection")
            isConnected = true
        }
        
    }
    
    func start(receiver: SimpleEndpoint?) {
        self.updateZones()
        isDemoActive = receiver == SimpleEndpoint.demoReceiver
        print("isDemoActive \(isDemoActive)")
        
        if isDemoActive {
            connection = NWConnection(host: "DEMO", port: port, using: .tcp)
            z1 = .init(powered: true, muted: false, volume: 40)
            z2 = .init(powered: true, muted: false, volume: 40)
            z3 = .init(powered: true, muted: false, volume: 40)
            max = 98.0
            updateZones()
            isConnected = true
            print("Started Demo Connection")
            return
        }
        
        stop()
        
        guard let receiver = receiver else {
            // Receiver is nil, cancel existing connection if any
            connection?.cancel()
            connection = nil
            return
        }
        let hostDNS = NWEndpoint.Host(receiver.localDNS)
        let newConnection = NWConnection(host: hostDNS, port: port, using: .tcp)
        
        newConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if let innerEndpoint = newConnection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = innerEndpoint {
                    print("Connected to \(host):\(port)")
                    self.getVitals()
                    self.statusChecker(newConnection)
                }
                // Update isConnected state or perform other actions upon successful connection
                self.isConnected = true
                DispatchQueue.global(qos: .userInitiated).async {
                    self.handleVolumeOne()
                    self.handleVolumeTwo()
                    self.handleVolumeThree()
                    
                    self.connection!.receive(minimumIncompleteLength: 1, maximumLength: 10000) { content, _, _, _ in
                        if let content = content {
                            self.processReceiveData(content: content, connection: self.connection!)
                        }
                    }
                }
                                    
            default:
                self.isConnected = false
                print(state)
            }
        }
        
        newConnection.start(queue: DispatchQueue.main)
        
        connection = newConnection
    }
    func stop() {
        connection?.cancel()
        self.isConnected = false
        connection = nil
        powered = false
        max = nil
        z1 = nil
        z2 = nil
        z3 = nil
        self.updateZones()

        return
    }
    
    func checkConnection() {
        
        self.updateZones()
        if isDemoActive {
            isConnected = true
            return
        }
        
        guard let connection = connection else {
            self.isConnected = false
            return
        }
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.isConnected = true
            default:
                self.isConnected = false
                print(state)
            }
        }
    }
    
    func getPowerState(_ zone: Zone) -> Bool {
        switch zone {
        case .one: return z1?.powered ?? false
        case .two: return z2?.powered ?? false
        case .three: return z3?.powered ?? false
        }
    }
    
    func statusChecker(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.isConnected = true
            default:
                self.isConnected = false
                print(state)
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: {
                self.statusChecker(connection)
            })
        }
    }
    
    func processReceiveData(content: Data, connection: NWConnection){
        DispatchQueue.main.async {
            
            let str = String(data: content, encoding: .utf8)!
            let commands = str.split(separator: "\r")
            
            commands.forEach { str in
                if str.starts(with: "MVMAX ") {
                    // MAX Volume
                    let components = str.split(separator: " ")
                    if let lastComponent = components.last {
                        let maxVolFloat = self.stringToVolume(lastComponent)
                        if self.max != maxVolFloat {
                            self.max = maxVolFloat
                        }
                    }
                   
                } else if str.starts(with: "MV") {
                    if self.z1 == nil { // Initialize zone 1 if not already
                        self.z1 = .init(powered: false, muted: false, volume: 0)
                        self.updateZones()
                    }
                    
                    // MAIN Volume
                    let vol = str.dropFirst(2)
                    self.z1?.volume = self.stringToVolume(vol)                    
                } else if str.starts(with: "Z2") && str.count >= 4 {
                    // ZONE 2
                    if self.z2 == nil { // Initialize zone 2 if not already
                        self.z2 = .init(powered: false, muted: false, volume: 0)
                        self.updateZones()
                    }
                    
                    let droppedFirst2 = str.dropFirst(2)
                    
                    if droppedFirst2.starts(with: "MU") {
                        self.z2?.muted = droppedFirst2.dropFirst(2) == "ON"
                    }
                    else if droppedFirst2 == "ON" || droppedFirst2 == ("OFF") {
                        self.z2?.powered = droppedFirst2 == "ON"
                    }
                    else if let vol = Int(droppedFirst2) {
                        self.z2?.volume = Double(vol) // Zone 2, 3 do not have 0.5 increments in volume
                    }
                    
                } else if str.starts(with: "Z3") && str.count >= 4 {
                    // ZONE3
                    if self.z3 == nil { // Initialize zone 3 if not already
                        self.z3 = .init(powered: false, muted: false, volume: 0)
                        self.updateZones()
                    }
                    let droppedFirst2 = str.dropFirst(2)
                    
                    if droppedFirst2.starts(with: "MU") {
                        self.z3?.muted = droppedFirst2.dropFirst(2) == "ON"
                    }
                    else if droppedFirst2 == "ON" || droppedFirst2 == ("OFF") {
                        self.z3?.powered = droppedFirst2 == "ON"
                    }
                    else if let vol = Int(droppedFirst2) {
                        self.z3?.volume = Double(vol)
                    }
                } else if str.starts(with: "PW") {
                    // POWER state
                    let state = str.dropFirst(2)
                    self.powered = state == "ON"
                } else if str.starts(with: "ZM") {
                    if self.z2 == nil { // Initialize zone 2 if not already
                        self.z2 = .init(powered: false, muted: false, volume: 0)
                        self.updateZones()
                    }
                    
                    // ZM State
                    let droppedFirst2 = str.dropFirst(2)
                    if droppedFirst2 == "ON" || droppedFirst2 == "OFF" {
                        self.z1?.powered = droppedFirst2 == "ON"
                    }
                } else if str.starts(with: "MU") {
                    self.z1?.muted = str.dropFirst(2) == "ON"
                }
                
                /*
                else if str.starts(with: "SI") {
                    // Implement input mode reading
                    let deviceStr = str.dropFirst(2)
                    let inputDevice: InputDevice = InputDevice.allCases
                        .first(where: { $0.rawValue == String(deviceStr) })
                        ?? InputDevice.select
                    if inputDevice != InputDevice.select
                        && InputDevice.allCases.contains(inputDevice) {
                        // How do you know what zone is being affected????
                    }
                }
                 */
            }

            
            // Persistant recieve data
            self.connection?.receive(minimumIncompleteLength: 1, maximumLength: 10000) { content, _, _, _ in
                if let content = content {
                    self.processReceiveData(content: content, connection: self.connection!)
                }
            }
        }
    }
    
    func stringToVolume(_ value: Substring.SubSequence) -> CGFloat {
        let length = value.count
        if let convertedD = Int(value) {
            if length == 3 {
                let convertedCGF = Double(convertedD)/10
                return convertedCGF
            }
            let convertedCGF = Double(convertedD)
            return convertedCGF
        }
        else {
            return 0.0
        }
    }
    
    func getVitals() {
        
        guard !isDemoActive else { return }
        
        guard let connection = connection else {
            print("could not get vitals: connection nil")
            return
        }
        let command = "PW?\r\nMV?\r\nZM?\r\nZ2?\r\nZ3?\r\nMU?\r\nZ2MU?\r\nZ3MU?\r\nSI?\r\n"
        let commandData = command.data(using: .utf8)!
        
        connection.send(content: commandData, completion: .contentProcessed { error in
            if let error = error {
                debugPrint("Error sending data: \(error)")
            } else {
                print("Command Sent Successfully \(commandData)")
            }
        })
        self.updateZones()
    }
    
    func enqueueVolume(_ volume: Double, _ zone: Zone) {
        
        
        if isDemoActive {
            switch zone {
            case .one:
                z1?.volume = volume
            case .two:
                z2?.volume = volume
            case .three:
                z3?.volume = volume
            }
            return
        }
        
        // Format such that if length is 2, add zero in front
        var vol = String(Int(volume*10)).count == 2 ? "0" + String(Int(volume*10)) : "" + String(Int(volume*10))
        if vol == "0" {
            vol = "00"
        }
  
        switch zone {
        case .one:
            z1Queue.enqueue(vol)
            print("getting \(vol)")
        case .two:
            if vol.count == 3 {
                vol = String(vol.dropLast())
            }
            z2Queue.enqueue(vol)
        case .three:
            if vol.count == 3 {
                vol = String(vol.dropLast())
            }
            z3Queue.enqueue(vol)
        }

    }
    
    func setInputDevice(_ input: InputDevice, _ index: Int) {
        
        
        if isDemoActive {
            selectedInput[index] = input
            return
        }
        guard let connection = connection else {
            print("could not toggle power: connection nil")
            return
        }
        var command: String = ""
        switch index {
        case 0: command = "SI\(input.rawValue)\r\n"
        case 1: command = "Z2\(input.rawValue)\r\n"
        case 2: command = "Z3\(input.rawValue)\r\n"
        default:
            print("Invalid index")
        }
        command = command.uppercased()
        let commandData = command.data(using: .utf8)!
        print(command)
        
        connection.send(content: commandData, completion: .contentProcessed { error in
            if let error = error {
                debugPrint("Error sending data: \(error)")
            } else {
                print("Command Sent Successfully \(commandData)")
            }
        })
    }
    
    func waitForMain(completion: @escaping (String) -> Void) {
        if let value = z1Queue.last() {
            completion(value)
        }
    }
    func waitForTwo(completion: @escaping (String) -> Void) {
        if let value = z2Queue.last() {
            completion(value)
        }
    }
    func waitForThree(completion: @escaping (String) -> Void) {
        if let value = z3Queue.last() {
            completion(value)
        }
    }

    
    func handleVolumeOne() {
    
        DispatchQueue.global(qos: .background).async {
            self.waitForMain { value in
                
                guard let connection = self.connection else {
                    print("Connection is not established.")
                    self.handleVolumeOne()
                    return
                }
                let commandData = ("MV\(value)").data(using: .utf8)!
                
                connection.send(content: commandData, completion: .contentProcessed({ error in
                    if let error = error {
                        print("Send error: \(error)")
                    }
                }))
            }
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000)
                self.handleVolumeOne()
            }
        }
    }
    func handleVolumeTwo() {
        DispatchQueue.global(qos: .background).async {
            self.waitForTwo { value in
                
                guard let connection = self.connection else {
                    print("Connection is not established.")
                    self.handleVolumeTwo()
                    return
                }
                
                let commandData = ("Z2\(value)").data(using: .utf8)!
                
                connection.send(content: commandData, completion: .contentProcessed({ error in
                    if let error = error {
                        print("Send error: \(error)")
                    }
                }))
            }
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000)
                self.handleVolumeTwo()
            }
        }
    }
    func handleVolumeThree() {
    
        DispatchQueue.global(qos: .background).async {
            self.waitForThree { value in
                
                guard let connection = self.connection else {
                    print("Connection is not established.")
                    self.handleVolumeThree()
                    return
                }
                let commandData = ("Z3\(value)").data(using: .utf8)!
                
                connection.send(content: commandData, completion: .contentProcessed({ error in
                    if let error = error {
                        print("Send error: \(error)")
                    }
                }))
            }
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000)
                self.handleVolumeThree()
            }
        }
    }
    
    func powerToggle() {
        
        if isDemoActive {
            return // To be implemented
        }
        guard let connection = connection else {
            print("could not toggle power: connection nil")
            return
        }
        let command = powered ? "PWSTANDBY" : "PWON"
        let commandData = command.data(using: .utf8)!
        print("powertoggle")
        
        connection.send(content: commandData, completion: .contentProcessed { error in
            if let error = error {
                debugPrint("Error sending data: \(error)")
            } else {
                print("Command Sent Successfully \(commandData)")
            }
        })
    }
    func zoneToggle(_ zone: Zone) {
        
        print("isDemoActive \(isDemoActive)")
        print("isConnected \(isConnected)")
//        isDemoActive = selectedReceiver.isDemo()
        
        if isDemoActive {
            switch zone {
            case .one: z1?.powered.toggle()
            case .two: z2?.powered.toggle()
            case .three: z3?.powered.toggle()
            }
            return
        }
        
        guard let connection = connection else {
            print("could not toggle power: connection nil")
            return
        }
        var command: String
        switch zone {
        case .one: command = z1?.powered ?? true ? "ZMOFF" : "ZMON"
        case .two: command = z2?.powered ?? true ? "Z2OFF" : "Z2ON"
        case .three: command = z3?.powered ?? true ? "Z3OFF" : "Z3ON"
        }
        let commandData = command.data(using: .utf8)!
        
        print(command)
        
        connection.send(content: commandData, completion: .contentProcessed { error in
            if let error = error {
                debugPrint("Error sending data: \(error)")
            } else {
                print("Command Sent Successfully \(commandData)")
            }
        })
    }
    func toggleMute(_ zone: Zone) {
        
//        isDemoActive = selectedReceiver.isDemo()
        
        if isDemoActive {
            switch zone {
            case .one: z1?.muted.toggle()
            case .two: z2?.muted.toggle()
            case .three: z3?.muted.toggle()
            }
            return
        }
        
        guard let connection = connection else {
            print("could not toggle power: connection nil")
            return
        }
        var command: String
        switch zone {
        case .one: command = z1?.muted ?? true ? "MUOFF" : "MUON"
        case .two: command = z2?.muted ?? true ? "Z2MUOFF" : "Z2MUON"
        case .three: command = z3?.muted ?? true ? "Z3MUOFF" : "Z3MUON"
        }
        let commandData = command.data(using: .utf8)!
        
        connection.send(content: commandData, completion: .contentProcessed { error in
            if let error = error {
                debugPrint("Error sending data: \(error)")
            } else {
                print("Command Sent Successfully \(commandData)")
            }
        })
        self.getVitals()
    }
}

