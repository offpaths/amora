import Foundation

enum DatePlanClientError: Error, Equatable {
    case invalidResponse
    case generationFailed(statusCode: Int, body: String)
    case decodingFailed(String)
    case unlockFailed
}

struct DatePlanClient {
    var baseURL: URL
    var session: URLSession = .shared

    func generatePlan(_ request: GeneratePlanRequest) async throws -> DatePlanResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("generate-plan"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatePlanClientError.invalidResponse
        }

        let responseBody = String(data: data, encoding: .utf8) ?? "<non-utf8 response>"
        guard httpResponse.statusCode == 200 else {
            throw DatePlanClientError.generationFailed(statusCode: httpResponse.statusCode, body: responseBody)
        }

        do {
            return try JSONDecoder().decode(DatePlanResponse.self, from: data)
        } catch {
            throw DatePlanClientError.decodingFailed("Decode error: \(error)\nBody: \(responseBody)")
        }
    }

    func unlockPlan(planToken: String, signedTransactionInfo: String) async throws -> UnlockedPlanResponse {
        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("unlock-plan"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(
            UnlockPlanRequest(planToken: planToken, signedTransactionInfo: signedTransactionInfo)
        )

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatePlanClientError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw DatePlanClientError.unlockFailed
        }

        return try JSONDecoder().decode(UnlockedPlanResponse.self, from: data)
    }
}
