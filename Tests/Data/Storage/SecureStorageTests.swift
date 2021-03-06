#if canImport(SwiftCheck)

import XCTest
import SwiftCheck
@testable import AppsPlusData

class SecureStorageTests: XCTestCase {
    
    var storage: SecureStorageImpl!
    var mockKeychain: MockKeychainAccess!
    var encoder: JSONEncoder!
    var decoder: JSONDecoder!
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainAccess()
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        
        storage = SecureStorageImpl(keychain: mockKeychain, encoder: encoder, decoder: decoder)
    }
    
    override func tearDown() {
        mockKeychain = nil
        encoder = nil
        decoder = nil
        storage = nil
        super.tearDown()
    }
    
    func test_settingValues() {
        property("Adding string value sets the string correctly") <- forAll(String.arbitrary) { [unowned self] in
            try? storage.setString($0, forKey: .testKey)
            
            return mockKeychain.addedValues[.testKey] == $0
        }
        
        property("Adding codable value sets the value correctly") <- forAll(MockCodable.arbitrary) { [unowned self] in
            try? storage.setValue($0, forKey: .testKey)
            
            let decodedObject = try? decoder.decode(MockCodable.self, from: mockKeychain.addedItem!)
            
            return decodedObject == $0
        }
    }
    
    func test_gettingValues() {
        property("Getting string value is the same as stored string") <- forAll(String.arbitrary) { [unowned self] in
            mockKeychain.returnedString = $0
            
            return storage.string(forKey: .testKey) == $0
        }
        
        property("Getting codable value is the same as stored codeable value") <- forAll(MockCodable.arbitrary) { [unowned self] in
            let encodedData = try? encoder.encode($0)
            mockKeychain.returnedData = encodedData
            
            return storage.value(forKey: .testKey) == $0
        }
    }
    
    func test_removingValues() {
        property("Setting nil string value removes the correct key") <- forAll { [unowned self] (key: SecureStorageKey) in
            try? storage.setString(nil, forKey: key)
            return mockKeychain.removedItemKey == key.rawValue
        }
        
        property("Setting nil codable value removes the correct key") <- forAll { [unowned self] (key: SecureStorageKey) in
            let mockCodable: MockCodable? = nil
            
            try? storage.setValue(mockCodable, forKey: key)
            return mockKeychain.removedItemKey == key.rawValue
        }
    }
    
}

extension SecureStorageKey: Arbitrary {
    
    static let testKey = SecureStorageKey(value: "testKey")
    
    public static var arbitrary: Gen<SecureStorageKey> {
        Gen.compose {
            return SecureStorageKey(value: $0.generate())
        }
    }
    
    public static func == (lhs: SecureStorageKey, rhs: SecureStorageKey) -> Bool {
        return lhs.rawValue == rhs.rawValue
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
    
}

#endif
