import AppKit
import SwiftUI

/// Shared fixed navigation used by Settings and the six-tool workbench.
/// The material covers both the search field and the list, including their spacing.
struct NativeSidebar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0, content: content)
            .frame(width: 224)
            .background(SidebarMaterialBackground())
    }
}

struct SidebarMaterialBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

struct EditorSurface: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: contrast == .increased ? 1.5 : 0.5)
                    .allowsHitTesting(false)
            }
    }
}

struct SidebarSearchEmptyState: View {
    let clear: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.title2)
            Text("没有搜索结果").font(.headline)
            Text("尝试其他关键词。")
                .foregroundStyle(.secondary)
            Button("清除搜索", action: clear)
        }
        .multilineTextAlignment(.center)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// One write path for tool controls; format changes also update an enabled snapshot.
extension AppModel {
    func toolPreference<Value>(_ path: WritableKeyPath<ToolboxPreferences, Value>) -> Binding<Value> {
        Binding(get: { self.data.toolboxPreferences[keyPath: path] }, set: { value in
            var preferences = self.data.toolboxPreferences
            preferences[keyPath: path] = value
            self.updateToolboxPreferences(preferences)
            Task { await self.toolbox.persistNow() }
        })
    }
}
