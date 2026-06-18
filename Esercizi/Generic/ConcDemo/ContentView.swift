//
//  ContentView.swift
//  ConcDemo
//
//  Created by Antonio Minelli.
//

import SwiftUI

/// Vista principale: hub di navigazione verso le sezioni demo della concorrenza.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Concorrenza di base") {
                    NavigationLink("Task strutturati e non", destination: TaskDemoView())
                    NavigationLink("Gruppi di task", destination: TaskGroupDemoView())
                    NavigationLink("Cancellazione cooperativa", destination: CancellationDemoView())
                }
                Section("Isolamento dello stato") {
                    NavigationLink("Attori (Actor)", destination: ActorDemoView())
                }
                Section("Interoperabilità e flussi") {
                    NavigationLink("Continuazioni (legacy → async)", destination: ContinuationDemoView())
                    NavigationLink("AsyncStream / AsyncThrowingStream", destination: AsyncStreamDemoView())
                }
            }
            .navigationTitle("ConcDemo")
        }
    }
}

#Preview {
    ContentView()
}
