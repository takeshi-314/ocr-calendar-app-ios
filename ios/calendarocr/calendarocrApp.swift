//
//  calendarocrApp.swift
//  calendarocr
//
//  Created by TT on 2026/05/07.
//

import SwiftUI
import FirebaseCore

@main
struct CalendarOCRApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
