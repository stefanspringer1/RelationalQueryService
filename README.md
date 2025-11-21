# RelationalQueryService

Connect the [RelationalQuery](https://github.com/stefanspringer1/RelationalQuery) format to an SQL database via an OpenAPI defintion.

The application needs to be started with an API key, optionally the allowed table names and a maximal number of conditions in a query can be specified.

Get the list of arguments using the `--help` argument.

The OpenAPI specification is `Sources/RelationalQueryOpenAPI/openapi.yaml`.

Example input (cf. `reverseInputTest` in the tests)):

```json
{
    "apiKey": "sieben",
    "table": "entries",
    "fields": [
        {
            "name": "column_1"
        },
        {
            "to": "value",
            "renaming": "column_2"
        }
    ],
    "order": [
        {
            "name": "column_1"
        },
        {
            "withDirection": "column_2",
            "direction": "descending"
        }
    ],
    "table": "my_table",
    "condition": {
        "or": [
            {
                "equalTextField": "column_1",
                "value": "some value"
            },
            {
                "and": [
                    {
                        "equalTextField": "column_1",
                        "value": "some other value"
                    },
                    {
                        "not": {
                            "similarTextField": "column_2",
                            "template": "blabla %",
                            "wildcard": "%"
                        }
                    }
                ]
            }
        ]
    }
}
```

This results in the following SQL code used to query the database:

```sql
SELECT column_1,column_2 AS value FROM my_table WHERE (column_1='some value' OR (column_1='some other value' AND NOT column_2 LIKE 'blabla %')) ORDER BY column_1,column_2 DESC
```
