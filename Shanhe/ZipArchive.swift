import Foundation
import zlib

/// Standard ZIP (stored / raw DEFLATE), with CRC and traversal validation. No third-party dependency.
enum ZipArchive {
    private static func fail() -> TravelError { .message("备份 ZIP 无效、已加密，或使用了不支持的 ZIP64 格式。") }
    private static func crc(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { bytes in UInt32(crc32(0, bytes.bindMemory(to: Bytef.self).baseAddress, uInt(data.count))) }
    }
    static func write(_ entries: [(String, Data)]) throws -> Data {
        guard entries.count <= 10000 else { throw TravelError.message("备份照片数量过多。") }
        var body = Data(), directory = Data()
        for (name, bytes) in entries {
            guard name == "records.json" || TravelRules.safePhoto(name) else { throw fail() }
            let filename = Data(name.utf8), checksum = crc(bytes), offset = UInt32(body.count)
            guard body.count + bytes.count < TravelRules.maximumArchiveBytes else { throw TravelError.message("iOS 备份目前最大 256 MB。") }
            body.u32(0x04034b50); body.u16(20); body.u16(0x800); body.u16(0); body.u16(0); body.u16(0x0021)
            body.u32(checksum); body.u32(UInt32(bytes.count)); body.u32(UInt32(bytes.count)); body.u16(UInt16(filename.count)); body.u16(0)
            body.append(filename); body.append(bytes)
            directory.u32(0x02014b50); directory.u16(20); directory.u16(20); directory.u16(0x800); directory.u16(0); directory.u16(0); directory.u16(0x0021)
            directory.u32(checksum); directory.u32(UInt32(bytes.count)); directory.u32(UInt32(bytes.count)); directory.u16(UInt16(filename.count)); directory.u16(0); directory.u16(0); directory.u16(0); directory.u16(0); directory.u32(0); directory.u32(offset); directory.append(filename)
        }
        let start = UInt32(body.count); body.append(directory)
        body.u32(0x06054b50); body.u16(0); body.u16(0); body.u16(UInt16(entries.count)); body.u16(UInt16(entries.count)); body.u32(UInt32(directory.count)); body.u32(start); body.u16(0)
        guard body.count <= TravelRules.maximumArchiveBytes else { throw TravelError.message("iOS 备份目前最大 256 MB。") }; return body
    }
    static func read(_ archive: Data) throws -> [String: Data] {
        guard archive.count >= 22, archive.count <= TravelRules.maximumArchiveBytes else { throw TravelError.message("备份为空或超过 iOS 当前 256 MB 限制。") }
        let data = Data(archive), low = max(0, archive.count - 65557)
        guard let end = stride(from: data.count - 22, through: low, by: -1).first(where: { offset in
            (try? data.read32(offset)) == 0x06054b50 && (try? data.read16(offset + 20)).map { offset + 22 + Int($0) == data.count } == true
        }) else { throw fail() }
        guard try data.read16(end + 4) == 0, try data.read16(end + 6) == 0 else { throw fail() }
        let count = Int(try data.read16(end + 10)), centralSize = Int(try data.read32(end + 12)), centralStart = Int(try data.read32(end + 16))
        guard count <= 10000, count == Int(try data.read16(end + 8)), centralStart <= end, centralSize <= end - centralStart else { throw fail() }
        var cursor = centralStart, total = 0, output: [String: Data] = [:]
        for _ in 0..<count {
            guard try data.read32(cursor) == 0x02014b50 else { throw fail() }
            let flags = try data.read16(cursor + 8), method = try data.read16(cursor + 10), checksum = try data.read32(cursor + 16)
            let compressed = Int(try data.read32(cursor + 20)), size = Int(try data.read32(cursor + 24)), nameSize = Int(try data.read16(cursor + 28))
            let extraSize = Int(try data.read16(cursor + 30)), commentSize = Int(try data.read16(cursor + 32)), local = Int(try data.read32(cursor + 42))
            let next = cursor + 46 + nameSize + extraSize + commentSize
            guard flags & 1 == 0, [UInt16(0), 8].contains(method), next <= centralStart + centralSize,
                  size <= TravelRules.maximumPhotoBytes, try data.read16(cursor + 34) == 0,
                  let name = String(data: try data.bytes(cursor + 46, nameSize), encoding: .utf8) else { throw fail() }
            cursor = next
            if name.hasSuffix("/") { continue }
            guard name == "records.json" || TravelRules.safePhoto(name), output[name] == nil else { throw fail() }
            total += size; guard total <= TravelRules.maximumArchiveBytes else { throw TravelError.message("备份解压后超过 256 MB。") }
            guard try data.read32(local) == 0x04034b50, try data.read16(local + 8) == method, try data.read16(local + 6) & 1 == 0 else { throw fail() }
            let localNameSize = Int(try data.read16(local + 26)), localExtra = Int(try data.read16(local + 28))
            guard try data.bytes(local + 30, localNameSize) == Data(name.utf8) else { throw fail() }
            let payload = local + 30 + localNameSize + localExtra
            guard payload <= centralStart, compressed <= centralStart - payload else { throw fail() }
            let packed = try data.bytes(payload, compressed)
            let unpacked: Data
            if method == 0 { unpacked = packed } else { unpacked = try inflateRaw(packed, size: size) }
            guard unpacked.count == size, crc(unpacked) == checksum else { throw TravelError.message("备份文件校验失败，现有数据未被覆盖。") }
            output[name] = unpacked
        }
        guard output["records.json"] != nil else { throw TravelError.message("这个 ZIP 不是山河足迹的完整备份。") }; return output
    }
    private static func inflateRaw(_ input: Data, size: Int) throws -> Data {
        var stream = z_stream(), output = Data(count: max(1, size))
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw fail() }
        defer { inflateEnd(&stream) }
        let result = input.withUnsafeBytes { source in
            output.withUnsafeMutableBytes { target -> Int32 in
                stream.next_in = UnsafeMutablePointer(mutating: source.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(input.count); stream.next_out = target.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(max(1, size)); return inflate(&stream, Z_FINISH)
            }
        }
        guard result == Z_STREAM_END, stream.total_out == uLong(size), stream.avail_in == 0 else { throw fail() }
        return Data(output.prefix(size))
    }
}

private extension Data {
    mutating func u16(_ value: UInt16) { var v = value.littleEndian; Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) } }
    mutating func u32(_ value: UInt32) { var v = value.littleEndian; Swift.withUnsafeBytes(of: &v) { append(contentsOf: $0) } }
    func read16(_ offset: Int) throws -> UInt16 {
        guard offset >= 0, offset <= count - 2 else { throw TravelError.message("ZIP 文件截断。") }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }
    func read32(_ offset: Int) throws -> UInt32 {
        guard offset >= 0, offset <= count - 4 else { throw TravelError.message("ZIP 文件截断。") }
        return UInt32(self[offset]) | UInt32(self[offset + 1]) << 8 | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }
    func bytes(_ offset: Int, _ length: Int) throws -> Data {
        guard offset >= 0, length >= 0, offset <= count, length <= count - offset else { throw TravelError.message("ZIP 文件截断。") }
        return subdata(in: offset..<(offset + length))
    }
}
