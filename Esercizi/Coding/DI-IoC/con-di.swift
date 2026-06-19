protocol APIClientProtocol {
    func fetchData() -> String
}

class APIClient: APIClientProtocol {
    func fetchData() -> String {
        return "Dati dal server"
    }
}

class APIClientNew: APIClientProtocol {
    func fetchData() -> String {
        return "Dati dal server"
    }
}

class ViewModel {
    private let api: APIClientProtocol

    // ✅ DI via initializer
    init(api: APIClientProtocol) {
        self.api = api
    }

    func load() {
        let data = api.fetchData()
        print(data)
    }
}

let api = APIClient()
let viewModel = ViewModel(api: api) // ✅ dependency injection

let api2 = APIClientNew()
let viewModel2 = ViewModel(api: api2) // ✅ dependency injection

viewModel.load()
viewModel2.load()

