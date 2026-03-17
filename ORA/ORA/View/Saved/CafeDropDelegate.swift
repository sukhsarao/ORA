import SwiftUI

/// A `DropDelegate` responsible for handling in-grid reordering of `Cafe` items during drag-and-drop.
///
/// Example usage:
/// ```swift
/// .onDrop(of: [.text], delegate: CafeDropDelegate(item: cafe, list: $cafes, dragging: $draggingCafe))
/// ```
struct CafeDropDelegate: DropDelegate {
    /// The current item being hovered over during a drop operation.
    let item: Cafe

    /// The list of cafes being reordered.
    @Binding var list: [Cafe]

    /// The cafe item currently being dragged.
    @Binding var dragging: Cafe?

    /// Called when a drag item enters the drop target’s area.
    /// Reorders the list visually by swapping the dragged and target items.
    func dropEntered(info: DropInfo) {
        guard let dragging,
              dragging.id != item.id,
              let from = list.firstIndex(where: { $0.id == dragging.id }),
              let to   = list.firstIndex(where: { $0.id == item.id })
        else { return }

        // Animate the reorder for a smooth visual transition.
        withAnimation(.easeInOut(duration: 0.15)) {
            let moved = list.remove(at: from)
            list.insert(moved, at: to)
        }
    }

    /// Informs the system that this delegate supports item movement during the drop.
    func dropUpdated(info: DropInfo) -> DropProposal? {
        .init(operation: .move)
    }

    /// Finalizes the drop operation and clears the dragging reference.
    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
