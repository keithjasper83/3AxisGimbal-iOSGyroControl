import Foundation
import CoreBluetooth
import Combine

enum BLEConnectionState {
    case disconnected
    case scanning
    case connecting
    case connected
}

class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    @Published var connectionState: BLEConnectionState = .disconnected
    @Published var lastError: String?
    @Published var statusMessage: String = "ready"
    
    private var centralManager: CBCentralManager!
    private var targetPeripheral: CBPeripheral?
    
    // Service & Characteristics UUIDs
    private let serviceUUID = CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")
    private let rxCharacteristicUUID = CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")
    private let txCharacteristicUUID = CBUUID(string: "19B10002-E8F2-537E-4F6C-D104768A1214")
    
    private var rxCharacteristic: CBCharacteristic?
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            lastError = "Bluetooth is not powered on"
            return
        }
        
        connectionState = .scanning
        lastError = nil
        centralManager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }
    
    func stopScanning() {
        centralManager.stopScan()
        if connectionState == .scanning {
            connectionState = .disconnected
        }
    }
    
    func disconnect() {
        if let peripheral = targetPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        targetPeripheral = nil
        rxCharacteristic = nil
        connectionState = .disconnected
    }
    
    func sendCommand(_ message: String) {
        guard let rx = rxCharacteristic, let peripheral = targetPeripheral else {
            return
        }
        
        if let data = message.data(using: .utf8) {
            peripheral.writeValue(data, for: rx, type: .withoutResponse)
        }
    }
    
    // MARK: - CBCentralManagerDelegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            break
        case .poweredOff:
            lastError = "Bluetooth is powered off."
            disconnect()
        case .unauthorized:
            lastError = "Bluetooth usage unauthorized. Please enable in Settings."
            disconnect()
        case .unsupported:
            lastError = "Bluetooth low energy not supported on this device."
            disconnect()
        default:
            lastError = "Bluetooth state unknown: \(central.state.rawValue)"
            disconnect()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
        if name == "Gimbal-ESP32" || advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] != nil {
            centralManager.stopScan()
            targetPeripheral = peripheral
            targetPeripheral?.delegate = self
            connectionState = .connecting
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectionState = .connecting
        peripheral.discoverServices([serviceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        lastError = "Failed to connect: \(error?.localizedDescription ?? "unknown error")"
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        connectionState = .disconnected
        rxCharacteristic = nil
        targetPeripheral = nil
    }
    
    // MARK: - CBPeripheralDelegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            lastError = "Service discovery failed: \(error.localizedDescription)"
            disconnect()
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            if service.uuid == serviceUUID {
                peripheral.discoverCharacteristics([rxCharacteristicUUID, txCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            lastError = "Characteristic discovery failed: \(error.localizedDescription)"
            disconnect()
            return
        }
        
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.uuid == rxCharacteristicUUID {
                rxCharacteristic = characteristic
            } else if characteristic.uuid == txCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        if rxCharacteristic != nil {
            connectionState = .connected
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error updating value: \(error.localizedDescription)")
            return
        }
        
        if characteristic.uuid == txCharacteristicUUID, let data = characteristic.value {
            if let statusStr = String(data: data, encoding: .ascii) {
                DispatchQueue.main.async {
                    self.statusMessage = statusStr
                }
            }
        }
    }
}
