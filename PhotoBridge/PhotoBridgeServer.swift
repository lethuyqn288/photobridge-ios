import Foundation
import Photos

class PhotoBridgeServer: NSObject, StreamDelegate {

    private let port: UInt32 = 8765
    private var inputStream:  InputStream?
    private var outputStream: OutputStream?
    private var serverSocket: CFSocket?

    func start() {
        var context = CFSocketContext(version: 0, info: Unmanaged.passRetained(self).toOpaque(),
                                     retain: nil, release: nil, copyDescription: nil)
        serverSocket = CFSocketCreate(nil, AF_INET, SOCK_STREAM, IPPROTO_TCP,
                                      CFSocketCallBackType.acceptCallBack.rawValue,
                                      { socket, type, address, data, info in
            guard let info = info else { return }
            let server = Unmanaged<PhotoBridgeServer>.fromOpaque(info).takeUnretainedValue()
            server.handleAccept(data: data)
        }, &context)

        guard let socket = serverSocket else { return }

        var yes: Int32 = 1
        setsockopt(CFSocketGetNative(socket), SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port   = in_port_t(port).bigEndian
        addr.sin_addr   = in_addr(s_addr: INADDR_ANY)

        let data = withUnsafeBytes(of: &addr) { Data($0) } as CFData
        CFSocketSetAddress(socket, data)

        let source = CFSocketCreateRunLoopSource(nil, socket, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .defaultMode)
        print("[Bridge] Listening on port \(port)")
    }

    private func handleAccept(data: UnsafeRawPointer?) {
        guard let data = data else { return }
        let handle = data.load(as: CFSocketNativeHandle.self)
        var readStream:  Unmanaged<CFReadStream>?
        var writeStream: Unmanaged<CFWriteStream>?
        CFStreamCreatePairWithSocket(nil, handle, &readStream, &writeStream)

        let input  = readStream!.takeRetainedValue()
        let output = writeStream!.takeRetainedValue()

        CFReadStreamSetProperty(input,  CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket), kCFBooleanTrue)
        CFWriteStreamSetProperty(output, CFStreamPropertyKey(rawValue: kCFStreamPropertyShouldCloseNativeSocket), kCFBooleanTrue)

        DispatchQueue.global(qos: .userInitiated).async {
            self.processConnection(input: input, output: output)
        }
    }

    private func processConnection(input: CFReadStream, output: CFWriteStream) {
        CFReadStreamOpen(input)
        CFWriteStreamOpen(output)

        defer {
            CFReadStreamClose(input)
            CFWriteStreamClose(output)
        }

        // Đọc 4 bytes: độ dài filename
        guard let nameLenData = readExact(stream: input, count: 4) else { return }
        let nameLen = nameLenData.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

        // Đọc filename
        guard let nameData = readExact(stream: input, count: Int(nameLen)),
              let filename = String(data: nameData, encoding: .utf8) else { return }

        // Đọc 8 bytes: độ dài data
        guard let dataLenBytes = readExact(stream: input, count: 8) else { return }
        let dataLen = dataLenBytes.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian }

        // Đọc file data
        var fileData = Data()
        fileData.reserveCapacity(Int(dataLen))
        var remaining = Int(dataLen)
        while remaining > 0 {
            let chunk = min(remaining, 65536)
            guard let part = readExact(stream: input, count: chunk) else { break }
            fileData.append(part)
            remaining -= part.count
        }

        // Lưu vào Photos
        let success = saveToPhotos(data: fileData, filename: filename)
        let response: [UInt8] = [success ? 0x01 : 0x00]
        let responseData = Data(response)
        responseData.withUnsafeBytes { ptr in
            _ = CFWriteStreamWrite(output, ptr.bindMemory(to: UInt8.self).baseAddress!, 1)
        }
    }

    private func readExact(stream: CFReadStream, count: Int) -> Data? {
        var result = Data()
        var remaining = count
        while remaining > 0 {
            var buf = [UInt8](repeating: 0, count: remaining)
            let n = CFReadStreamRead(stream, &buf, remaining)
            if n <= 0 { return nil }
            result.append(contentsOf: buf.prefix(n))
            remaining -= n
        }
        return result
    }

    private func saveToPhotos(data: Data, filename: String) -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        let ext = (filename as NSString).pathExtension.lowercased()
        let isVideo = ["mov", "mp4", "m4v"].contains(ext)

        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do { try data.write(to: tmp) } catch { return false }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                semaphore.signal()
                return
            }
            PHPhotoLibrary.shared().performChanges({
                if isVideo {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmp)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tmp)
                }
            }) { ok, _ in
                success = ok
                try? FileManager.default.removeItem(at: tmp)
                semaphore.signal()
            }
        }

        semaphore.wait()
        return success
    }
}
