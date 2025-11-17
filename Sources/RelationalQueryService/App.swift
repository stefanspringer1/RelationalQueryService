import ArgumentParser
import Hummingbird
import OpenAPIHummingbird
import OpenAPIRuntime

@main struct RelationalQueryService: AsyncParsableCommand {
    
    @Option(name: .shortAndLong)
    var hostname: String = "127.0.0.1"
    
    @Option(name: .shortAndLong)
    var port: Int = 8080
    
    func run() async throws {
        
        let router = Router()
        router.middlewares.add(LogRequestsMiddleware(.info))
        
        let api = RelationalQueryAPI()
        
        try api.registerHandlers(on: router)
        
        let app = Application(
            router: router,
            configuration: .init(address: .hostname(hostname, port: port))
        )
        
        try await app.runService()
    }
}
