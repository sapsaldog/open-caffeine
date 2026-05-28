import KeyboardShortcuts
import SwiftUI

struct HotKeyRecorderRow: View {
    var body: some View {
        HStack {
            Text("Activate with hot key:")
            Spacer()
            KeyboardShortcuts.Recorder(for: .toggleCaffeine)
        }
    }
}
