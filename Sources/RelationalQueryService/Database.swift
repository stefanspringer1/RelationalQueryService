import Foundation
import Hummingbird
import PostgresNIO

protocol DatabaseMethods: Sendable {
    
    /// Query.
    func query(sql: String) async throws -> PostgresRowSequence
    
}

struct PostgresDatabaseMethods: DatabaseMethods, Sendable {
    
    let client: PostgresClient
    
    func query(sql: String) async throws -> PostgresNIO.PostgresRowSequence {
        try await client.query(PostgresQuery(stringLiteral: sql))
    }
    
}
