import Foundation
import Testing
import RelationalQueryOpenAPI

@Suite struct RelationalQueryOpenAPITests {
    
    @Test func reverseInputTest() throws {
        
        let queryExample = Components.Schemas.RelationalQuery(
            table: "my_table",
            fields: [
                Components.Schemas.RelationalField.field(.init(name: "column_1")),
                Components.Schemas.RelationalField.renamingField(.init(renaming: "column_2", to: "value"))
            ],
            condition: Components.Schemas.RelationalQueryCondition.or(.init(or: [
                Components.Schemas.RelationalQueryCondition.equalText(.init(equalTextField: "column_1", value: "some value")),
                Components.Schemas.RelationalQueryCondition.and(.init(and: [
                    Components.Schemas.RelationalQueryCondition.equalText(.init(equalTextField: "column_1", value: "some other value")),
                    Components.Schemas.RelationalQueryCondition.not(.init(not:
                        Components.Schemas.RelationalQueryCondition.similarText(.init(similarTextField: "column_2", template: "blabla %", wildcard: "%"))
                    ))
                ]))
            ])),
            order: [
                Components.Schemas.RelationalQueryResultOrder.field(Components.Schemas.field(name: "column_1")),
                Components.Schemas.RelationalQueryResultOrder.fieldWithDirection(Components.Schemas.fieldWithDirection(withDirection: "column_2", direction: .descending))
            ]
        )
        
        let asJSON = try JSONEncoder().encode(queryExample)
        
        if let json = try? JSONSerialization.jsonObject(with: asJSON, options: .mutableContainers),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            #expect(String(data: jsonData, encoding: .utf8) == """
                {
                  "condition" : {
                    "or" : [
                      {
                        "equalTextField" : "column_1",
                        "value" : "some value"
                      },
                      {
                        "and" : [
                          {
                            "equalTextField" : "column_1",
                            "value" : "some other value"
                          },
                          {
                            "not" : {
                              "similarTextField" : "column_2",
                              "template" : "blabla %",
                              "wildcard" : "%"
                            }
                          }
                        ]
                      }
                    ]
                  },
                  "fields" : [
                    {
                      "name" : "column_1"
                    },
                    {
                      "renaming" : "column_2",
                      "to" : "value"
                    }
                  ],
                  "order" : [
                    {
                      "name" : "column_1"
                    },
                    {
                      "direction" : "descending",
                      "withDirection" : "column_2"
                    }
                  ],
                  "table" : "my_table"
                }
                """)
        } else {
            #expect("error" == "invalid JSON")
        }
        
    }
    
}
