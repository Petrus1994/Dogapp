import Foundation

// MARK: - Outbound request shapes for the OpenAI Responses API

/// A single message sent to the model.
struct AIMessage: Encodable {
    let role: String   // "system" | "developer" | "user" | "assistant"
    let content: String
}

/// JSON Schema descriptor used for structured output requests.
struct AIJSONSchema: Encodable {
    let name: String
    let schema: JSONSchemaObject
    let strict: Bool

    struct JSONSchemaObject: Encodable {
        let type: String
        let properties: [String: JSONProperty]
        let required: [String]
        let additionalProperties: Bool

        struct JSONProperty: Encodable {
            let type: String?
            let description: String?
            let items: JSONArrayItems?
            // Nested objects handled through separate schema definitions

            struct JSONArrayItems: Encodable {
                let type: String
            }
        }
    }
}

/// Full Responses API request body.
struct OpenAIResponsesRequest: Encodable {
    let model: String
    let input: [AIMessage]
    let temperature: Double
    let maxOutputTokens: Int
    let text: TextFormat?

    enum CodingKeys: String, CodingKey {
        case model, input, temperature
        case maxOutputTokens = "max_output_tokens"
        case text
    }

    struct TextFormat: Encodable {
        let format: FormatDescriptor

        struct FormatDescriptor: Encodable {
            let type: String              // "json_schema" | "text"
            let name: String?
            let schema: JSONValue?        // free-form JSON schema
            let strict: Bool?
        }
    }
}

// MARK: - JSONValue helper (encode arbitrary JSON schemas)

/// Wraps arbitrary Encodable values so we can embed raw JSON schemas.
indirect enum JSONValue: Encodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let v):  try c.encode(v)
        case .int(let v):     try c.encode(v)
        case .double(let v):  try c.encode(v)
        case .bool(let v):    try c.encode(v)
        case .array(let v):   try c.encode(v)
        case .object(let v):  try c.encode(v)
        case .null:           try c.encodeNil()
        }
    }
}
