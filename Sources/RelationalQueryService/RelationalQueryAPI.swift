import Foundation
import RelationalQueryOpenAPI
import RelationalQuery

struct Person {
    var name: String
}

struct RelationalQueryAPI: APIProtocol {
    
    func query(_ input: RelationalQueryOpenAPI.Operations.query.Input) async throws -> RelationalQueryOpenAPI.Operations.query.Output {
        
        guard case .json(let json) = input.body else {
            return .ok(.init(body:
                    .json(.init(
                        message: "No valid JSON!"
                    ))
            ))
        }
        
        var firstFieldInfo = "–"
        var debug = ""
        
        if let firstField = json.fields?.first {
            
            // >>>>>>>>>>>>>>>>>>>>>>>>
            // see how as it should look as JSON:
            let field1 = Components.Schemas.RelationalField.renamingField(Components.Schemas.renamingField(renamingField_name: "vorher", renamingField_to: "nachher"))
            let field2 = Components.Schemas.RelationalField.field(Components.Schemas.field(field_name: "spalte1"))
            
            let test = Components.Schemas.RelationalQuery(
                table: "myTable",
                fields: [
                    field1, field2,
                ]
            )
            
            debug = String(data: try JSONEncoder().encode(test), encoding: .utf8) ?? "ERROR WHEN ENCODING"
            // <<<<<<<<<<<<<<<<<<<<<<<<
            
            switch firstField {
            case .field(let field):
                firstFieldInfo = String(data: try JSONEncoder().encode(field), encoding: .utf8) ?? "?"
                if let name = field.field_name {
                    firstFieldInfo += ": " + name
                }
            case .renamingField(let renamingField):
                firstFieldInfo = String(data: try JSONEncoder().encode(renamingField), encoding: .utf8) ?? "?"
                if let name = renamingField.renamingField_name, let to = renamingField.renamingField_to {
                    firstFieldInfo += ": " + "\(name) -> \(to)"
                }
            }
        }
        
        return .ok(.init(body:
            .json(.init(
                message: "Hello query for table with first field \(firstFieldInfo) (\(debug))"
            ))
        ))
    }
    
}
