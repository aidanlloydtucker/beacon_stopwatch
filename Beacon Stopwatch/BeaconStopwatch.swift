//
//  BeaconStopwatch.swift
//  Beacon Stopwatch
//
//  Created by Aidan Lloyd-Tucker on 1/31/25.
//

import SwiftUI

struct BeaconStopwatch: View {
    @StateObject private var timer = StopWatchManager()
    @State private var isRunning = false
    @State private var flatSplits: [TimeInterval] = []
    @State private var currentSplitIdx: Int = 0
    @State private var numBeacons: Int = 1
    @State private var showMoreOptions = false
    @State private var resetAlert: Bool = false
    @State private var notificationDate: Date = Date()
    
    // [[] Beacon Split Names] with times attached
    private var splits: [[(String, TimeInterval?)]] {
        splitNames.enumerated().map { (bi, bsns) in
            bsns.enumerated().map { (si, sn) in
                let fi = splitsIdxtoFlatIdx(bi, si)
                if fi == -1 || fi >= flatSplits.count {
                    return (sn, nil)
                } else {
                    return (sn, flatSplits[fi])
                }
            }
        }
    }
    
    private var splitNames: [[String]]  {
        [BeaconSplitOrder] + Array(1...numBeacons).filter {$0 > 1}.map { _ in
            BeaconSplitOrderExtra
        }
    }
    
    private var totalSplits: Int {
        splitNames.reduce(0) { $0 + $1.count }
    }
    
    // flatSplits index to the splits index (Beacon Idx, Split Idx)
    private func flatIdxToSplitIdx(_ flatIdx: Int) -> (Int, Int) {
        if flatIdx >= flatSplits.count {
            return (-1, -1)
        }
        
        return unsafeFlatIdxToSplitIdx(flatIdx)
    }
    
    // unsafeFlatIdxToSplitIdx splits the flat index into a beacon and split index unsafely
    private func unsafeFlatIdxToSplitIdx(_ flatIdx: Int) -> (Int, Int) {
        var idx = 0
        
        for i in 0..<numBeacons {
            for j in 0..<splitNames[i].count {
                if idx == flatIdx {
                    return (i, j)
                } else {
                    idx += 1
                }
            }
        }
        return (-1, -1)
    }
    
    private func splitsIdxtoFlatIdx(_ beaconIdx: Int, _ splitIdx: Int) -> (Int) {
        if beaconIdx >= numBeacons || splitIdx >= splitNames[beaconIdx].count {
            return -1
        }
        
        var idx = 0
        for i in 0...beaconIdx {
            for j in 0..<splitNames[i].count {
                if i == beaconIdx && j == splitIdx {
                    return idx
                } else {
                    idx += 1
                }
            }
        }
        
        return -1
    }
    
    private var beaconTimes: [TimeInterval] {
        splits.map { bs in
            bs.reduce(0) { result, split in
                result + (split.1 ?? 0)
            }
        }
    }

    private var beaconTimesText: String {
        // create an array of beacon times by adding everything through END
        var textArr: [String] = ["Total Time: \(formatTime(timer.totalElapsedTime))"]
        if beaconTimes.count > 1 {
            textArr += beaconTimes.enumerated().map { (i, time) in
                "Beacon \(i+1): \(formatTime(time))"
            }
            
        }
        return textArr.joined(separator: "\n")
    }
    
    private var exportText: String {
        return splits.enumerated().map { (bi, bs) in
            var str = bs.map { split in
                "\(BeaconSplitNames[split.0] ?? "Unknown"): \(formatTime(split.1 ?? 0))"
            }.joined(separator: "\n")
            if numBeacons > 1 {
                let time = bs.reduce(0) { result, split in
                    result + (split.1 ?? 0)
                }
                str += "\n  = Beacon \(bi + 1) Time: \(formatTime(time))\n"
            }
            return str + "\n"
        }
        .reduce("""
\(beaconTimesText)
---


""", +)
    }
    
    private var splitsDone: Bool {
        currentSplitIdx >= totalSplits
    }
    
    private func sumBeaconTime(_ beaconIdx: Int) -> TimeInterval {
        var beaconTime = splits[beaconIdx].reduce(0) { result, split in
            result + (split.1 ?? 0)
        }
        // if current beacon, we must keep up to date
        let (currentBeaconIdx, _) = unsafeFlatIdxToSplitIdx(currentSplitIdx)
        if currentBeaconIdx == beaconIdx {
            beaconTime += timer.currentSplitTime
        }
        return beaconTime
    }
    
    
    var body: some View {
        VStack(spacing: 20) {
            Text(formatTime(timer.totalElapsedTime))
                .font(.system(size:80).monospacedDigit())
                .padding(.horizontal)
            
            
            HStack {
                Button(action: {
                    if isRunning {
                        next()
                    } else {
                        resetAlert = true
                    }
                }) {
                    Text(!isRunning && timer.totalElapsedTime > 0 ? "Reset" : (currentSplitIdx >= totalSplits - 1 ? "Finish" : "Next"))
                        .frame(width: 100, height: 100)
                        .background(!isRunning && timer.totalElapsedTime == 0 ? .gray.opacity(0.3) : (isRunning ?  .green : .gray))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .font(.title)
                }
                .disabled(!isRunning && timer.totalElapsedTime == 0)
                .alert(
                    Text("Are you sure you want to reset"),
                    isPresented: $resetAlert
                ) {
                    Button(role: .destructive) {
                        resetAlert = false
                        reset()
                    } label: {
                        Text("Reset")
                    }
                    Button("Cancel", role: .cancel) {
                        resetAlert = false
                    }
                }
                
                Spacer()
                
                Button(action: {
                    isRunning.toggle()
                    if isRunning {
                        start()
                    } else {
                        stop()
                    }
                }) {
                    Text(isRunning ? "Stop" : "Start")
                        .frame(width:100, height: 100)
                        .background(isRunning ? .red : (splitsDone ? .green.opacity(0.3) : .green))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .font(.title)
                }
                .disabled(splitsDone)
            }
            .padding(.horizontal)
            
            List() {
                ForEach(Array(splits.enumerated()), id: \.offset) { bi, bs in
                    
                    Section(header: Text("Beacon \(bi+1)"), footer: Text("Recovered Time: \(sumBeaconTime(bi) > 0 ? formatTime(sumBeaconTime(bi)) : "---")")) {
                        ForEach(Array(bs.enumerated()), id: \.offset) { si, split in
                            HStack {
                                Text(BeaconSplitNames[split.0] ?? "unknown" )
                                Spacer()
                                if let st = split.1 {
                                    Text(formatTime(st))
                                        .font(.system(size:16).monospacedDigit())
                                } else if currentSplitIdx == splitsIdxtoFlatIdx(bi, si) {
                                    Text(formatTime(timer.currentSplitTime))
                                        .font(.system(size:16).monospacedDigit())
                                } else {
                                    Text("---")
                                }
                                
                            }
//                            .listRowInsets(EdgeInsets())
                        }
                    }
                }
            }
            .listStyle(.automatic)
        }
//        .padding()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                
                if splitsDone {
                    ShareLink(item: exportText)
                }
                
                
                Button {
                    showMoreOptions.toggle()
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                .popover(isPresented: $showMoreOptions,
                         attachmentAnchor: .point(.bottom), arrowEdge: .bottom, content: {
                    Stepper("Beacons (\(numBeacons))",
                            value: $numBeacons,
                            in: 1...3
                    )
                    .presentationCompactAdaptation(.popover)
                    .padding()
                    .disabled(isRunning)
                })
            }
            
        }
        .navigationTitle("Beacon Stopwatch")
        .navigationBarTitleDisplayMode(.inline)
        
        
    }
    
    private func start() {
        timer.start()
    }
    
    private func next() {
        flatSplits.append(timer.currentSplitTime)
        if currentSplitIdx + 1 < totalSplits {
            currentSplitIdx += 1
        } else {
            isRunning = false
            stop()
            currentSplitIdx = totalSplits
        }
        timer.currentSplitTime = 0
    }
    
    private func stop() {
        timer.pause()
    }
    
    private func reset() {
        flatSplits = []
        timer.stop()
        currentSplitIdx = 0
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time - Double(minutes * 60 + seconds)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
}

let BeaconSplitOrder: [String] = [
    "START",
    "signalSearch",
    "coarseSearch",
    "fineSearch",
    "gear",
    "probe",
    "END"
]

let BeaconSplitOrderExtra: [String] = [
    "START_NEXT",
    "signalSearch",
    "coarseSearch",
    "fineSearch",
    "probe",
    "END"
]

let BeaconSplitNames: [String:String] = [
    "START":"Stationary at Top",
    "signalSearch":"Signal Search",
    "coarseSearch":"Coarse Search",
    "fineSearch":"Fine Search",
    "gear":"Gear",
    "probe":"Probe",
    "END":"Shovel",
    // extra
    "START_NEXT":"Skis On"
]


#Preview {
    NavigationStack {
        BeaconStopwatch()
    }
}
