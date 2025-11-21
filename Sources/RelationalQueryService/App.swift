import ArgumentParser
import Hummingbird
import OpenAPIHummingbird
import OpenAPIRuntime
import PostgresNIO

@main struct RelationalQueryService: AsyncParsableCommand {
    
    @Option(name: [.long], help: #"The API key."#)
    var apiKey: String
    
    @Option(name: [.long], help: #"The host name."#)
    var hostname: String = "127.0.0.1"
    
    @Option(name: [.long], help: #"The port."#)
    var port: Int = 8080
    
    @Option(name: [.long], help: #"The database host."#)
    var dbHost: String = "localhost"
    
    @Option(name: [.long], help: #"The database port."#)
    var dbPort: Int = 5432
    
    @Option(name: [.long], help: #"The database user."#)
    var dbUser: String
    
    @Option(name: [.long], help: #"The database password."#)
    var dbPassword: String
    
    @Option(name: [.long], help: #"The database name."#)
    var dbDatabase: String
    
    @Option(name: [.long], help: #"Optional: A comma-separated list of allowed table names."#)
    var allowedTables: String? = nil
    
    @Option(name: [.long], help: #"Optional: Maximal number of conditions."#)
    var maxConditions: Int? = nil
    
    func run() async throws {
        
        let router = Router()
        router.middlewares.add(LogRequestsMiddleware(.info))
        
        let postgresClient = PostgresClient(
            configuration: .init(
                host: dbHost,
                port: dbPort,
                username: dbUser,
                password: dbPassword,
                database: dbDatabase,
                tls: .disable
            )
        )
        
        let postgresDatabaseMethods = PostgresDatabaseMethods(client: postgresClient)
        
        let api = RelationalQueryAPI(
            postgresDatabaseMethods: postgresDatabaseMethods,
            parameters: Parameters(
                apiKey: apiKey,
                allowedTables: allowedTables?.split(separator: ",", omittingEmptySubsequences: true).map{ String($0) },
                maxConditions: maxConditions
            )
        )
        
        try api.registerHandlers(on: router)
        
        var app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        
        app.addServices(postgresDatabaseMethods.client)
        
        try await app.runService()
    }
}

struct Parameters {
    let apiKey: String
    let allowedTables: [String]?
    let maxConditions: Int?
}
