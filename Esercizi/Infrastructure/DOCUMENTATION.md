# InfraDemo — Documentazione Tecnica

> **Piattaforma**: iOS 26+ · **Linguaggio**: Swift 6.3 · **UI**: SwiftUI  
> **Data**: Giugno 2026

---

## Sommario

1. [Architettura generale](#1-architettura-generale)
2. [MVVM-C e Clean Architecture](#2-mvvm-c-e-clean-architecture) — include SPM modularizzazione
3. [Dependency Injection](#3-dependency-injection)
4. [REST & JSON avanzato](#4-rest--json-avanzato) — include union type Codable
5. [URLSession con async/await](#5-urlsession-con-asyncawait)
6. [Resilience Patterns](#6-resilience-patterns)
7. [Logging e Monitoring](#7-logging-e-monitoring) — include guida Instruments
8. [Struttura del progetto](#8-struttura-del-progetto)
9. [Come aggiungere i file a Xcode](#9-come-aggiungere-i-file-a-xcode)

---

## 1. Architettura generale

Il progetto implementa **Clean Architecture** con pattern **MVVM-C** (Model-View-ViewModel-Coordinator) organizzato in layer orizzontali:

```
┌─────────────────────────────────────────────────────┐
│                   Presentation Layer                │
│          (SwiftUI Views + ViewModels + Coordinators)│
├─────────────────────────────────────────────────────┤
│                    Domain Layer                     │
│           (Entities, UseCases, Repository protocols)│
├─────────────────────────────────────────────────────┤
│                     Data Layer                      │
│       (Repository implementations, DTOs, Network)   │
├─────────────────────────────────────────────────────┤
│                Infrastructure Layer                 │
│         (Resilience, Logging, Cache, DI)            │
└─────────────────────────────────────────────────────┘
```

### La Dependency Rule

> *"Le dipendenze del codice sorgente puntano sempre verso l'interno"* — Robert C. Martin

- Il **Domain** non conosce il **Data** layer
- Il **Data** layer implementa le interfacce del **Domain**
- Il **Presentation** layer dipende dal **Domain** (UseCase protocols), non dal **Data**
- Il binding avviene nel `DependencyContainer` (Composition Root)

---

## 2. MVVM-C e Clean Architecture

### Il ruolo del Coordinator

Il **Coordinator** separa la logica di navigazione dal ViewModel:

| Responsabilità | ViewModel | Coordinator |
|---------------|-----------|-------------|
| Logica di presentazione | ✅ | ❌ |
| Stato della UI | ✅ | ❌ |
| Navigazione | ❌ | ✅ |
| Creazione di ViewModels figli | ❌ | ✅ |
| Deep link handling | ❌ | ✅ (AppCoordinator) |

```swift
// Il ViewModel chiama il coordinator senza sapere cosa accade
coordinator?.showDetail(post: post)

// Il Coordinator gestisce la navigazione nel suo NavigationStack
public func showDetail(post: Post) {
    path.append(PostsRoute.detail(post: post))
}
```

### UseCase e Repository

```
PostsView → PostsViewModel → FetchPostsUseCase → PostRepository (protocol)
                                                        ↓
                                                PostRepositoryImpl (Data layer)
                                                        ↓
                                                NetworkActor (URLSession)
```

**Vantaggio**: i test del ViewModel usano un mock di `FetchPostsUseCaseProtocol` senza toccare la rete.

### Modularizzazione con Swift Package Manager

Il file `Package.swift` alla radice del progetto definisce **5 moduli** che rispecchiano i layer dell'architettura:

```
InfraDemo (app host)
    ├── PostsFeature  ──────────────────────┐
    ├── UsersFeature  ──────────────────────┤
    │       ↓                               │
    ├── InfraKit  (DI, Logging, Resilienza) │
    │       ↓                               │
    ├── NetworkKit (URLSession, Cache, DTO) │
    │       ↓                               │
    └── DomainKit (Entità, UseCase, Repo)  ←┘
```

| Modulo | Path | Dipendenze |
|--------|------|------------|
| `DomainKit` | `Core/Domain` | nessuna |
| `NetworkKit` | `Core/Data` | `DomainKit` |
| `InfraKit` | `Core/{DI,FeatureFlags,Infrastructure}` | `DomainKit`, `NetworkKit` |
| `PostsFeature` | `Features/Posts` | `DomainKit`, `InfraKit` |
| `UsersFeature` | `Features/Users` | `DomainKit`, `InfraKit` |

Ogni modulo esporta solo i tipi `public`, nascondendo le implementazioni `internal`. Il compilatore Swift verifica staticamente che nessun modulo violi la Dependency Rule importando un modulo "superiore".

**Come aggiungere il Package al progetto Xcode esistente**:
1. In Xcode: **File → Add Package Dependencies…**
2. Seleziona **Add Local…** e scegli la cartella radice del progetto
3. Xcode riconosce `Package.swift` e aggiunge i target come dipendenze locali
4. Nel target `InfraDemo` → **Frameworks, Libraries, and Embedded Content** → aggiungi i moduli necessari

### Feature Flag per modulo

I flag controllano le funzionalità a runtime:

```swift
if featureFlags[.streamingEnabled] {
    // Mostra il bottone streaming solo se il flag è abilitato
}
```

---

## 3. Dependency Injection

### Init-based DI

Il metodo preferito: le dipendenze sono esplicite, il codice è testabile senza framework terzi.

```swift
// UseCase riceve il repository come protocollo
public struct FetchPostsUseCase: FetchPostsUseCaseProtocol {
    private let repository: any PostRepository
    
    public init(repository: any PostRepository) {
        self.repository = repository
    }
}
```

### DependencyContainer (Composition Root)

Un unico oggetto assembla l'intero grafo delle dipendenze:

```swift
@MainActor
public final class DependencyContainer: ObservableObject {
    // Tutti i singleton e le factory dell'app
    let networkActor: NetworkActor
    let postRepository: any PostRepository
    let fetchPostsUseCase: any FetchPostsUseCaseProtocol
    // ...
}
```

### EnvironmentKey in SwiftUI

Distribuzione delle dipendenze senza prop drilling:

```swift
// Definizione
private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = DependencyContainer()
}

extension EnvironmentValues {
    var dependencies: DependencyContainer { … }
}

// Iniezione (nel genitore)
.environment(\.dependencies, container)

// Lettura (in qualsiasi vista figlia)
@Environment(\.dependencies) private var deps
```

---

## 4. REST & JSON avanzato

### Endpoint Protocol

Ogni endpoint è un tipo enumerato che implementa `Endpoint`:

```swift
public enum PostsEndpoint: Endpoint {
    case list(page: Int, limit: Int)
    case detail(id: Int)
    case byUser(userID: Int)
}
```

Vantaggi:
- **Type-safe**: l'IDE suggerisce tutti i parametri
- **Testabile**: si può verificare l'URL generato senza fare chiamate di rete
- **Esaustivo**: il compilatore avvisa se si aggiunge un caso senza gestirlo

### Codable avanzato: Union Type

Quando l'API restituisce tipi diversi nella stessa lista:

```swift
public enum FeedItemDTO: Codable {
    case post(PostDTO)
    case article(ArticleDTO)
    
    public init(from decoder: Decoder) throws {
        let type_ = try container.decode(String.self, forKey: .type)
        switch type_ {
        case "post":    self = .post(try ...)
        case "article": self = .article(try ...)
        default: throw DecodingError.dataCorrupted(...)
        }
    }
}
```

### Paginazione Cursor-based

Il cursore è un token opaco (Base64 in questo demo):

```
Prima pagina:  fetchPosts(cursor: nil)    → (posts, nextCursor: "cGFnZT0y")
Seconda pagina: fetchPosts(cursor: "cGFnZT0y") → (posts, nextCursor: "cGFnZT0z")
Ultima pagina:  fetchPosts(cursor: "cGFnZT0x...") → (posts, nextCursor: nil)
```

Rispetto alla paginazione offset:
- **Consistente**: non perde elementi se vengono aggiunti/rimossi durante la paginazione
- **Scalabile**: non richiede COUNT(*) sul server
- **Nasconde i dettagli**: il client non sa se è offset, timestamp o token cifrato

### URLProtocol custom

`MockURLProtocol` intercetta le richieste nei test:

```swift
let config = URLSessionConfiguration.ephemeral
config.protocolClasses = [MockURLProtocol.self]
let session = URLSession(configuration: config)
```

Tutti i test di rete vengono eseguiti **senza connessione internet**, in modo deterministico.

---

## 5. URLSession con async/await

### API async di URLSession

| Metodo | Uso |
|--------|-----|
| `data(for:)` | JSON/testo, risposta completa |
| `download(for:)` | File pesanti (salva su disco) |
| `bytes(for:)` | Streaming progressivo (SSE, NDJSON) |

### AsyncSequence per streaming

```swift
// Lato server (hypothetical SSE endpoint)
// data: {"id": 1, "title": "..."}
// data: {"id": 2, "title": "..."}

// Lato client
for try await line in bytes.lines {
    try Task.checkCancellation()
    processLine(line)
}
```

### Cancellazione con Task

```swift
// Salva il Task per annullarlo in seguito
let task = Task { ... }
task.cancel()  // Il for-await lancia CancellationError
```

### async let vs TaskGroup

```swift
// async let — N fisso di task, risultati tipizzati diversamente
async let post: PostDTO = client.perform(postEndpoint, as: PostDTO.self)
async let user: UserDTO = client.perform(userEndpoint, as: UserDTO.self)
let (p, u) = try await (post, user)

// TaskGroup — N dinamico di task, stesso tipo di risultato
withThrowingTaskGroup(of: PostDTO.self) { group in
    for id in ids { group.addTask { try await fetch(id) } }
    for try await post in group { results.append(post) }
}
```

### NetworkActor e strict concurrency

```swift
// actor garantisce accesso esclusivo allo stato interno
public actor NetworkActor: HTTPClientProtocol {
    private let session: URLSession  // Isolato nell'actor
    
    // nonisolated: può essere chiamato da qualsiasi contesto
    public nonisolated func stream(...) -> AsyncThrowingStream<String, Error> { ... }
}
```

---

## 6. Resilience Patterns

### Retry con backoff esponenziale

```
Tentativo 1: eseguito immediatamente
Tentativo 2: attendi 0.5s ± jitter
Tentativo 3: attendi 1.0s ± jitter
Tentativo 4: attendi 2.0s ± jitter (se maxAttempts > 3)
...
Max delay:   30s (cap)
```

Il **jitter** (±20%) distribuisce i retry di client multipli, evitando il "thundering herd" su server già sotto stress.

### URLCache e HTTP caching

```
Client ────→ URLCache (disco) ────→ Server
              ↑                      ↑
         Cache-Control          ETag / Last-Modified
         max-age=300            304 Not Modified
```

La URLSession rispetta automaticamente:
- `Cache-Control: max-age=N` — usa la cache per N secondi
- `ETag` / `If-None-Match` — rivalidazione condizionale
- `Last-Modified` / `If-Modified-Since` — rivalidazione temporale

### NSCache vs URLCache

| | NSCache | URLCache |
|---|---------|----------|
| **Tipo dati** | Qualsiasi oggetto Swift | Risposte HTTP |
| **Persistenza** | Solo memoria | Memoria + disco |
| **Gestione memoria** | Automatica (OS) | Manuale + policy HTTP |
| **Thread-safety** | ✅ | ✅ |
| **Invalidazione** | Manuale o automatica (memory pressure) | Automatica (HTTP headers) |
| **Uso tipico** | Oggetti decodificati, immagini | Risposte JSON grezze |

### Circuit Breaker

```
     Richieste normali
         │
    [CLOSED] ──── 3 fallimenti ────→ [OPEN]
         ↑                               │
         │                          15s cooldown
         │                               │
    successo ←──── [HALF-OPEN] ←────────┘
                        │
                   fallimento
                        │
                   torna OPEN
```

### NWPathMonitor e offline-first

```swift
monitor.pathUpdateHandler = { path in
    let status = path.status == .satisfied ? "online" : "offline"
}
```

L'app:
1. Mostra un banner arancione quando è offline
2. Usa la cache NSCache/URLCache per i dati precedentemente scaricati
3. Riprende automaticamente quando la connessione è ripristinata

---

## 7. Logging e Monitoring

### os.Logger: livelli e privacy

```swift
// Livelli (dal meno al più critico):
logger.debug(...)   // Solo in debug, non va in produzione
logger.info(...)    // Informativo, aggregato
logger.notice(...)  // Default, sempre persistito
logger.warning(...) // Avvisi
logger.error(...)   // Errori recuperabili
logger.fault(...)   // Crash, dati persi → paging immediato

// Privacy:
logger.info("URL: \(url, privacy: .public)")   // Visibile nei log
logger.info("Token: \(token, privacy: .private)") // Redatto: <private>
```

Visibili in **Console.app** filtrando per subsystem `com.infrademo`.

### MetricKit

Metriche aggregate consegnate ogni ~24h:

| Metrica | Classe |
|---------|--------|
| Tempo di avvio | `MXAppLaunchMetric` |
| Utilizzo CPU | `MXCPUMetric` |
| Memoria picco | `MXMemoryMetric` |
| Trasferimento rete | `MXNetworkTransferMetric` |
| Hang UI (>250ms) | `MXHangDiagnostic` |
| Crash + stack trace | `MXCrashDiagnostic` |

### Breadcrumb Trail

Sequenza degli ultimi 50 eventi significativi:

```
[navigation] Aperta schermata: Posts        14:32:01
[network]    HTTP 200 ← /posts?_page=1      14:32:02
[ui]         Selezionato post #5            14:32:05
[network]    HTTP 200 ← /users/1            14:32:05
[navigation] Aperta schermata: PostDetail   14:32:05
```

In caso di crash, il trail viene inviato al server di crash reporting per il contesto.

### Instruments: profiler chiave

Per avviare una sessione di profiling: **Xcode → Product → Profile** (`⌘I`), poi scegli il template.

---

#### Network (Profiler di rete)

**Cosa misura**: byte inviati/ricevuti, latenza per request, code di connessione, errori HTTP, utilizzo DNS e TLS.

**Quando usarlo**: latenza elevata nelle chiamate API, sospetto di doppie richieste, verifica che la cache HTTP (`URLCache`) funzioni correttamente.

**Come leggere i risultati**:
- Colonna **Duration**: tempo totale dalla richiesta alla risposta — valori >500ms su WiFi indicano un problema server o DNS
- Colonna **Bytes In/Out**: confronta con i dati attesi; troppo payload = JSON non filtrato
- Riga **Connection Reuse**: verde = HTTP/2 multiplexing attivo, rosso = nuova connessione per ogni request (costo TLS)
- `(from cache)` nella colonna Status = `URLCache` ha restituito la risposta senza toccare la rete ✅

**InfraDemo — cosa cercare**:
```
NetworkActor.perform(_:as:)  → deve mostrare retry con delay esponenziale
CacheManager                 → seconda chiamata identica deve essere (from cache)
TokenRefreshActor            → un solo refresh per N richieste concorrenti (no thundering herd)
```

---

#### Time Profiler

**Cosa misura**: campiona lo stack del CPU ogni ~1ms su tutti i thread, mostrando dove viene speso il tempo di esecuzione.

**Quando usarlo**: scroll lento nella lista dei post, animazioni che perdono frame (< 60 fps / 120 fps su ProMotion), avvio app lento.

**Come leggere i risultati**:
- Colonna **Self (ms)**: tempo speso *dentro* la funzione, esclusi i chiamati — le funzioni con Self alto sono i veri colli di bottiglia
- **Call Tree → Invert Call Tree**: mostra le foglie più costose al top (più utile di default)
- **Hide System Libraries**: filtra fuori il runtime Swift e UIKit, mostra solo il codice dell'app
- Thread **com.apple.main-thread**: qualsiasi operazione costosa qui causa jank — deve essere quasi vuoto durante scroll

**InfraDemo — cosa cercare**:
```
PostsViewModel.loadNextPage()  → deve girare su Task (thread pool), NON sul main thread
BreadcrumbTrail.add(_:)        → actor hop leggero, non deve apparire nel top 10
JSONDecoder.decode(_:from:)    → se > 5ms per risposta, considera parsing incrementale
```

---

#### Allocations

**Cosa misura**: ogni allocazione heap — oggetti creati, retain count, deallocazioni, memoria viva nel tempo.

**Quando usarlo**: memory leak sospetti, crescita continua della memoria durante la paginazione infinita, `Allocations > 50 MB` in MetricKit.

**Come leggere i risultati**:
- **Mark Generation** (barra `G`): scatta uno snapshot; naviga nella lista e scatta un secondo snapshot — gli oggetti vivi tra i due snapshot che non si azzerano sono candidati a leak
- Filtro **Created & Persistent**: mostra solo oggetti mai deallocati — i ViewModel o Coordinator qui sono bug
- **Cycles & Roots**: Instruments individua automaticamente i retain cycle — espandi il ciclo per trovare il punto da rompere con `[weak self]` o `weak var`
- Tipo **`_SwiftWeakRef`** persistente: un oggetto detenuto solo da weak reference — segnale di lifetime sbagliato

**InfraDemo — cosa cercare**:
```
PostsCoordinator / UsersCoordinator  → devono deallocarsi quando si cambia tab
Task (closure)                       → leak di Task cancellati male → usa .cancel() nell'onDisappear
NSCache (CacheManager.inMemory)      → cresce durante scroll? normale. Non si svuota mai? leak
```

**Pattern da applicare per prevenire leak**:
```swift
// ViewModel tiene il coordinator come weak per evitare retain cycle
private weak var coordinator: PostsCoordinator?

// Task salvato e cancellato correttamente
private var loadTask: Task<Void, Never>?

func onDisappear() {
    loadTask?.cancel()  // Instruments Allocations non mostrerà Task leaked
}
```

---

#### Hangs (Hang Detection)

**Cosa misura**: intervalli in cui il **main thread** è bloccato per più di **250 ms**, causando frame drop percepibili dall'utente (iOS segnala questi come hang a MetricKit dopo 250ms, e come ANR dopo 8s).

**Quando usarlo**: UI che non risponde a tap/scroll, spinner che si bloccano, segnalazioni `MXHangDiagnostic` da MetricKit in produzione.

**Come leggere i risultati**:
- Barra rossa nella timeline = hang rilevato; cliccaci sopra per vedere lo stack frame del main thread al momento del blocco
- **Heaviest Stack Trace**: lo stack più lungo durante il hang — quasi sempre mostra operazioni I/O, lock o decodifica JSON sul main thread
- Soglie: **giallo** = 100–250ms (warning), **rosso** = >250ms (hang confermato)

**InfraDemo — cosa cercare**:
```
// SBAGLIATO — blocca il main thread durante la decodifica
@MainActor
func loadPosts() {
    let data = try! Data(contentsOf: url)  // I/O sincrono sul main thread → HANG
    posts = try! JSONDecoder().decode(...)  // OK se piccolo, ma preferire Task
}

// CORRETTO — usa async/await per spostare il lavoro fuori dal main thread
@MainActor
func loadPosts() {
    Task {
        let posts = try await fetchPostsUseCase.execute(cursor: nil)
        self.posts = posts  // Torna al MainActor solo per aggiornare lo stato
    }
}
```

**Workflow consigliato per zero hang**:
1. Avvia Hangs profiler
2. Esegui ogni interazione utente (tap, scroll, pull-to-refresh, cambio tab)
3. Nessuna barra rossa = app hang-free ✅
4. Confronta con i dati `MXHangDiagnostic` ricevuti via MetricKit — devono corrispondere

---

#### Riepilogo rapido

| Profiler | Shortcut | Problema tipico in InfraDemo |
|----------|----------|-----------------------------|
| **Network** | `⌘I` → Network | Cache miss ripetuti, doppie richieste token |
| **Time Profiler** | `⌘I` → Time Profiler | `JSONDecoder` sul main thread |
| **Allocations** | `⌘I` → Allocations | Coordinator non deallocato, Task leaked |
| **Hangs** | `⌘I` → Hangs | `Data(contentsOf:)` o UserDefaults.synchronize() sul main thread |

---

## 8. Struttura del progetto

```
InfraDemo/
├── Core/
│   ├── Domain/
│   │   ├── Entities/
│   │   │   ├── Post.swift
│   │   │   └── User.swift
│   │   ├── Repositories/
│   │   │   ├── PostRepository.swift        ← protocollo
│   │   │   └── UserRepository.swift        ← protocollo
│   │   └── UseCases/
│   │       ├── FetchPostsUseCase.swift
│   │       └── FetchUserUseCase.swift
│   ├── Data/
│   │   ├── Network/
│   │   │   ├── Endpoint.swift              ← Endpoint protocol + enums
│   │   │   ├── NetworkClient.swift         ← NetworkActor (URLSession async)
│   │   │   ├── TokenRefreshActor.swift     ← Refresh token con coalescing
│   │   │   └── MockURLProtocol.swift       ← URLProtocol per i test
│   │   ├── Models/
│   │   │   ├── PostDTO.swift               ← Codable + union type
│   │   │   └── UserDTO.swift               ← Codable annidato
│   │   ├── Repositories/
│   │   │   ├── PostRepositoryImpl.swift    ← impl. con cache cursor-pagination
│   │   │   └── UserRepositoryImpl.swift
│   │   └── Cache/
│   │       └── CacheManager.swift          ← NSCache vs URLCache
│   ├── Infrastructure/
│   │   ├── Resilience/
│   │   │   ├── RetryPolicy.swift           ← Backoff esponenziale + jitter
│   │   │   ├── CircuitBreaker.swift        ← Circuit Breaker (actor)
│   │   │   └── NetworkMonitor.swift        ← NWPathMonitor offline-first
│   │   └── Logging/
│   │       ├── AppLogger.swift             ← os.Logger centralizzato
│   │       ├── BreadcrumbTrail.swift       ← Trail degli eventi (actor)
│   │       └── MetricKitSubscriber.swift   ← MetricKit integration
│   ├── DI/
│   │   ├── DependencyContainer.swift       ← Composition Root
│   │   └── EnvironmentKeys.swift           ← SwiftUI EnvironmentKey
│   └── FeatureFlags/
│       └── FeatureFlag.swift               ← Flag + FeatureFlagService + UI
├── Features/
│   ├── Posts/
│   │   ├── Coordinator/
│   │   │   └── PostsCoordinator.swift      ← MVVM-C coordinator
│   │   ├── ViewModel/
│   │   │   ├── PostsViewModel.swift        ← Paginazione, cancellazione Task
│   │   │   └── PostDetailViewModel.swift
│   │   └── View/
│   │       ├── PostsView.swift             ← Lista infinita + offline banner
│   │       ├── PostDetailView.swift
│   │       └── StreamingDemoView.swift     ← AsyncSequence streaming
│   └── Users/
│       ├── Coordinator/
│       │   └── UsersCoordinator.swift
│       ├── ViewModel/
│       │   └── UsersViewModel.swift
│       └── View/
│           └── UsersView.swift
├── App/
│   ├── AppCoordinator.swift                ← Root coordinator + TabView
│   └── InfraDashboardView.swift            ← Dashboard tecnica
├── ContentView.swift                       ← Alias per preview
└── InfraDemoApp.swift                      ← @main + MetricKit registration
```

---

## 9. Come aggiungere i file a Xcode

Poiché i file sono stati creati fuori da Xcode, è necessario aggiungerli manualmente al progetto:

1. Apri `InfraDemo.xcodeproj` in Xcode 26
2. Nel Project Navigator, seleziona la cartella `InfraDemo`
3. Tasto destro → **Add Files to "InfraDemo"…**
4. Naviga fino alla cartella `InfraDemo/Core` e selezionala
5. Assicurati che:
   - ✅ **Copy items if needed** sia **deselezionato** (i file sono già nel posto corretto)
   - ✅ **Create groups** sia selezionato
   - ✅ Il target `InfraDemo` sia checkato
6. Ripeti per le cartelle `Features` e `App`
7. Build (`⌘B`) — risolvi eventuali errori di compilazione

> **Tip**: In alternativa, usa `File → Add Package Dependencies…` per convertire il progetto in SPM multi-modulo.

---

*Documentazione generata per InfraDemo — iOS 26 · Swift 6.3*
