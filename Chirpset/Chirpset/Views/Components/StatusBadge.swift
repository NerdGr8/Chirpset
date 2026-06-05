import SwiftUI

struct StatusBadge: View {
    let status: DeviceStatus
    var body: some View {
        Text(status.label)
            .font(Theme.body(10, weight: .semibold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
    }
}
