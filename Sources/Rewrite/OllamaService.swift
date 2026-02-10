import Foundation

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case requestFailed(Int)
    case noData
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Ollama URL. Check your settings."
        case .connectionFailed(let detail):
            return "Cannot connect to Ollama: \(detail)"
        case .requestFailed(let code):
            return "Ollama returned HTTP \(code)."
        case .noData:
            return "No response from Ollama."
        case .decodingFailed(let detail):
            return "Failed to parse Ollama response: \(detail)"
        }
    }
}

final class OllamaService {
    static let shared = OllamaService()
    private init() {}

    func generate(prompt: String, completion: @escaping (Result<String, OllamaError>) -> Void) {
        let settings = Settings.shared
        guard let url = URL(string: "\(settings.ollamaURL)/api/generate") else {
            completion(.failure(.invalidURL))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": settings.modelName,
            "prompt": prompt,
            "stream": true,
            "options": ["temperature": 0.3]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(.decodingFailed(error.localizedDescription)))
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(.connectionFailed(error.localizedDescription)))
                return
            }

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                completion(.failure(.requestFailed(httpResponse.statusCode)))
                return
            }

            guard let data = data else {
                completion(.failure(.noData))
                return
            }

            // Parse NDJSON: each line is a JSON object with a "response" field
            let text = String(data: data, encoding: .utf8) ?? ""
            var result = ""

            for line in text.components(separatedBy: "\n") where !line.isEmpty {
                guard let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let fragment = json["response"] as? String else {
                    continue
                }
                result += fragment
            }

            if result.isEmpty {
                completion(.failure(.noData))
            } else {
                completion(.success(result.trimmingCharacters(in: .whitespacesAndNewlines)))
            }
        }

        task.resume()
    }

    func fetchModels(completion: @escaping ([String]) -> Void) {
        let settings = Settings.shared
        guard let url = URL(string: "\(settings.ollamaURL)/api/tags") else {
            completion([])
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else {
                completion([])
                return
            }
            let names = models.compactMap { $0["name"] as? String }.sorted()
            completion(names)
        }.resume()
    }
}
