import Foundation
import Testing
import RelationalQueryOpenAPI

@Suite struct RelationalQueryOpenAPITests {
    
    @Test func reverseInputTest() throws {
        
        let queryExample = Components.Schemas.Input(
            parameters: Components.Schemas.Parameters(apiKey: "sieben"),
            query: Components.Schemas.RelationalQuery(
                table: "my_table",
                fields: [
                    Components.Schemas.RelationalField.Field(.init(
                        field: Components.Schemas.field(name: "column_1")
                    )),
                    Components.Schemas.RelationalField.RenamingField(.init(
                        renamingField: Components.Schemas.renamingField(name: "column_2", to: "value")
                    ))
                ],
                condition: Components.Schemas.RelationalQueryCondition.or(.init(
                    or: Components.Schemas.Conditions(conditions: [
                        Components.Schemas.RelationalQueryCondition.EqualText(.init(equalText:
                            Components.Schemas.equalText(
                                field: "column_1",
                                value: "some value"
                            )
                        )),
                        Components.Schemas.RelationalQueryCondition.and(.init(
                                and: Components.Schemas.Conditions(conditions: [
                                    Components.Schemas.RelationalQueryCondition.EqualText(.init(equalText:
                                        Components.Schemas.equalText(
                                            field: "column_1",
                                            value: "some other value"
                                        )
                                    )),
                                    Components.Schemas.RelationalQueryCondition.Not(.init(not:
                                        Components.Schemas.not(condition:
                                            Components.Schemas.RelationalQueryCondition.SimilarText(.init(similarText:
                                                Components.Schemas.similarText(
                                                    field: "column_2",
                                                    template: "blabla %",
                                                    wildcard: "%"
                                                )
                                            ))
                                        )
                                    ))
                                ])
                        ))
                    ])
                )),
                order: [
                    Components.Schemas.RelationalQueryResultOrder.Field(.init(
                        field: Components.Schemas.field(name: "column_1")
                    )),
                    Components.Schemas.RelationalQueryResultOrder.FieldWithDirection(.init(
                        fieldWithDirection: Components.Schemas.fieldWithDirection(name: "column_2", direction: .descending)
                    ))
                ]
            )
        )
        
        let asJSON = try JSONEncoder().encode(queryExample)
        
        if let json = try? JSONSerialization.jsonObject(with: asJSON, options: .mutableContainers),
           let jsonData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            #expect(String(data: jsonData, encoding: .utf8) == """
                {
                  "parameters" : {
                    "apiKey" : "sieben"
                  },
                  "query" : {
                    "condition" : {
                      "or" : {
                        "conditions" : [
                          {
                            "equalText" : {
                              "field" : "column_1",
                              "value" : "some value"
                            }
                          },
                          {
                            "and" : {
                              "conditions" : [
                                {
                                  "equalText" : {
                                    "field" : "column_1",
                                    "value" : "some other value"
                                  }
                                },
                                {
                                  "not" : {
                                    "condition" : {
                                      "similarText" : {
                                        "field" : "column_2",
                                        "template" : "blabla %",
                                        "wildcard" : "%"
                                      }
                                    }
                                  }
                                }
                              ]
                            }
                          }
                        ]
                      }
                    },
                    "fields" : [
                      {
                        "field" : {
                          "name" : "column_1"
                        }
                      },
                      {
                        "renamingField" : {
                          "name" : "column_2",
                          "to" : "value"
                        }
                      }
                    ],
                    "order" : [
                      {
                        "field" : {
                          "name" : "column_1"
                        }
                      },
                      {
                        "fieldWithDirection" : {
                          "direction" : "descending",
                          "name" : "column_2"
                        }
                      }
                    ],
                    "table" : "my_table"
                  }
                }
                """)
        } else {
            #expect("error" == "invalid JSON")
        }
        
        let query = try makeQuery(fromInputQuery: queryExample.query)
        
        #expect(query.sql == """
            SELECT column_1,column_2 AS value FROM my_table WHERE (column_1='some value' OR (column_1='some other value' AND NOT column_2 LIKE 'blabla %')) ORDER BY column_1,column_2 DESC
            """)
    }
    
}
