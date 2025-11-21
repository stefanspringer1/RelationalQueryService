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
    
    let postgresDatabaseMethods: PostgresDatabaseMethods
    let parameters: Parameters
    
    func query(_ input: RelationalQueryOpenAPI.Operations.query.Input) async throws -> RelationalQueryOpenAPI.Operations.query.Output {
        
        guard case .json(let queryInput) = input.body else {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "No valid JSON!")))
            ))
        }
        
        guard queryInput.parameters.apiKey == parameters.apiKey else {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Wrong API key!")))
            ))
        }
        
        if let allowedTables = parameters.allowedTables {
            guard allowedTables.contains(queryInput.query.table) else {
                return .ok(.init(body:
                    .json(._Error(Components.Schemas._Error(error: "Table \"\(queryInput.query.table)\" not allowed!")))
                ))
            }
        }
        
        let query: RelationalQuery
        do {
            query = try makeQuery(fromInputQuery: queryInput.query, maxConditions: parameters.maxConditions)
        } catch {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Error while constructing query object: \(String(describing: error))")))
            ))
        }
        
        let sql = query.sql
        
        var results = [String]()
        
        let rows: PostgresRowSequence
        do {
            rows = try await postgresDatabaseMethods.query(sql: sql)
        } catch {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Could not excute query on database: \(String(reflecting: error))")))
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
