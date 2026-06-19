import SwiftUI

/// A removable chip representing a file or folder dropped onto the composer. Shown separately
/// from the typed prompt text so attachments don't clutter what the user is reading/editing.
struct AttachmentChip: View {
    let url: URL
    let onRemove: () -> Void

    private var isDirectory: Bool {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        return isDir.boolValue
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: isDirectory ? "folder.fill" : "doc.fill")
                .font(.caption2)
                .foregroundStyle(WhaleTheme.Color.secondary)
            Text(url.lastPathComponent)
                .font(WhaleTheme.Typography.caption())
                .foregroundStyle(WhaleTheme.Color.text)
                .lineLimit(1)
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(WhaleTheme.Color.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(WhaleTheme.Color.secondary.opacity(0.12))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(WhaleTheme.Color.border, lineWidth: 1))
        .help(url.path)
    }
}
