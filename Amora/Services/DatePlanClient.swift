import Foundation

enum DatePlanClientError: Error, Equatable {
    case invalidResponse
    case generationFailed
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

        guard httpResponse.statusCode == 200 else {
            throw DatePlanClientError.generationFailed
        }

        return try JSONDecoder().decode(DatePlanResponse.self, from: data)
    }
}
