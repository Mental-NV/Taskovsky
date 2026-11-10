import TaskovskyDomain
import Foundation
import Darwin

private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) { completionHandler(nil) }
}

extension TaskStore {
    public func resolveURLTitle(for id: UUID) {
        guard settings.urlParsing, let task = data.tasks.first(where: { $0.id == id }), let url = URL(string: task.title), ["http", "https"].contains(url.scheme?.lowercased() ?? ""), let host = url.host, !host.isEmpty, url.user == nil, url.password == nil else { return }
        let original = task.title
        Task {
            guard let title = await Self.fetchURLTitle(url, host: host), settings.urlParsing,
                  var current = data.tasks.first(where: { $0.id == id }), current.title == original else { return }
            current.title = title
            if current.body.isEmpty { current.body = original }
            updateTask(current)
        }
    }
    private nonisolated static func isPublicHost(_ host: String) -> Bool {
        let lower = host.lowercased()
        guard lower.contains("."), !lower.hasSuffix(".local"), !lower.hasSuffix(".localhost"), lower != "localhost" else { return false }
        var hints = addrinfo(); hints.ai_family = AF_UNSPEC; hints.ai_socktype = SOCK_STREAM; hints.ai_flags = AI_ADDRCONFIG
        var result: UnsafeMutablePointer<addrinfo>?
        guard getaddrinfo(host, nil, &hints, &result) == 0, let first = result else { return false }
        defer { freeaddrinfo(first) }
        var cursor: UnsafeMutablePointer<addrinfo>? = first
        var found = false
        while let entry = cursor {
            if entry.pointee.ai_family == AF_INET, let address = entry.pointee.ai_addr {
                let value = UInt32(bigEndian: address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr.s_addr })
                let a = value >> 24, b = (value >> 16) & 255
                if a == 0 || a == 10 || a == 127 || a >= 224 || (a == 169 && b == 254) || (a == 172 && (16...31).contains(b)) || (a == 192 && b == 168) || (a == 100 && (64...127).contains(b)) { return false }
                found = true
            } else { return false } // Fail closed on IPv6 until its address ranges are validated.
            cursor = entry.pointee.ai_next
        }
        return found
    }
    private nonisolated static func fetchURLTitle(_ url: URL, host: String) async -> String? {
        guard isPublicHost(host) else { return nil }
        let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 5; config.timeoutIntervalForResource = 8
        let session = URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        do {
            var request = URLRequest(url: url); request.setValue("text/html", forHTTPHeaderField: "Accept")
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode), response.mimeType?.lowercased() == "text/html" else { return nil }
            var data = Data()
            for try await byte in bytes { data.append(byte); if data.count >= 131_072 { break } }
            guard let html = String(data: data, encoding: .utf8), let regex = try? NSRegularExpression(pattern: "(?is)<title[^>]*>(.*?)</title>"), let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)), let range = Range(match.range(at: 1), in: html) else { return nil }
            let title = String(html[range]).replacingOccurrences(of: "&amp;", with: "&").replacingOccurrences(of: "&lt;", with: "<").replacingOccurrences(of: "&gt;", with: ">").trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : String(title.prefix(300))
        } catch { return nil }
    }
}
