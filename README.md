# RelationalQueryService

---

⚠️ **NOTE:**

This repository is deprecated; use the following, currently maintained repository instead:

https://github.com/struktaris/RelationalQueryService

Note the new version number: The last version of this repository corresponds to version 1.0.0 of the new repository.

---

Connect the [RelationalQuery](https://github.com/stefanspringer1/RelationalQuery) format to a PostgreSQL database using an OpenAPI definition.

The application needs to be started with an API key, optionally the allowed table names, the allowed field names, or the maximal number of conditions in a query can be specified.

Get the list of arguments using the `--help` argument.

The OpenAPI specification is `Sources/RelationalQueryOpenAPI/openapi.yaml`.

Example input (cf. `reverseInputTest` in the tests)):

```json
{
  "parameters" : {
    "apiKey" : "myKey"
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
```

This results in the following SQL code used to query the database (linebreaks and indentation added):

```sql
SELECT column_1,column_2 AS value
FROM my_table
WHERE (
  column_1='some value' OR (
    column_1='some other value' AND
    NOT column_2 LIKE 'blabla %'
  )
)
ORDER BY column_1,column_2 DESC
```
