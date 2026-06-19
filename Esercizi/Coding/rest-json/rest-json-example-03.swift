// URLProtocol custom per logging e mock

import Foundation

// MARK: - Logging URLProtocol

final class LoggingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        print("[HTTP] → \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "")")

        let config = URLSessionConfiguration.default
        config.protocolClasses = []  // evita ricorsione
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            if let error {
                self.client?.urlProtocol(self, didFailWithError: error)
                return
            }
            if let response {
                self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }
            if let data {
                self.client?.urlProtocol(self, didLoad: data)
                print("[HTTP] ← \(data.count) bytes")
            }
            self.client?.urlProtocolDidFinishLoading(self)
        }
        task.resume()
    }

    override func stopLoading() {}
}

// MARK: - Mock URLProtocol per test

final class MockURLProtocol: URLProtocol {
    static var mockResponses: [URL: (Data, HTTPURLResponse)] = [:]

    override class func canInit(with request: URLRequest) -> Bool {
        guard let url = request.url else { return false }
        return mockResponses[url] != nil
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let (data, response) = MockURLProtocol.mockResponses[url] else {
            client?.urlProtocol(self, didFailWithError: URLError(.fileDoesNotExist))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Configurazione per test

func makeTestSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}