//
//  NavigationRouter.swift
//  UIDemo
//
//  Gestione centralizzata della navigazione e del deep linking.
//  Utilizza NavigationPath (iOS 16+) per una navigation stack type-safe.
//
//  Deep link schema: uidemo://navigate/<destinazione>
//  Esempio: uidemo://navigate/glass
//
//  Riferimento: WWDC 2022 "The SwiftUI cookbook for navigation"
//

import SwiftUI
import Observation

// MARK: - Destinazioni di navigazione

/// Tutte le possibili destinazioni raggiungibili tramite NavigationStack.
/// Conformità a Hashable richiesta da NavigationPath.
/// Conformità a Codable per la persistenza dello stato di navigazione.
enum NavigationDestination: Hashable, Codable {
    case itemDetail(id: UUID, title: String)
    case category(name: String)
    case settings
    case profile
    case deepLinkLanding(message: String)
}

// MARK: - NavigationRouter

/// Router centralizzato per la navigazione dell'applicazione.
/// Gestisce sia la NavigationStack (push/pop) sia i deep link in arrivo.
/// @MainActor garantisce che tutte le modifiche alla UI avvengano sul thread principale.
@Observable
@MainActor
final class NavigationRouter {

    // MARK: - Stato

    /// Stack di navigazione principale. Aggiungere/rimuovere elementi
    /// corrisponde a push/pop sulla NavigationStack.
    var path: NavigationPath = NavigationPath()

    /// Deep link in attesa di essere gestito
    var pendingDeepLink: URL? = nil

    /// Indica se è in corso la gestione di un deep link
    var isHandlingDeepLink: Bool = false

    // MARK: - Navigazione programmatica

    /// Naviga verso una destinazione specifica (push).
    func navigate(to destination: NavigationDestination) {
        path.append(destination)
    }

    /// Torna indietro di un livello (pop).
    func goBack() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    /// Torna alla radice della navigation stack (pop to root).
    func goToRoot() {
        path.removeLast(path.count)
    }

    // MARK: - Deep Linking

    /// Gestisce un URL di deep link in arrivo.
    /// Schema supportato: `uidemo://navigate/<destinazione>/<parametro>`
    ///
    /// - Parameter url: URL ricevuto dal sistema operativo
    /// - Returns: `true` se l'URL è stato gestito correttamente
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "uidemo",
              url.host == "navigate"
        else { return false }

        // Analizza il path del deep link
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        isHandlingDeepLink = true
        // Resetta lo stack prima di navigare verso il deep link
        goToRoot()

        // Mappa i componenti del path alla destinazione corretta
        switch pathComponents.first {
        case "detail":
            let title = pathComponents.dropFirst().first ?? "Dettaglio"
            navigate(to: .itemDetail(id: UUID(), title: title))

        case "category":
            let name = pathComponents.dropFirst().first ?? "Generale"
            navigate(to: .category(name: name))

        case "settings":
            navigate(to: .settings)

        case "profile":
            navigate(to: .profile)

        default:
            // Deep link generico: mostra una landing con il messaggio ricevuto
            let message = url.absoluteString
            navigate(to: .deepLinkLanding(message: message))
        }

        isHandlingDeepLink = false
        return true
    }
}

// MARK: - Deep Link URL Builder

/// Utility per costruire URL di deep link in modo type-safe.
/// Utile nei test e nella documentazione.
enum DeepLink {
    static let scheme = "uidemo"

    static func url(for destination: NavigationDestination) -> URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = "navigate"

        switch destination {
        case .itemDetail(_, let title):
            components.path = "/detail/\(title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? title)"
        case .category(let name):
            components.path = "/category/\(name)"
        case .settings:
            components.path = "/settings"
        case .profile:
            components.path = "/profile"
        case .deepLinkLanding(let message):
            components.path = "/landing"
            components.queryItems = [URLQueryItem(name: "msg", value: message)]
        }

        return components.url
    }
}
