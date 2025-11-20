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
        
        func makeConditon(from inputCondition: Components.Schemas.RelationalQueryCondition) -> RelationalQueryCondition {
            switch inputCondition {
            case .equalText(let equalText):
                .equalText(field: equalText.equalTextField, value: equalText.value)
            case .equalInteger(let equalInteger):
                .equalInteger(field: equalInteger.equalIntegerField, value: equalInteger.value)
            case .smallerInteger(let smallerInteger):
                .smallerInteger(field: smallerInteger.smallerIntegerField, than: smallerInteger.than)
            case .smallerOrEqualInteger(let smallerOrEqualInteger):
                .smallerOrEqualInteger(field: smallerOrEqualInteger.smallerOrEqualField, than: smallerOrEqualInteger.than)
            case .greaterInteger(let greaterInteger):
                .greaterInteger(field: greaterInteger.greaterIntegerField, than: greaterInteger.than)
            case .greaterOrEqualInteger(let greaterOrEqualInteger):
                .greaterOrEqualInteger(field: greaterOrEqualInteger.greaterOrEqualIntegerField, than: greaterOrEqualInteger.than)
            case .equalBoolean(let equalBoolean):
                .equalBoolean(field: equalBoolean.equalBooleanField, value: equalBoolean.value)
            case .similarText(let similarText):
                .similarText(field: similarText.similarTextField, template: similarText.template, wildcard: similarText.wildcard)
            case .not(let not):
                    .not(condition: makeConditon(from: not.not))
            case .and(let and):
                .and(conditions: and.and.map(makeConditon))
            case .or(let or):
                .or(conditions: or.or.map(makeConditon))
            }
        }
        
        func makeConditon(fromOptional inputCondition: Components.Schemas.RelationalQueryCondition?) -> RelationalQueryCondition? {
            guard let inputCondition else { return nil }
            return makeConditon(from: inputCondition)
        }
        
        let query = RelationalQuery(
            table: queryInput.table,
            fields: queryInput.fields?.map { field in
                switch field {
                case .field(let field):
                    RelationalField.field(name: field.name)
                case .renamingField(let renamingField):
                    RelationalField.renamingField(name: renamingField.renaming, to: renamingField.to)
                }
            },
            condition: makeConditon(fromOptional: queryInput.condition),
            orderBy: queryInput.order?.map { order in
                switch order {
                case .field(let field):
                    .field(name: field.name)
                case .fieldWithDirection(let fieldWithDirection):
                        .fieldWithDirection(name: fieldWithDirection.withDirection, direction: fieldWithDirection.direction == .descending ? .descending : .ascending)

                }
            }
        )
        
        let sql = query.sql
        //let sql = "SELECT number, date FROM entries WHERE number = 'DIN 20000-1'"
        
        var results = [String]()
        
        func connect() async throws -> (PostgresClient,Task<(), Never>) {
            let environment = Environment()
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
