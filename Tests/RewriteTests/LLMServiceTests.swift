import XCTest
@testable import Rewrite

private extension Data {
    init(reading stream: InputStream) {
        self.init()
        stream.open()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read > 0 {
                self.append(buffer, count: read)
            } else {
                break
            }
        }
        stream.close()
    }
}

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data?))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: 0, userInfo: [NSLocalizedDescriptionKey: "No handler set"]))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            if let data = data {
                client?.urlProtocol(self, didLoad: data)
            }
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

final class LLMServiceTests: XCTestCase {
    var session: URLSession!
    var service: LLMService!

    override func setUp() {
        super.setUp()
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: config)
        service = LLMService(session: session, settingsProvider: {
            (serverURL: "http://localhost:8080", modelName: "test-model")
        })
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        session = nil
        service = nil
        super.tearDown()
    }

    // MARK: - generate()

    func testGenerateSuccess() {
        let responseJSON: [String: Any] = [
            "choices": [
                ["message": ["content": "  Fixed text  "]]
            ]
        ]
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("/v1/chat/completions"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            return (response, data)
        }

        let exp = expectation(description: "generate")
        service.generate(prompt: "Fix this") { result in
            switch result {
            case .success(let text):
                XCTAssertEqual(text, "Fixed text")
            case .failure(let error):
                XCTFail("Expected success, got \(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testGenerateRequestContainsPromptAndModel() {
        MockURLProtocol.requestHandler = { request in
            let bodyData: Data
            if let httpBody = request.httpBody {
                bodyData = httpBody
            } else if let stream = request.httpBodyStream {
                bodyData = Data(reading: stream)
            } else {
                XCTFail("No request body")
                throw NSError(domain: "test", code: 0)
            }
            let body = try JSONSerialization.jsonObject(with: bodyData) as! [String: Any]
            let messages = body["messages"] as! [[String: Any]]
            XCTAssertEqual(messages.first?["content"] as? String, "Test prompt")
            XCTAssertEqual(body["model"] as? String, "test-model")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: ["choices": [["message": ["content": "ok"]]]])
            return (response, data)
        }

        let exp = expectation(description: "generate")
        service.generate(prompt: "Test prompt") { _ in exp.fulfill() }
        wait(for: [exp], timeout: 5)
    }

    func testGenerateConnectionFailed() {
        MockURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }

        let exp = expectation(description: "generate")
        service.generate(prompt: "test") { result in
            if case .failure(.connectionFailed) = result {
                // pass
            } else {
                XCTFail("Expected connectionFailed error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testGenerateRequestFailed500() {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, nil)
        }

        let exp = expectation(description: "generate")
        service.generate(prompt: "test") { result in
            if case .failure(.requestFailed(500)) = result {
                // pass
            } else {
                XCTFail("Expected requestFailed(500), got \(result)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testGenerateNoData() {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        let exp = expectation(description: "generate")
        service.generate(prompt: "test") { result in
            if case .failure(.noData) = result {
                // pass
            } else {
                XCTFail("Expected noData error")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testGenerateMalformedJSON() {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = "not json".data(using: .utf8)
            return (response, data)
        }

        let exp = expectation(description: "generate")
        service.generate(prompt: "test") { result in
            if case .failure(.noData) = result {
                // malformed JSON falls through to noData
            } else {
                XCTFail("Expected noData error for malformed JSON")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    // MARK: - fetchModels()

    func testFetchModelsSuccess() {
        let responseJSON: [String: Any] = [
            "data": [
                ["id": "model-b"],
                ["id": "model-a"],
                ["id": "model-c"]
            ]
        ]
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url!.absoluteString.contains("/v1/models"))
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let data = try JSONSerialization.data(withJSONObject: responseJSON)
            return (response, data)
        }

        let exp = expectation(description: "fetchModels")
        service.fetchModels { models in
            XCTAssertEqual(models, ["model-a", "model-b", "model-c"])
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }

    func testFetchModelsErrorReturnsEmpty() {
        MockURLProtocol.requestHandler = { _ in
            throw NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        }

        let exp = expectation(description: "fetchModels")
        service.fetchModels { models in
            XCTAssertTrue(models.isEmpty)
            exp.fulfill()
        }
        wait(for: [exp], timeout: 5)
    }
}
