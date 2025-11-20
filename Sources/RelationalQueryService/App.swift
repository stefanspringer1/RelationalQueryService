import ArgumentParser
import Hummingbird
import OpenAPIHummingbird
import OpenAPIRuntime
import PostgresNIO



@main struct RelationalQueryService: AsyncParsableCommand {
    
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
    
    @Option(name: [.long], help: #"Maximal number of conditions."#)
    var dbConditions: Int = -1
    
    func run() async throws {
        
        let router = Router()
        router.middlewares.add(LogRequestsMiddleware(.info))
        
        let api = RelationalQueryAPI()
        
        try api.registerHandlers(on: router)
        
        var app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        
        app.addServices()
        
        var environment = Environment()
        environment.set("DB-HOST", value: dbHost)
        environment.set("DB-PORT", value: String(dbPort))
        environment.set("DB-USER", value: dbUser)
        environment.set("DB-PASSWORD", value: dbPassword)
        environment.set("DB-DATABASE", value: dbDatabase)
        environment.set("DB-CONDITIONS", value: String(dbConditions))
        
        try await app.runService()
    }
}
