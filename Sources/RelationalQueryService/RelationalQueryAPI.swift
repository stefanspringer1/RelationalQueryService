import Foundation
import RelationalQueryOpenAPI
import RelationalQuery
import PostgresNIO
import Hummingbird
import OpenAPIRuntime

struct ConnectionError: Error, CustomStringConvertible {
    
    let description: String
    
    var localizedDescription: String {
        return description
    }
    
    init(_ description: String) {
        self.description = description
    }
    
}

struct RelationalQueryAPI: APIProtocol {
    
    func query(_ input: RelationalQueryOpenAPI.Operations.query.Input) async throws -> RelationalQueryOpenAPI.Operations.query.Output {
        
        guard case .json(let queryInput) = input.body else {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "No valid JSON!")))
            ))
        }
        
        let environment = Environment()
        
        guard let apiKey = environment.get("API-KEY"), !apiKey.isEmpty else {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Missing API key!")))
            ))
        }
        
        guard apiKey == queryInput.parameters.apiKey else {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Wrong API key!")))
            ))
        }
        
        if let allowedTables = environment.get("DB-TABLES"), !allowedTables.isEmpty,
           case let allowedTables = allowedTables.split(separator: ",", omittingEmptySubsequences: true).map({ String($0) }) {
            guard allowedTables.contains(queryInput.query.table) else {
                return .ok(.init(body:
                    .json(._Error(Components.Schemas._Error(error: "Table \"\(queryInput.query.table)\" not allowed!")))
                ))
            }
        }
        
        let maxConditionCount = Int(environment.get("DB-CONDITIONS") ?? "")
        
        let query: RelationalQuery
        do {
            query = try makeQuery(fromInputQuery: queryInput.query, maxConditions: maxConditionCount)
        } catch {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Error while constructing query object: \(String(describing: error))")))
            ))
        }
        
        let sql = query.sql
        
        var results = [String]()
        
        func connect() async throws -> (PostgresClient,Task<(), Never>) {
            guard
                let dbHost = environment.get("DB-HOST"),
                let dbPort = Int(environment.get("DB-PORT") ?? ""),
                let dbUser = environment.get("DB-USER"),
                let dbPassword = environment.get("DB-PASSWORD"),
                let dbDatabase = environment.get("DB-DATABASE") else {
                    throw ConnectionError("Missing database configuration!")
                }
            
            let postgresClient = PostgresClient(
                configuration: .init(
                    host: dbHost,
                    port: dbPort,
                    username: dbUser,
                    password: dbPassword,
                    database: dbDatabase,
                    tls: .disable
                )
            )
            let task = Task {
                await postgresClient.run()
            }
            return (postgresClient,task)
        }
        
        let postgreSQLQuery = PostgresQuery(stringLiteral: sql)
        let rows: PostgresRowSequence
        do {
            let (postgresClient,task) = try await connect()
            rows = try await postgresClient.query(postgreSQLQuery)
            task.cancel()
        } catch {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: String(reflecting: error))))
            ))
        }
        
        var resultRows = [Components.Schemas.Row]()
        
        for row in try await rows.collect() {
            var cells = [String:Sendable]()
            for cell in row {
                results.append(cell.columnName)
                switch cell.dataType {
                case .varchar, .text:
                    cells[cell.columnName] = try cell.decode(String.self)
                case .bool:
                    cells[cell.columnName] = try cell.decode(Bool.self)
                case .int2, .int4, .int8:
                    cells[cell.columnName] = try cell.decode(Int.self)
                default:
                    return .ok(.init(body:
                        .json(._Error(Components.Schemas._Error(error: "Unhandled data type: \(cell.dataType)")))
                    ))
                }
            }
            let container: OpenAPIObjectContainer
            do {
                container = try OpenAPIObjectContainer(unvalidatedValue: cells)
            } catch {
                return .ok(.init(body:
                    .json(._Error(Components.Schemas._Error(error: String(reflecting: error))))
                ))
            }
            resultRows.append(Components.Schemas.Row(additionalProperties: container))
        }
        
        return .ok(.init(body:
            .json(.Rows(Components.Schemas.Rows(rows: resultRows)))
        ))
    }
    
}
