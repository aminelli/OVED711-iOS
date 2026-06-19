class APIClient {
    func fetchData() -> String {
        return "Dati dal server"
    }
}

class ViewModel {
    private let api = APIClient() // ❌ dipendenza creata internamente

    func load() {
        let data = api.fetchData()
        print(data)
    }
}
