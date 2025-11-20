# RelationalQueryService

Connect the [RelationalQuery](https://github.com/stefanspringer1/RelationalQuery) format to an SQL database via an OpenAPI defintion.

---

**NOTE:**

This package is in development.

---

Die OpanAPI specification is `Sources/RelationalQueryOpenAPI/openapi.yaml`.

Example input (cf. `reverseInputTest` in the tests)):

```json
{
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
