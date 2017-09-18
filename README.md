# JDB API

## Directory Layout

```bash
.
├── db                        # Database schema source files and tests
│   ├── src                   # Schema definition
│   │   ├── api               # Api entities avaiable as REST endpoints
│   │   ├── data              # Definition of source tables that hold the data
│   │   ├── libs              # A collection modules of used throughout the code
│   │   ├── authorization     # Application level roles and their privileges
│   │   ├── sample_data       # A few sample rows
│   │   └── init.sql          # Schema definition entry point
│   └── tests                 # pgTap tests
├── openresty                 # Reverse proxy configurations and Lua code
│   ├── lualib
│   │   └── user_code         # Application Lua code
│   ├── nginx                 # Nginx files
│   │   ├── conf              # Configuration files
│   │   └── html              # Static frontend files
│   ├── tests                 # Mocha based integration tests
│   │   ├── rest              # REST interface tests
│   │   └── common.js         # Helper functions
│   ├── Dockerfile            # Dockerfile definition for production
│   └── entrypoint.sh         # Custom entrypoint
├── postgrest                 # PostgREST 
│   └── tests                 # Simple bash based integration tests
├── docker-compose.yml        # Defines Docker services, networks and volumes
└── .env                      # Project configurations

```


## Installation

Make sure that you have [Docker](https://www.docker.com/community-edition) v17 or newer installed.

Setup your git repo with a reference to the upstream
```base
mkdir example-api
cd example-api
git init
git remote add upstream https://github.com/subzerocloud/postgrest-starter-kit.git
git fetch upstream
git merge upstream/master
```

Launch the app with [Docker Compose](https://docs.docker.com/compose/):

```bash
docker-compose up -d
```

The API server must become available at [http://localhost:8080/rest](http://localhost:8080/rest).
Try a simple request

```bash
curl http://localhost:8080/rest/todos?select=id,todo
```

## Development workflow and debugging

Install [subzero-cli](https://github.com/subzerocloud/subzero-cli) using `npm install -g subzero-cli`.

Execute `subzero dashboard` in the root of your project.<br />
After this step you can view the logs of all the stack components (SQL queries will also be logged) and
if you edit a sql/conf/lua file in your project, the changes will immediately be applied.


## Testing

The starter kit comes with a testing infrastructure setup. 
You can write pgTAP tests that run directly in your database, useful for testing the logic that resides in your database (user privileges, Row Level Security, stored procedures).
Integration tests are written in JavaScript.

Here is how you run them

```bash
npm install                     # Install test dependencies
npm run test_db                 # Run pgTAP tests
npm run test_rest               # Run integration tests
npm test                        # Run all tests (db, rest)
```

## Keeping Up-to-Date

You can always fetch and merge the recent updates back into your project by running:

```bash
git fetch upstream
git merge upstream/master
```

## Deployment

More information in [Production Infrastructure (AWS ECS+RDS)](https://github.com/subzerocloud/postgrest-starter-kit/wiki/Production-Infrastructure)

## Contributing

Anyone and everyone is welcome to contribute.

## License

Copyright © 2017-present Biswajit Baruah.<br />
This source code is licensed under [MIT](https://github.com/subzerocloud/postgrest-starter-kit/blob/master/LICENSE.txt) license<br />
The documentation to the project is licensed under the [CC BY-SA 4.0](http://creativecommons.org/licenses/by-sa/4.0/) license.

