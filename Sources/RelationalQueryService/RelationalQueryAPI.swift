import Foundation
import RelationalQueryOpenAPI
import RelationalQuery

struct Person {
    var name: String
}

struct RelationalQueryAPI: APIProtocol {
    
    func query(_ input: RelationalQueryOpenAPI.Operations.query.Input) async throws -> RelationalQueryOpenAPI.Operations.query.Output {
        
        guard case .json(let queryInput) = input.body else {
            return .ok(.init(body:
                    .json(.init(
                        message: "No valid JSON!"
                    ))
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
        
        return .ok(.init(body:
            .json(.init(
                message: "Hello query: \(sql)"
            ))
        ))
    }
    
}
