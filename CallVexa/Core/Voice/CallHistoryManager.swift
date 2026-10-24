import Foundation
import Combine

final class CallHistoryManager: ObservableObject {
    static let shared = CallHistoryManager()
    
    @Published var calls: [CallRecord] = []
    
    private let storageKey = "callvexa_persisted_call_history_v1"
    
    private init() {
        loadFromStorage()
    }
    
    func loadFromStorage() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let saved = try? JSONDecoder().decode([CallRecord].self, from: data) else {
            return
        }
        if Thread.isMainThread {
            self.calls = saved
        } else {
            DispatchQueue.main.async {
                self.calls = saved
            }
        }
    }
    
    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(calls) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    @discardableResult
    func recordCall(
        toNumber: String,
        status: String,
        durationSec: Int,
        country: String? = nil,
        direction: String = "outbound"
    ) -> CallRecord {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let uniqueId = Int(abs(nowMs % 1_000_000_000))
        
        let record = CallRecord(
            id: uniqueId,
            toNumber: toNumber,
            status: status,
            duration: durationSec,
            country: country,
            direction: direction,
            startedAt: DateFormatters.mediumDateTime.string(from: Date()),
            createdAt: nowMs
        )
        
        let updateBlock = {
            // Remove duplicate if same number logged within 3 seconds
            self.calls.removeAll { existing in
                existing.toNumber == toNumber && abs((existing.createdAt ?? 0) - nowMs) < 3000
            }
            self.calls.insert(record, at: 0)
            if self.calls.count > 250 {
                self.calls = Array(self.calls.prefix(250))
            }
            self.saveToStorage()
        }
        
        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
        
        return record
    }
    
    func mergeServerCalls(_ serverCalls: [CallRecord]) {
        guard !serverCalls.isEmpty else { return }
        let updateBlock = {
            var map: [Int: CallRecord] = [:]
            for c in self.calls {
                map[c.id] = c
            }
            for sc in serverCalls {
                map[sc.id] = sc
            }
            var merged = Array(map.values)
            merged.sort { ($0.createdAt ?? 0) > ($1.createdAt ?? 0) }
            self.calls = merged
            self.saveToStorage()
        }
        
        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }
    
    func deleteCall(id: Int) {
        let updateBlock = {
            self.calls.removeAll(where: { $0.id == id })
            self.saveToStorage()
        }
        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }
    
    func clearAll() {
        let updateBlock = {
            self.calls.removeAll()
            UserDefaults.standard.removeObject(forKey: self.storageKey)
        }
        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async(execute: updateBlock)
        }
    }
    
    func recentCalls(limit: Int = 5) -> [CallRecord] {
        return Array(self.calls.prefix(limit))
    }
}
