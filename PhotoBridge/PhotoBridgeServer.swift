import Foundation
import Photos
import Network

/// TCP server lắng nghe trên port 8765
/// Protocol đơn giản:
///   PC gửi:  [4 bytes: filename length][filename][8 bytes: data length][data]
///   App trả: [1 byte: 0x01=OK, 0x00=FAIL]
class PhotoBridgeServer {

    private let port: NWEndpoint.Port = 8765
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "PhotoBridgeServer")

    func start() {
        do {
            listener = try NWListener(using: .tcp, on: port)
        } catch {
            print("[Bridge] Cannot create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[Bridge] Server ready on port 8765")
            case .failed(let error):
                print("[Bridge] Server failed: \(error)")
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
    }

    // MARK: - Connection handling

    private func handleConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveFilename(from: connection)
    }

    /// Bước 1: đọc 4 bytes = độ dài filename
    private func receiveFilename(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] data, _, _, error in
            guard let self = self, let data = data, data.count == 4, error == nil else {
                connection.cancel()
                return
            }
            let nameLen = Int(data.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            self.receiveFilenameString(from: connection, length: nameLen)
        }
    }

    /// Bước 2: đọc filename string
    private func receiveFilenameString(from connection: NWConnection, length: Int) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, _, error in
            guard let self = self, let data = data, data.count == length, error == nil else {
                connection.cancel()
                return
            }
            let filename = String(data: data, encoding: .utf8) ?? "import.jpg"
            self.receiveDataLength(from: connection, filename: filename)
        }
    }

    /// Bước 3: đọc 8 bytes = độ dài data
    private func receiveDataLength(from connection: NWConnection, filename: String) {
        connection.receive(minimumIncompleteLength: 8, maximumLength: 8) { [weak self] data, _, _, error in
            guard let self = self, let data = data, data.count == 8, error == nil else {
                connection.cancel()
                return
            }
            let dataLen = Int(data.withUnsafeBytes { $0.load(as: UInt64.self).bigEndian })
            self.receiveFileData(from: connection, filename: filename, totalLength: dataLen)
        }
    }

    /// Bước 4: đọc toàn bộ file data
    private func receiveFileData(from connection: NWConnection, filename: String, totalLength: Int) {
        var received = Data()
        received.reserveCapacity(totalLength)
        receiveChunk(from: connection, filename: filename, received: &received, totalLength: totalLength)
    }

    private func receiveChunk(from connection: NWConnection, filename: String,
                               received: inout Data, totalLength: Int) {
        let remaining = totalLength - received.count
        guard remaining > 0 else {
            // Đã nhận đủ — lưu vào Photos
            let snapshot = received
            saveToPhotos(data: snapshot, filename: filename) { success in
                let response = Data([success ? 0x01 : 0x00])
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
            return
        }

        let chunkSize = min(remaining, 256 * 1024)
        connection.receive(minimumIncompleteLength: 1, maximumLength: chunkSize) { [weak self] data, _, _, error in
            guard let self = self, let data = data, !data.isEmpty, error == nil else {
                connection.cancel()
                return
            }
            received.append(data)
            self.receiveChunk(from: connection, filename: filename, received: &received, totalLength: totalLength)
        }
    }

    // MARK: - PhotoKit save

    private func saveToPhotos(data: Data, filename: String, completion: @escaping (Bool) -> Void) {
        // Kiểm tra / xin quyền
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

        switch status {
        case .authorized, .limited:
            performSave(data: data, filename: filename, completion: completion)

        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { [weak self] granted in
                if granted == .authorized || granted == .limited {
                    self?.performSave(data: data, filename: filename, completion: completion)
                } else {
                    completion(false)
                }
            }

        default:
            print("[Bridge] Photos permission denied")
            completion(false)
        }
    }

    private func performSave(data: Data, filename: String, completion: @escaping (Bool) -> Void) {
        // Ghi ra file tạm
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename)
        do {
            try data.write(to: tmp)
        } catch {
            print("[Bridge] Write tmp failed: \(error)")
            completion(false)
            return
        }

        let ext = (filename as NSString).pathExtension.lowercased()
        let isVideo = ["mov", "mp4", "m4v", "3gp"].contains(ext)

        PHPhotoLibrary.shared().performChanges({
            if isVideo {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tmp)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: tmp)
            }
        }) { success, error in
            // Xóa file tạm
            try? FileManager.default.removeItem(at: tmp)
            if let error = error {
                print("[Bridge] PhotoKit error: \(error)")
            }
            completion(success)
        }
    }
}
