//
//  ContentView.swift
//  MyCalender
//
//  Created by tanakamiki on 2026/03/12.
//

import SwiftUI

struct ContentView: View {
    @State private var appViewModel = AppViewModel()

    var body: some View {
        Group {
            if appViewModel.isReady {
                DayView()
            } else if let message = appViewModel.errorMessage {
                ContentUnavailableView("起動できませんでした", systemImage: "exclamationmark.triangle", description: Text(message))
            } else {
                SavingReturnArrowOverlay(isSaving: true)
            }
        }
        .task {
            appViewModel.bootstrap()
        }
    }
}

#Preview {
    ContentView()
}
