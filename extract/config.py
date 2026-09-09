DATASET_CONFIGS = {
    "w7w3-xahh": {
        "name": "issued-licenses",
        "strategy": "single",
        "max_retries": 5,
        "delay": 5
    },
    "erm2-nwe9": {
        "name": "311-service-request",
        "strategy": "batch-keyset",
        "order_column": ":updated_at",
        "created_column": "created_date",
        "page_size": 1000,
        "max_retries": 2,
        "delay": 5,
        "max_ingested": 500000,
        "has_limit": False,
        "has_year_limit": False,
        "checkpoint": "order_column"
    },
    "64uk-42ks": {
        "name": "pluto",
        "strategy": "single",
        "order_column": "appdate",
        "page_size": 1000,
        "max_retries": 2,
        "delay": 5,
        "max_ingested": 1000000,
        "has_limit": False,
        "checkpoint": "offset"
    }
}