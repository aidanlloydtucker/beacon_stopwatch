//
//  StopWatchManager.swift
//  Beacon Stopwatch
//
//  Created by Aidan Lloyd-Tucker on 1/31/25.
//

import SwiftUI

class StopWatchManager: ObservableObject {
    @Published var totalElapsedTime: TimeInterval = 0
    @Published var currentSplitTime: TimeInterval = 0
    private var timer: Timer = Timer()
    @State private var bgMoveDate: Date = Date()
    
    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
            self.totalElapsedTime += 0.01
            self.currentSplitTime += 0.01
        }
        RunLoop.main.add(timer, forMode: .common)
    }
    
    func stop() {
        timer.invalidate()
        self.totalElapsedTime = 0
        self.currentSplitTime = 0
    }
    
    func pause() {
        timer.invalidate()
    }
    
    func movingToBackground() {
        bgMoveDate = Date()
        self.pause()
    }
    
    func movingToForeground() {
        let deltaTime = Date().timeIntervalSince(bgMoveDate)
        self.totalElapsedTime += deltaTime
        self.currentSplitTime += deltaTime
        self.start()
    }
}
