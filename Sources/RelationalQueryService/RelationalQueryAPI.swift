import Foundation
import RelationalQueryOpenAPI
import RelationalQuery

struct Person {
    var name: String
}

struct RelationalQueryAPI: APIProtocol {
    
    func query(_ input: RelationalQueryOpenAPI.Operations.query.Input) async throws -> RelationalQueryOpenAPI.Operations.query.Output {
        
        guard case .json(let query) = input.body else {
            return .ok(.init(body:
                    .json(.init(
                        message: "No valid JSON!"
                    ))
            ))
        }
        
        var firstFieldInfo = "–"
        var firstOrderInfo = "–"
        var debug = ""
        
        if let firstField = query.fields?.first {
            
            // >>>>>>>>>>>>>>>>>>>>>>>>
            // see how as it should look as JSON:
            let field1 = Components.Schemas.RelationalField.renamingField(Components.Schemas.renamingField(renaming: "vorher", to: "nachher"))
            let field2 = Components.Schemas.RelationalField.field(Components.Schemas.field(name: "spalte1"))
            
            let test = Components.Schemas.RelationalQuery(
                table: "myTable",
                fields: [
                    field1, field2,
                ]
            )
            
            debug = String(data: try JSONEncoder().encode(test), encoding: .utf8) ?? "ERROR WHEN ENCODING"
            // <<<<<<<<<<<<<<<<<<<<<<<<
            
            switch firstField {
            case .renamingField(let renamingField):
                firstFieldInfo = String(data: try JSONEncoder().encode(renamingField), encoding: .utf8) ?? "?"
                firstFieldInfo += ": " + "\(renamingField.renaming) -> \(renamingField.to)"
            case .field(let field):
                firstFieldInfo = String(data: try JSONEncoder().encode(field), encoding: .utf8) ?? "?"
                firstFieldInfo += ": " + field.name
            }
        }
        
        if let firstDirection = query.order?.first {
            switch firstDirection {
            case .field(let field):
                firstOrderInfo = "ORDER BY \(field.name)"
            case .fieldWithDirection(let fieldWithDirection):
                firstOrderInfo = "ORDER BY \(fieldWithDirection.withDirection) \(fieldWithDirection.direction)"
            }
        }
        
        return .ok(.init(body:
            .json(.init(
                message: "Hello query for table with first field \(firstFieldInfo), first order \(firstOrderInfo) (\(debug))"
            ))
        ))
    }
    
}
