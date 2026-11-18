import Foundation
import IOKit

/// Avisa quando um DualSense (054c:0ce6) ou DualSense Edge (054c:0df2) é ligado ou desligado na USB.
/// Usa notificações do IOKit: não precisa de permissão e não fica fazendo polling.
final class USBWatcher {
    private var port: IONotificationPortRef?
    private var iterators: [io_iterator_t] = []
    private var started = false
    private var onAdded: () -> Void = {}
    private var onRemoved: () -> Void = {}

    func start(onAdded: @escaping () -> Void, onRemoved: @escaping () -> Void) {
        guard !started else { return }
        started = true
        self.onAdded = onAdded
        self.onRemoved = onRemoved

        port = IONotificationPortCreate(kIOMainPortDefault)
        guard let port else { return }
        let source = IONotificationPortGetRunLoopSource(port).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        let me = Unmanaged.passUnretained(self).toOpaque()

        let added: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon).takeUnretainedValue()
            if USBWatcher.drain(iterator) { watcher.onAdded() }
        }
        let removed: IOServiceMatchingCallback = { refcon, iterator in
            guard let refcon else { return }
            let watcher = Unmanaged<USBWatcher>.fromOpaque(refcon).takeUnretainedValue()
            if USBWatcher.drain(iterator) { watcher.onRemoved() }
        }

        for pid in [0x0ce6, 0x0df2] {
            for (type, callback) in [(kIOFirstMatchNotification, added),
                                     (kIOTerminatedNotification, removed)] {
                guard let dict = IOServiceMatching("IOUSBHostDevice") else { continue }
                let match = dict as NSMutableDictionary
                match["idVendor"] = NSNumber(value: 0x054c)
                match["idProduct"] = NSNumber(value: pid)
                // IOServiceAddMatchingNotification consome uma referência do dicionário.
                _ = Unmanaged.passUnretained(dict).retain()

                var iterator: io_iterator_t = 0
                let result = IOServiceAddMatchingNotification(port, type, dict, callback, me, &iterator)
                if result == KERN_SUCCESS {
                    iterators.append(iterator)
                    _ = USBWatcher.drain(iterator) // "arma" a notificação
                }
            }
        }
    }

    /// Esvazia o iterador; devolve true se havia algum dispositivo.
    private static func drain(_ iterator: io_iterator_t) -> Bool {
        var found = false
        var object = IOIteratorNext(iterator)
        while object != 0 {
            IOObjectRelease(object)
            found = true
            object = IOIteratorNext(iterator)
        }
        return found
    }
}
