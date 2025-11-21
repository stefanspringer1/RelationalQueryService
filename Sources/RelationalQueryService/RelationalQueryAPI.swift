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

struct ComplexQueryError: Error, CustomStringConvertible {
    
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
        
        guard apiKey == queryInput.apiKey else {
            return .ok(.init(body:
                .json(._Error(Components.Schemas._Error(error: "Wrong API key!")))
            ))
        }
        
        if let allowedTables = environment.get("DB-TABLES"), !allowedTables.isEmpty,
           case let allowedTables = allowedTables.split(separator: ",", omittingEmptySubsequences: true).map({ String($0) }) {
            guard allowedTables.contains(queryInput.table) else {
                return .ok(.init(body:
                    .json(._Error(Components.Schemas._Error(error: "Table \"\(queryInput.table)\" not allowed!")))
                ))
            }
        }
        
        let maxConditionCount = Int(environment.get("DB-CONDITIONS") ?? "") ?? -1
        var conditionCount = 0
        
        func augmentConditionCount() throws {
            conditionCount += 1
            if maxConditionCount > 0 && conditionCount > maxConditionCount {
                throw ComplexQueryError("More than \(maxConditionCount) conditions!")
            }
        }
        
        func makeConditon(from inputCondition: Components.Schemas.RelationalQueryCondition) throws -> RelationalQueryCondition {
            switch inputCondition {
            case .equalText(let equalText):
                try augmentConditionCount()
                return .equalText(field: equalText.equalTextField, value: equalText.value)
            case .equalInteger(let equalInteger):
                try augmentConditionCount()
                return .equalInteger(field: equalInteger.equalIntegerField, value: equalInteger.value)
            case .smallerInteger(let smallerInteger):
                try augmentConditionCount()
                return .smallerInteger(field: smallerInteger.smallerIntegerField, than: smallerInteger.than)
            case .smallerOrEqualInteger(let smallerOrEqualInteger):
                try augmentConditionCount()
                return .smallerOrEqualInteger(field: smallerOrEqualInteger.smallerOrEqualField, than: smallerOrEqualInteger.than)
            case .greaterInteger(let greaterInteger):
                try augmentConditionCount()
                return .greaterInteger(field: greaterInteger.greaterIntegerField, than: greaterInteger.than)
            case .greaterOrEqualInteger(let greaterOrEqualInteger):
                try augmentConditionCount()
                return .greaterOrEqualInteger(field: greaterOrEqualInteger.greaterOrEqualIntegerField, than: greaterOrEqualInteger.than)
            case .equalBoolean(let equalBoolean):
                return .equalBoolean(field: equalBoolean.equalBooleanField, value: equalBoolean.value)
            case .similarText(let similarText):
                try augmentConditionCount()
                return .similarText(field: similarText.similarTextField, template: similarText.template, wildcard: similarText.wildcard)
            case .not(let not):
                return .not(condition: try makeConditon(from: not.not))
            case .and(let and):
                return .and(conditions: try and.and.map(makeConditon))
            case .or(let or):
                return .or(conditions: try or.or.map(makeConditon))
            }
        }
        
        func makeConditon(fromOptional inputCondition: Components.Schemas.RelationalQueryCondition?) throws -> RelationalQueryCondition? {
            guard let inputCondition else { return nil }
            return try makeConditon(from: inputCondition)
        }
        
        let query: RelationalQuery
        do {
            query = RelationalQuery(
                table: queryInput.table,
                fields: queryInput.fields?.map { field in
                    switch field {
                    case .field(let field):
                        RelationalField.field(name: field.name)
                    case .renamingField(let renamingField):
                        RelationalField.renamingField(name: renamingField.renaming, to: renamingField.to)
                    }
                },
                condition: try makeConditon(fromOptional: queryInput.condition),
                orderBy: queryInput.order?.map { order in
                    switch order {
                    case .field(let field):
                            .field(name: field.name)
                    case .fieldWithDirection(let fieldWithDirection):
                            .fieldWithDirection(name: fieldWithDirection.withDirection, direction: fieldWithDirection.direction == .descending ? .descending : .ascending)
                        
                    }
                }
            )
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
