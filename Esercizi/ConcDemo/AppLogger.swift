//
//  AppLogger.swift
//  ConcDemo
//

import OSLog

/// Namespace centralizzato per tutti i logger dell'app.
/// Ogni categoria corrisponde a un'area funzionale specifica.
/// Per filtrare i log in Console.app usa il subsystem "com.concDemo".
enum AppLogger {

    // Sottosistema comune: usa il bundle identifier o un fallback
    // nonisolated(unsafe): Bundle.main è thread-safe, nessun rischio di race
    private nonisolated(unsafe) static let subsystem =
        Bundle.main.bundleIdentifier ?? "com.concDemo"

    /// Logger per le demo sui Task strutturati e non strutturati
    /// nonisolated(unsafe): Logger è un tipo thread-safe di Apple (os_log)
    nonisolated(unsafe) static let tasks = Logger(subsystem: subsystem, category: "tasks")

    /// Logger per le demo sui TaskGroup
    nonisolated(unsafe) static let groups = Logger(subsystem: subsystem, category: "groups")

    /// Logger per le demo sugli attori
    nonisolated(unsafe) static let actors = Logger(subsystem: subsystem, category: "actors")

    /// Logger per le demo sulle continuazioni (bridge legacy → async)
    nonisolated(unsafe) static let continuations = Logger(subsystem: subsystem, category: "continuations")

    /// Logger per le demo sugli AsyncStream e AsyncThrowingStream
    nonisolated(unsafe) static let streams = Logger(subsystem: subsystem, category: "streams")

    /// Logger per le demo sulla cancellazione cooperativa
    nonisolated(unsafe) static let cancellation = Logger(subsystem: subsystem, category: "cancellation")
}
