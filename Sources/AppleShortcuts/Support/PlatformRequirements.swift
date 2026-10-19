//
//  PlatformRequirements.swift
//  AppleShortcuts
//
//  Created by David Sherlock on 2026.
//
//  `Tools.visibilityFlags` and `Tools.requirements`, read as far as measured.
//

import Foundation

enum PlatformRequirements {

    /// The Mac's platform number in `requirements`.
    static let mac = 3

    /// The visibility bit the Mac editor needs.
    static let macVisible = 4

    /// The platforms a requirements blob names.
    ///
    /// The blob is a protocol buffer: repeated field 1, each holding field 1,
    /// whose own field 1 is the platform as a varint — `0A 04 0A 02 08 03` is
    /// platform 3. An entry without that path (`0A 02 20 01`) names no
    /// platform and is skipped.
    static func platforms(_ blob: Data) -> [Int] {
        var platforms: [Int] = []
        for entry in Protobuf.fields(blob) where entry.number == 1 {
            guard case .bytes(let inner) = entry.value else { continue }
            for platform in Protobuf.fields(inner) where platform.number == 1 {
                guard case .bytes(let deepest) = platform.value else { continue }
                for value in Protobuf.fields(deepest) where value.number == 1 {
                    if case .varint(let number) = value.value { platforms.append(Int(number)) }
                }
            }
        }
        return platforms
    }

    static func availability(visibility: Int, requirements: Data) -> MacAvailability {
        if visibility & macVisible == 0 { return .refusedAtImport }
        let platforms = platforms(requirements)
        if !platforms.isEmpty, !platforms.contains(mac) { return .notOnMac }
        return .runs
    }
}

/// Just enough protocol-buffer reading for the catalogue's blobs.
enum Protobuf {

    enum Value: Equatable { case varint(UInt64), bytes(Data), other }

    struct Field: Equatable {
        let number: Int
        let value: Value
    }

    static func fields(_ data: Data) -> [Field] {
        let bytes = [UInt8](data)
        var index = 0
        var fields: [Field] = []
        func varint() -> UInt64? {
            var result: UInt64 = 0
            var shift: UInt64 = 0
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                result |= UInt64(byte & 0x7F) << shift
                if byte & 0x80 == 0 { return result }
                shift += 7
                if shift > 63 { return nil }
            }
            return nil
        }
        while index < bytes.count {
            guard let key = varint() else { break }
            let number = Int(key >> 3)
            switch key & 7 {
            case 0:
                guard let value = varint() else { return fields }
                fields.append(Field(number: number, value: .varint(value)))
            case 2:
                guard let length = varint(), index + Int(length) <= bytes.count else { return fields }
                fields.append(Field(number: number, value: .bytes(Data(bytes[index..<index + Int(length)]))))
                index += Int(length)
            case 1: index += 8; fields.append(Field(number: number, value: .other))
            case 5: index += 4; fields.append(Field(number: number, value: .other))
            default: return fields
            }
        }
        return fields
    }
}
