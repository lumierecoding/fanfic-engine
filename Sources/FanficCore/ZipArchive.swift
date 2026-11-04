import Compression
import Foundation

/// A minimal read-only ZIP reader (enough for EPUB files).
/// Reads the central directory, supports stored (0) and deflate (8) entries. No ZIP64, no encryption.
public struct ZipArchive: Sendable {
    /// The largest entry that is unpacked (SPEC section 3). Checked before any memory is reserved, so an entry that
    /// claims to unpack to gigabytes is refused. The largest text document in a real library of 809 AO3 EPUBs was 0.27 MB.
    public static let maxEntrySize = 16 * 1024 * 1024

    public struct Entry: Sendable {
        public let name: String
        let method: UInt16
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    public enum ZipError: LocalizedError {
        case notAZip
        case damaged
        case unsupported(String)
        case missingEntry(String)
        case tooLarge(String)

        public var errorDescription: String? {
            switch self {
            case .notAZip: "not a ZIP/EPUB file"
            case .damaged: "the EPUB file is damaged"
            case .unsupported(let what): "unsupported EPUB packing (\(what))"
            case .missingEntry(let name): "\(name) is missing inside the EPUB"
            case .tooLarge(let name): "\(name) inside the EPUB is larger than 16 MB"
            }
        }
    }

    private let bytes: [UInt8]
    public let entries: [Entry]

    public init(data: Data) throws {
        let bytes = [UInt8](data)
        let n = bytes.count
        guard n >= 22 else { throw ZipError.notAZip }

        // End of central directory record: last 22 bytes plus an optional comment of up to 65535 bytes.
        var eocd = -1
        var i = n - 22
        let lowest = max(0, n - 22 - 65_535)
        while i >= lowest {
            if Self.u32(bytes, i) == 0x0605_4B50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ZipError.notAZip }

        let count = Int(Self.u16(bytes, eocd + 10))
        let directoryOffset = Int(Self.u32(bytes, eocd + 16))
        guard directoryOffset != 0xFFFF_FFFF, count != 0xFFFF else { throw ZipError.unsupported("ZIP64") }

        var entries: [Entry] = []
        entries.reserveCapacity(count)
        var p = directoryOffset
        for _ in 0..<count {
            guard p + 46 <= n, Self.u32(bytes, p) == 0x0201_4B50 else { throw ZipError.damaged }
            let flags = Self.u16(bytes, p + 8)
            let method = Self.u16(bytes, p + 10)
            let compressed = Int(Self.u32(bytes, p + 20))
            let uncompressed = Int(Self.u32(bytes, p + 24))
            let nameLength = Int(Self.u16(bytes, p + 28))
            let extraLength = Int(Self.u16(bytes, p + 30))
            let commentLength = Int(Self.u16(bytes, p + 32))
            let localOffset = Int(Self.u32(bytes, p + 42))
            guard p + 46 + nameLength <= n else { throw ZipError.damaged }
            if flags & 0x1 != 0 { throw ZipError.unsupported("encrypted") }
            let nameBytes = Array(bytes[(p + 46)..<(p + 46 + nameLength)])
            let name = String(bytes: nameBytes, encoding: .utf8)
                ?? String(bytes: nameBytes, encoding: .isoLatin1) ?? ""
            entries.append(Entry(name: name, method: method, compressedSize: compressed,
                                 uncompressedSize: uncompressed, localHeaderOffset: localOffset))
            p += 46 + nameLength + extraLength + commentLength
        }
        self.bytes = bytes
        self.entries = entries
    }

    public func contains(_ name: String) -> Bool { entry(named: name) != nil }

    /// The uncompressed bytes of one entry. Name lookup is exact first, then case-insensitive.
    public func contents(of name: String) throws -> Data {
        guard let entry = entry(named: name) else { throw ZipError.missingEntry(name) }
        guard entry.compressedSize <= Self.maxEntrySize, entry.uncompressedSize <= Self.maxEntrySize else {
            throw ZipError.tooLarge(entry.name)
        }
        let o = entry.localHeaderOffset
        guard o + 30 <= bytes.count, Self.u32(bytes, o) == 0x0403_4B50 else { throw ZipError.damaged }
        let start = o + 30 + Int(Self.u16(bytes, o + 26)) + Int(Self.u16(bytes, o + 28))
        guard start + entry.compressedSize <= bytes.count else { throw ZipError.damaged }
        let slice = bytes[start..<(start + entry.compressedSize)]

        switch entry.method {
        case 0:
            return Data(slice)
        case 8:
            if entry.uncompressedSize == 0 { return Data() }
            guard entry.compressedSize > 0 else { throw ZipError.damaged }
            var output = [UInt8](repeating: 0, count: entry.uncompressedSize)
            let written = slice.withUnsafeBufferPointer { source in
                output.withUnsafeMutableBufferPointer { destination in
                    // COMPRESSION_ZLIB is raw DEFLATE (RFC 1951), which is what ZIP uses.
                    compression_decode_buffer(destination.baseAddress!, entry.uncompressedSize,
                                              source.baseAddress!, source.count, nil, COMPRESSION_ZLIB)
                }
            }
            guard written == entry.uncompressedSize else { throw ZipError.damaged }
            return Data(output)
        default:
            throw ZipError.unsupported("compression method \(entry.method)")
        }
    }

    private func entry(named name: String) -> Entry? {
        if let exact = entries.first(where: { $0.name == name }) { return exact }
        let lower = name.lowercased()
        return entries.first { $0.name.lowercased() == lower }
    }

    private static func u16(_ b: [UInt8], _ o: Int) -> UInt16 {
        guard o + 2 <= b.count else { return 0 }
        return UInt16(b[o]) | UInt16(b[o + 1]) << 8
    }

    private static func u32(_ b: [UInt8], _ o: Int) -> UInt32 {
        guard o + 4 <= b.count else { return 0 }
        return UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24
    }
}
