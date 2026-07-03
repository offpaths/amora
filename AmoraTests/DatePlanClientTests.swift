import XCTest
@testable import Amora

final class DatePlanClientTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func testGeneratePlanEncodesRequestAndDecodesResponse() async throws {
        let responseJSON = """
        {
          "id": "plan_test_123",
          "preview": {
            "title": "A cozy 2-hour plan near Williamsburg",
            "summaryBadges": ["$$", "2 hours", "No bars"],
            "stops": [
              { "order": 1, "concept": "A cozy conversation starter" },
              { "order": 2, "concept": "A personal activity" },
              { "order": 3, "concept": "A relaxed dessert finish" }
            ]
          },
          "lockedPlan": {
            "totalEstimatedCost": "$60-$90",
            "stops": [
              { "order": 1, "venueName": "A", "address": "1 St", "appleMapsQuery": "A 1 St", "durationMinutes": 35, "reason": "A thoughtful first stop.", "estimatedCost": "$20-$30" },
              { "order": 2, "venueName": "B", "address": "2 St", "appleMapsQuery": "B 2 St", "durationMinutes": 50, "reason": "A thoughtful second stop.", "estimatedCost": "$10-$25" },
              { "order": 3, "venueName": "C", "address": "3 St", "appleMapsQuery": "C 3 St", "durationMinutes": 35, "reason": "A thoughtful final stop.", "estimatedCost": "$30-$35" }
            ]
          }
        }
        """.data(using: .utf8)!

        URLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/generate-plan")
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(request.httpBodyData)
            let encoded = try JSONDecoder().decode(GeneratePlanRequest.self, from: body)
            XCTAssertEqual(encoded.locationLabel, "Williamsburg, Brooklyn")
            XCTAssertEqual(encoded.countryCode, "US")
            XCTAssertEqual(encoded.budgetAmount, 100)
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseJSON)
        }

        let client = DatePlanClient(baseURL: URL(string: "https://example.com")!, session: .stubbed)
        let plan = try await client.generatePlan(
            GeneratePlanRequest(
                locationLabel: "Williamsburg, Brooklyn",
                countryCode: "US",
                budgetAmount: 100,
                vibe: .cozy,
                noDrinking: true,
                durationMinutes: 120,
                partnerLikes: "bookstores"
            )
        )

        XCTAssertEqual(plan.id, "plan_test_123")
        XCTAssertEqual(plan.lockedPlan.stops.count, 3)
    }

    func testGeneratePlanThrowsGenerationFailedForBackendError() async {
        URLProtocolStub.requestHandler = { request in
            let data = #"{"error":"generation_failed","retryable":true}"#.data(using: .utf8)!
            return (HTTPURLResponse(url: request.url!, statusCode: 502, httpVersion: nil, headerFields: nil)!, data)
        }

        let client = DatePlanClient(baseURL: URL(string: "https://example.com")!, session: .stubbed)

        do {
            _ = try await client.generatePlan(
                GeneratePlanRequest(
                    locationLabel: "Williamsburg, Brooklyn",
                    countryCode: "US",
                    budgetAmount: 100,
                    vibe: .cozy,
                    noDrinking: true,
                    durationMinutes: 120,
                    partnerLikes: ""
                )
            )
            XCTFail("Expected generationFailed")
        } catch let error as DatePlanClientError {
            XCTAssertEqual(error, .generationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

final class URLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static var stubbed: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

private extension URLRequest {
    var httpBodyData: Data? {
        if let httpBody {
            return httpBody
        }

        guard let httpBodyStream else {
            return nil
        }

        httpBodyStream.open()
        defer { httpBodyStream.close() }

        var data = Data()
        let bufferSize = 1024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while httpBodyStream.hasBytesAvailable {
            let readCount = httpBodyStream.read(buffer, maxLength: bufferSize)
            if readCount <= 0 {
                break
            }
            data.append(buffer, count: readCount)
        }

        return data
    }
}
