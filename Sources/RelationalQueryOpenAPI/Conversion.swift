import RelationalQuery

public struct ComplexQueryError: Error, CustomStringConvertible {
    
    public let description: String
    
    var localizedDescription: String {
        return description
    }
    
    init(_ description: String) {
        self.description = description
    }
    
}

public func makeQuery(fromInputQuery inputQuery: Components.Schemas.RelationalQuery, maxConditions: Int? = nil) throws -> RelationalQuery {
    
    var conditionCount = 0
    
    func augmentConditionCount() throws {
        conditionCount += 1
        if let maxConditions, maxConditions >= 0, conditionCount > maxConditions {
            throw ComplexQueryError("More than \(maxConditions) conditions!")
        }
    }
    
    func makeConditon(from inputCondition: Components.Schemas.RelationalQueryCondition) throws -> RelationalQueryCondition {
        switch inputCondition {
        case .EqualText(let content):
            try augmentConditionCount()
            return .equalText(
                field: content.equalText.field,
                value: content.equalText.value
            )
        case .EqualInteger(let content):
            try augmentConditionCount()
            return .equalInteger(
                field: content.equalInteger.field,
                value: content.equalInteger.value
            )
        case .SmallerInteger(let content):
            try augmentConditionCount()
            return .smallerInteger(
                field: content.smallerInteger.field,
                than: content.smallerInteger.than
            )
        case .SmallerOrEqualInteger(let content):
            try augmentConditionCount()
            return .smallerOrEqualInteger(
                field: content.smallerOrEqualInteger.field,
                than: content.smallerOrEqualInteger.than
            )
        case .GreaterInteger(let content):
            try augmentConditionCount()
            return .greaterInteger(
                field: content.greaterInteger.field,
                than: content.greaterInteger.than
            )
        case .GreaterOrEqualInteger(let content):
            try augmentConditionCount()
            return .greaterOrEqualInteger(
                field: content.greaterOrEqualInteger.field,
                than: content.greaterOrEqualInteger.than
            )
        case .EqualBoolean(let content):
            return .equalBoolean(
                field: content.equalBoolean.field,
                value: content.equalBoolean.value
            )
        case .SimilarText(let content):
            try augmentConditionCount()
            return .similarText(
                field: content.similarText.field,
                template: content.similarText.template,
                wildcard: content.similarText.wildcard
            )
        case .Not(let content):
            return .not(condition: try makeConditon(from: content.not.condition))
        case .and(let and):
            return .and(conditions: try and.and.conditions.map(makeConditon))
        case .or(let or):
            return .or(conditions: try or.or.conditions.map(makeConditon))
        }
    }
    
    func makeConditon(fromOptional inputCondition: Components.Schemas.RelationalQueryCondition?) throws -> RelationalQueryCondition? {
        guard let inputCondition else { return nil }
        return try makeConditon(from: inputCondition)
    }
    
    return RelationalQuery(
        table: inputQuery.table,
        fields: inputQuery.fields?.map { field in
            switch field {
            case .Field(let content):
                RelationalField.field(name: content.field.name)
            case .RenamingField(let content):
                RelationalField.renamingField(name: content.renamingField.name, to: content.renamingField.to)
            }
        },
        condition: try makeConditon(fromOptional: inputQuery.condition),
        orderBy: inputQuery.order?.map { order in
            switch order {
            case .Field(let content):
                    .field(
                        name: content.field.name
                    )
            case .FieldWithDirection(let content):
                    .fieldWithDirection(
                        name: content.fieldWithDirection.name,
                        direction: content.fieldWithDirection.direction == .descending ? .descending : .ascending
                    )
                
            }
        }
    )
}
