import Foundation

enum PopupPhase {
    case loading
    case result(String)
    case error(String)
}

final class PopupState: ObservableObject {
    @Published var selectedModeId: UUID?
    @Published var modePhases: [UUID: PopupPhase] = [:]

    var modes: [RewriteMode]
    var onModeSelected: ((RewriteMode) -> Void)?
    var onReplace: ((String) -> Void)?
    var onCopy: ((String) -> Void)?
    var onCancel: (() -> Void)?

    init(modes: [RewriteMode]) {
        self.modes = modes
    }

    var currentPhase: PopupPhase {
        guard let id = selectedModeId else { return .loading }
        return modePhases[id] ?? .loading
    }
}
