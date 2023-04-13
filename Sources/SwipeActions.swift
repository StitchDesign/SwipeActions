/*

 SwipeActions.swift
 SwipeActions

 Created by A. Zheng (github.com/aheze) on 4/12/23.
 Copyright © 2023 A. Zheng. All rights reserved.

 MIT License

 Copyright (c) 2023 A. Zheng

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

import SwiftUI

// MARK: - Structures

/// The swipe gesture's current state.
public enum SwipeState {
    /// The default state.
    case closed

    /// All actions are shown.
    case expanded

    /// The last action is highlighted. Only applies if `swipeToTriggerLeadingEdge` / `swipeToTriggerTrailingEdge` are true.
    case triggering

    /// The last action is highlighted and fills the whole row. Only applies if `swipeToTriggerLeadingEdge` / `swipeToTriggerTrailingEdge` are true.
    case triggered
}

/// Either `leading` or `trailing`.
public enum SwipeSide {
    case leading
    case trailing

    /// When leading actions are shown, the offset is positive. It's the opposite for trailing actions.
    var signWhenDragged: Int {
        switch self {
        case .leading:
            return 1
        case .trailing:
            return -1
        }
    }

    /// Convert to `SwiftUI`'s `Alignment` struct.
    var alignment: Alignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }

    /// Used when there's only one action.
    var edgeTriggerAlignment: Alignment {
        switch self {
        case .leading:
            return .trailing
        case .trailing:
            return .leading
        }
    }
}

/// Context for the swipe action.
public struct SwipeContext {
    /// The current state.
    public var state: SwipeState?

    /// How many actions are provided.
    public var numberOfActions = 0

    /// The side that this context applies to.
    public var side: SwipeSide

    /// The opacity of the swipe actions, determined by `actionsVisibleStartPoint` and `actionsVisibleEndPoint`.
    public var opacity = Double(0)
}

/// The style to reveal actions.
public enum SwipeActionStyle {
    /// Fully render actions, but reveal them using a mask.
    case mask

    /// All actions have equal widths, taking up all available space together.
    case equalWidths

    /// A "overlapping" style.
    case cascade
}

/// Options for configuring the swipe view.
public struct SwipeOptions {
    /// Enable triggering the leading edge via a drag.
    var swipeToTriggerLeadingEdge = false

    /// Enable triggering the trailing edge via a drag.
    var swipeToTriggerTrailingEdge = false

    /// The minimum distance needed to drag to start the gesture. Should be more than 0 for best compatibility with other gestures/buttons.
    var swipeMinimumDistance = Double(2)

    /// The style to use (`mask`, `equalWidths`, or `cascade`).
    var actionsStyle = SwipeActionStyle.mask

    /// The corner radius that encompasses all actions.
    var actionsMaskCornerRadius = Double(20)

    /// At what point the actions start becoming visible.
    var actionsVisibleStartPoint = Double(50)

    /// At what point the actions become fully visible.
    var actionsVisibleEndPoint = Double(100)

    /// The corner radius for each action.
    var actionCornerRadius = Double(32)

    /// The width for each action.
    var actionWidth = Double(100)

    /// Spacing between actions and the label view.
    var spacing = Double(8)

    /// The point where the user must drag to expand actions.
    var readyToExpandPadding = Double(50)

    /// The point where the user must drag to enter the `triggering` state.
    var readyToTriggerPadding = Double(20)

    /// Ensure that the user must drag a significant amount to trigger the edge action, even if the actions' total width is small.
    var minimumPointToTrigger = Double(200)

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is true.
    var enableTriggerHaptics = true

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is false, or when there's no actions on one side.
    var stretchRubberBandingPower = Double(0.7)

    /// If true, you can change from the leading to the trailing actions in one single swipe.
    var allowSingleSwipeAcross = false

    /// The animation used for adjusting the content's view when it's triggered.
    var actionContentTriggerAnimation = Animation.spring(response: 0.2, dampingFraction: 1, blendDuration: 1)

    /// Values for controlling the close animation.
    var offsetCloseAnimationStiffness = Double(160), offsetCloseAnimationDamping = Double(70)

    /// Values for controlling the expand animation.
    var offsetExpandAnimationStiffness = Double(160), offsetExpandAnimationDamping = Double(70)

    /// Values for controlling the trigger animation.
    var offsetTriggerAnimationStiffness = Double(160), offsetTriggerAnimationDamping = Double(70)
}

// MARK: - Environment

public struct SwipeContextKey: EnvironmentKey {
    public static let defaultValue = SwipeContext(side: .leading)
}

public extension EnvironmentValues {
    var swipeContext: SwipeContext {
        get { self[SwipeContextKey.self] }
        set { self[SwipeContextKey.self] = newValue }
    }
}

// MARK: - Action view

/// A view to wrap buttons in, for use in either the `leading` or `trailing` side.
public struct SwipeAction<Label: View, Background: View>: View {
    // MARK: - Properties

    /// For trigger-by-drag.
    public var isSwipeEdge = false

    /// Constrain the action's content size (helpful for text).
    public var labelFixedSize = true

    /// Additional horizontal padding.
    public var labelHorizontalPadding = Double(16)

    /// Whether to ramp the opacity of the entire view or just the label.
    public var changeLabelVisibilityOnly = false

    /// Code to run when the action triggers.
    public var action: () -> Void

    /// The parameter indicates if it's highlighted or not.
    public var label: (Bool) -> Label

    /// The background of the swipe action.
    public var background: (Bool) -> Background

    // MARK: - Internal state

    @Environment(\.swipeContext) var swipeContext

    @State var highlighted = false

    public init(
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping (Bool) -> Label,
        @ViewBuilder background: @escaping (Bool) -> Background
    ) {
        self.action = action
        self.label = label
        self.background = background
    }

    public var body: some View {
        let alignment: Alignment = {
            guard isSwipeEdge else { return .center }
            if swipeContext.numberOfActions == 1 {
                if swipeContext.state == .triggering || swipeContext.state == .triggered {
                    return swipeContext.side.edgeTriggerAlignment
                }
            }
            return .center
        }()

        let (totalOpacity, labelOpacity): (Double, Double) = {
            if changeLabelVisibilityOnly {
                return (1, swipeContext.opacity)
            } else {
                return (swipeContext.opacity, 1)
            }
        }()

        Button(action: action) {
            background(highlighted)
                .overlay(
                    label(highlighted)
                        .opacity(labelOpacity)
                        .fixedSize(horizontal: labelFixedSize, vertical: labelFixedSize)
                        .padding(.horizontal, labelHorizontalPadding),
                    alignment: alignment
                )
        }
        .opacity(totalOpacity)
        ._onButtonGesture { pressing in
            self.highlighted = pressing
        } perform: {}
        .buttonStyle(SwipeActionButtonStyle())
        .onChange(of: swipeContext.state) { state in
            guard isSwipeEdge else { return }
            if let state {
                if state == .triggering || state == .triggered {
                    highlighted = true
                } else {
                    highlighted = false
                }

                if state == .triggered {
                    action()
                }
            } else {
                highlighted = false
            }
        }
    }
}

// MARK: - Main view

/**
 A view for adding swipe actions.
 */
public struct SwipeView<Label, LeadingActions, TrailingActions>: View where Label: View, LeadingActions: View, TrailingActions: View {
    // MARK: - Properties

    public var options = SwipeOptions()
    @ViewBuilder public var label: () -> Label
    @ViewBuilder public var leadingActions: (Binding<SwipeContext>) -> LeadingActions
    @ViewBuilder public var trailingActions: (Binding<SwipeContext>) -> TrailingActions

    // MARK: - Internal state

    @State var currentSide: SwipeSide?
    @State var leadingState: SwipeState?
    @State var trailingState: SwipeState?
    @State var numberOfLeadingActions = 0
    @State var numberOfTrailingActions = 0

    /// When you touch down with a second finger, the drag gesture freezes, but `currentlyDragging` will be accurate.
    @GestureState var currentlyDragging = false

    /// Upon a gesture freeze / cancellation, use this to end the gesture.
    @State var latestDragGestureValueBackup: DragGesture.Value?

    /// The gesture's current velocity.
    @GestureVelocity var velocity: CGVector
    @State var currentOffset = Double(0)
    @State var savedOffset = Double(0)
    @State var size = CGSize.zero

    public init(
        @ViewBuilder label: @escaping () -> Label,
        @ViewBuilder leadingActions: @escaping (Binding<SwipeContext>) -> LeadingActions,
        @ViewBuilder trailingActions: @escaping (Binding<SwipeContext>) -> TrailingActions
    ) {
        self.label = label
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
    }

    public var body: some View {
        HStack {
            label()
                .offset(x: offset)
        }
        .readSize { size = $0 }
        .background(
            actionsView(side: .leading, state: $leadingState, numberOfActions: $numberOfLeadingActions) { context in
                leadingActions(context)
                    .environment(\.swipeContext, context.wrappedValue)
            },
            alignment: .leading
        )
        .background(
            actionsView(side: .trailing, state: $trailingState, numberOfActions: $numberOfTrailingActions) { context in
                trailingActions(context)
                    .environment(\.swipeContext, context.wrappedValue)
            },
            alignment: .trailing
        )
        .highPriorityGesture(
            DragGesture(minimumDistance: options.swipeMinimumDistance)
                .updating($currentlyDragging) { value, state, transaction in
                    state = true
                }
                .onChanged(onChanged)
                .onEnded(onEnded)
                .updatingVelocity($velocity)
        )
        .onChange(of: currentlyDragging) { currentlyDragging in
            if !currentlyDragging, let latestDragGestureValueBackup {
                /// Gesture cancelled.

                let velocity = velocity.dx / currentOffset
                end(value: latestDragGestureValueBackup, velocity: velocity)
            }
        }

        .onChange(of: leadingState) { [leadingState] newValue in
            /// Make sure the change was from `triggering` to `nil`, or the other way around.
            let changed =
                leadingState == .triggering && newValue == nil ||
                leadingState == nil && newValue == .triggering

            if changed, options.enableTriggerHaptics {
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred()
            }
        }
        .onChange(of: trailingState) { [trailingState] newValue in

            let changed =
                trailingState == .triggering && newValue == nil ||
                trailingState == nil && newValue == .triggering

            if changed, options.enableTriggerHaptics {
                let generator = UIImpactFeedbackGenerator(style: .rigid)
                generator.impactOccurred()
            }
        }
    }
}

// MARK: - Actions view

extension SwipeView {
    @ViewBuilder func actionsView<Actions: View>(
        side: SwipeSide,
        state: Binding<SwipeState?>,
        numberOfActions: Binding<Int>,
        @ViewBuilder actions: (Binding<SwipeContext>) -> Actions
    ) -> some View {
        let draggedLength = offset * Double(side.signWhenDragged) /// Flip the offset if necessary.
        let visibleWidth: Double = {
            var width = draggedLength
            width -= options.spacing /// Minus the side spacing.
            width = max(0, width) /// Prevent from becoming negative.
            return width
        }()

        let opacity: Double = {
            /// Subtract the start point from the dragged length, which cancels it out initially.
            let offset = max(0, draggedLength - options.actionsVisibleStartPoint)

            /// Calculate the opacity percent.
            let percent = offset / (options.actionsVisibleEndPoint - options.actionsVisibleStartPoint)

            /// Make sure the opacity doesn't exceed 1.
            let opacity = min(1, percent)

            return opacity
        }()

        _VariadicView.Tree(
            SwipeActionsLayout(
                numberOfActions: numberOfActions,
                side: side,
                options: options,
                state: state.wrappedValue,
                visibleWidth: visibleWidth
            )
        ) {
            let context = Binding {
                SwipeContext(
                    state: state.wrappedValue,
                    numberOfActions: numberOfActions.wrappedValue,
                    side: side,
                    opacity: opacity
                )
            } set: { newValue in
                state.wrappedValue = newValue.state
                currentSide = side
                update(side: side, to: newValue.state)
            }

            actions(context)
        }
        .mask(
            Color.clear.overlay(
                /// Make the mask's corner radius a bit smaller.
                RoundedRectangle(cornerRadius: options.actionsMaskCornerRadius / 2, style: .continuous)
                    .frame(width: visibleWidth),
                alignment: side.alignment
            )
        )
    }
}

// MARK: - Actions Layout

struct SwipeActionsLayout: _VariadicView_UnaryViewRoot {
    @Binding var numberOfActions: Int
    var side: SwipeSide
    var options: SwipeOptions
    var state: SwipeState?
    var visibleWidth: Double

    @ViewBuilder
    public func body(children: _VariadicView.Children) -> some View {
        let edge: AnyHashable? = {
            switch side {
            case .leading:
                return children.first?.id
            case .trailing:
                return children.last?.id
            }
        }()

        HStack(spacing: options.spacing) {
            ForEach(Array(zip(children.indices, children)), id: \.1.id) { index, child in
                let isEdge = child.id == edge

                let shown: Bool = {
                    if state == .triggering || state == .triggered {
                        if !isEdge {
                            return false
                        }
                    }

                    return true
                }()

                let width: CGFloat? = {
                    if state == .triggering || state == .triggered {
                        if isEdge {
                            return visibleWidth
                        } else {
                            return 0
                        }
                    }

                    /**
                     Use this when rubber banding (the actions should stretch a bit).

                     Also applies when `options.actionsStyle` is `.equalWidths`.
                     */
                    let evenlyDistributedActionWidth: Double = {
                        if numberOfActions > 0 {
                            let visibleWidthWithoutSpacing = visibleWidth - options.spacing * Double(numberOfActions - 1)
                            let evenlyDistributedActionWidth = visibleWidthWithoutSpacing / Double(numberOfActions)
                            return evenlyDistributedActionWidth
                        } else {
                            return options.actionWidth /// At first `numberOfTrailingActions` is 0, so just return `options.actionWidth`.
                        }
                    }()

                    switch options.actionsStyle {
                    case .mask:
                        return max(evenlyDistributedActionWidth, options.actionWidth)
                    case .equalWidths:
                        return evenlyDistributedActionWidth
                    case .cascade:
                        return max(evenlyDistributedActionWidth, options.actionWidth)
                    }
                }()

                if options.actionsStyle == .cascade {
                    /// Overlapping views require a `zIndex`.
                    let zIndex: Int = {
                        switch side {
                        case .leading:
                            return children.count - index - 1 /// Left-most views should be on top.
                        case .trailing:
                            return index
                        }
                    }()

                    Color.clear.overlay(
                        child
                            .frame(maxHeight: .infinity)
                            .frame(width: width)
                            .opacity(shown ? 1 : 0)
                            .mask(
                                RoundedRectangle(cornerRadius: options.actionCornerRadius, style: .continuous)
                            ),
                        alignment: side.edgeTriggerAlignment
                    )
                    .zIndex(Double(zIndex))
                } else {
                    child
                        .frame(maxHeight: .infinity)
                        .frame(width: width)
                        .opacity(shown ? 1 : 0)
                        .mask(
                            RoundedRectangle(cornerRadius: options.actionCornerRadius, style: .continuous)
                        )
                }
            }
        }
        .frame(width: options.actionsStyle == .cascade ? visibleWidth : nil)
        .animation(options.actionContentTriggerAnimation, value: state)
        .onAppear {
            numberOfActions = children.count
        }
        .onChange(of: children.count) { count in
            numberOfActions = count
        }
    }
}

// MARK: - Calculated values

extension SwipeView {
    /// The total offset of the content.
    var offset: Double {
        currentOffset + savedOffset
    }

    /// Calculate the total width for actions.
    func actionsWidth(numberOfActions: Int) -> Double {
        let count = Double(numberOfActions)
        let totalWidth = count * options.actionWidth
        let totalSpacing = (count - 1) * options.spacing
        let actionsWidth = totalWidth + totalSpacing

        return actionsWidth
    }

    /// If `allowSwipeAcross` is disabled, make sure the user can't swipe from one side to the other in a single swipe.
    func getDisallowedSide(totalOffset: Double) -> SwipeSide? {
        guard !options.allowSingleSwipeAcross else { return nil }
        if let currentSide {
            switch currentSide {
            case .leading:
                if totalOffset < 0 {
                    /// Disallow showing trailing actions.
                    return .trailing
                }
            case .trailing:
                if totalOffset > 0 {
                    /// Disallow showing leading actions.
                    return .leading
                }
            }
        }
        return nil
    }

    // MARK: - Trailing

    var trailingReadyToExpandOffset: Double {
        -options.readyToExpandPadding
    }

    var trailingExpandedOffset: Double {
        let expandedOffset = -(actionsWidth(numberOfActions: numberOfTrailingActions) + options.spacing)
        return expandedOffset
    }

    var trailingReadyToTriggerOffset: Double {
        var readyToTriggerOffset = trailingExpandedOffset - options.readyToTriggerPadding
        let minimumOffsetToTrigger = -options.minimumPointToTrigger /// Sometimes if there's only one action, the trigger drag distance is too small. This makes sure it's big enough.
        if readyToTriggerOffset > minimumOffsetToTrigger {
            readyToTriggerOffset = minimumOffsetToTrigger
        }
        return readyToTriggerOffset
    }

    var trailingTriggeredOffset: Double {
        let triggeredOffset = -(size.width + options.spacing)
        return triggeredOffset
    }

    // MARK: - Leading

    var leadingReadyToExpandOffset: Double {
        options.readyToExpandPadding
    }

    var leadingExpandedOffset: Double {
        let expandedOffset = actionsWidth(numberOfActions: numberOfLeadingActions) + options.spacing
        return expandedOffset
    }

    var leadingReadyToTriggerOffset: Double {
        var readyToTriggerOffset = leadingExpandedOffset + options.readyToTriggerPadding
        let minimumOffsetToTrigger = options.minimumPointToTrigger

        if readyToTriggerOffset < minimumOffsetToTrigger {
            readyToTriggerOffset = minimumOffsetToTrigger
        }
        return readyToTriggerOffset
    }

    var leadingTriggeredOffset: Double {
        let triggeredOffset = size.width + options.spacing
        return triggeredOffset
    }
}

// MARK: - State

extension SwipeView {
    /// For programmatically setting the state.
    func update(side: SwipeSide, to state: SwipeState?) {
        guard let state else { return }
        switch state {
        case .closed:
            close(velocity: 0)
        case .expanded:
            expand(side: side, velocity: 0)
        case .triggering:
            break
        case .triggered:
            trigger(side: side, velocity: 0)
        }
    }

    func close(velocity: Double) {
        withAnimation(.interpolatingSpring(stiffness: options.offsetTriggerAnimationStiffness, damping: options.offsetTriggerAnimationDamping, initialVelocity: velocity)) {
            savedOffset = 0
            currentOffset = 0
        }
    }

    func trigger(side: SwipeSide, velocity: Double) {
        withAnimation(.interpolatingSpring(stiffness: options.offsetTriggerAnimationStiffness, damping: options.offsetTriggerAnimationDamping, initialVelocity: velocity)) {
            switch side {
            case .leading:
                savedOffset = leadingTriggeredOffset
            case .trailing:
                savedOffset = trailingTriggeredOffset
            }
            currentOffset = 0
        }
    }

    func expand(side: SwipeSide, velocity: Double) {
        withAnimation(.interpolatingSpring(stiffness: options.offsetExpandAnimationStiffness, damping: options.offsetExpandAnimationDamping, initialVelocity: velocity)) {
            switch side {
            case .leading:
                savedOffset = leadingExpandedOffset
            case .trailing:
                savedOffset = trailingExpandedOffset
            }
            currentOffset = 0
        }
    }
}

// MARK: - Gestures

extension SwipeView {
    func onChanged(value: DragGesture.Value) {
        /// Backup the value.
        latestDragGestureValueBackup = value

        /// Set the current side.
        if currentSide == nil {
            let dx = value.location.x - value.startLocation.x
            if dx > 0 {
                currentSide = .leading
            } else {
                currentSide = .trailing
            }
        }

        /// The total offset of the swipe view.
        let totalOffset = savedOffset + value.translation.width

        /// Get the disallowed side if it exists.
        let disallowedSide = getDisallowedSide(totalOffset: totalOffset)

        /// Apply rubber banding if an empty side is reached, or if a side is disallowed.
        if numberOfLeadingActions == 0 || disallowedSide == .leading, totalOffset > 0 {
            let constrainedExceededOffset = pow(totalOffset, options.stretchRubberBandingPower)
            currentOffset = constrainedExceededOffset - savedOffset
            leadingState = nil
            trailingState = nil
        } else if numberOfTrailingActions == 0 || disallowedSide == .trailing, totalOffset < 0 {
            let constrainedExceededOffset = -pow(-totalOffset, options.stretchRubberBandingPower)
            currentOffset = constrainedExceededOffset - savedOffset
            leadingState = nil
            trailingState = nil
        } else { /// Otherwise, attempt to trigger the swipe actions.
            /// Flag to keep track of whether `currentOffset` was set or not — if `false`, then set to the default of `value.translation.width`.
            var setCurrentOffset = false

            if totalOffset > leadingReadyToTriggerOffset {
                setCurrentOffset = true
                if options.swipeToTriggerLeadingEdge {
                    currentOffset = value.translation.width
                    leadingState = .triggering
                    trailingState = nil
                } else {
                    let exceededOffset = totalOffset - leadingReadyToTriggerOffset
                    let constrainedExceededOffset = pow(exceededOffset, options.stretchRubberBandingPower)
                    let constrainedTotalOffset = leadingReadyToTriggerOffset + constrainedExceededOffset
                    currentOffset = constrainedTotalOffset - savedOffset
                    leadingState = nil
                    trailingState = nil
                }
            }

            if totalOffset < trailingReadyToTriggerOffset {
                setCurrentOffset = true
                if options.swipeToTriggerTrailingEdge {
                    currentOffset = value.translation.width
                    trailingState = .triggering
                    leadingState = nil
                } else {
                    let exceededOffset = totalOffset - trailingReadyToTriggerOffset
                    let constrainedExceededOffset = -pow(-exceededOffset, options.stretchRubberBandingPower)
                    let constrainedTotalOffset = trailingReadyToTriggerOffset + constrainedExceededOffset
                    currentOffset = constrainedTotalOffset - savedOffset
                    leadingState = nil
                    trailingState = nil
                }
            }

            /// If the offset wasn't modified already (due to rubber banding), use `value.translation.width` as the default.
            if !setCurrentOffset {
                currentOffset = value.translation.width
                leadingState = nil
                trailingState = nil
            }
        }
    }

    func onEnded(value: DragGesture.Value) {
        latestDragGestureValueBackup = nil
        let velocity = velocity.dx / currentOffset
        end(value: value, velocity: velocity)
    }

    func end(value: DragGesture.Value, velocity: CGFloat) {
        let totalOffset = savedOffset + value.translation.width
        let totalPredictedOffset = (savedOffset + value.predictedEndTranslation.width) * 0.5

        if getDisallowedSide(totalOffset: totalPredictedOffset) != nil {
            currentSide = nil
            leadingState = .closed
            trailingState = .closed
            close(velocity: velocity)
            return
        }

        if trailingState == .triggering {
            trailingState = .triggered
            trigger(side: .trailing, velocity: velocity)
        } else if leadingState == .triggering {
            leadingState = .triggered
            trigger(side: .leading, velocity: velocity)
        } else {
            if totalPredictedOffset > leadingReadyToExpandOffset, numberOfLeadingActions > 0 {
                leadingState = .expanded
                expand(side: .leading, velocity: velocity)
            } else if totalPredictedOffset < trailingReadyToExpandOffset, numberOfTrailingActions > 0 {
                trailingState = .expanded
                expand(side: .trailing, velocity: velocity)
            } else {
                currentSide = nil
                leadingState = .closed
                trailingState = .closed
                let draggedPastTrailingSide = totalOffset > 0
                if draggedPastTrailingSide { /// if the finger is on the right of the view, make the velocity negative to return to closed quicker.
                    close(velocity: velocity * -0.1)
                } else {
                    close(velocity: velocity)
                }
            }
        }
    }
}

// MARK: Convenience views

public extension SwipeAction where Label == Text, Background == Color {
    init(
        _ title: LocalizedStringKey,
        backgroundColor: Color = Color.primary.opacity(0.1),
        highlightOpacity: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.init(action: action) { highlight in
            Text(title)
        } background: { highlight in
            backgroundColor
                .opacity(highlight ? highlightOpacity : 1)
        }
    }
}

public extension SwipeAction where Label == Image, Background == Color {
    init(
        systemImage: String,
        backgroundColor: Color = Color.primary.opacity(0.1),
        highlightOpacity: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.init(action: action) { highlight in
            Image(systemName: systemImage)
        } background: { highlight in
            backgroundColor
                .opacity(highlight ? highlightOpacity : 1)
        }
    }
}

public extension SwipeAction where Label == VStack<TupleView<(ModifiedContent<Image, _EnvironmentKeyWritingModifier<Font?>>, Text)>>, Background == Color {
    init(
        _ title: LocalizedStringKey,
        systemImage: String,
        imageFont: Font? = .title2,
        backgroundColor: Color = Color.primary.opacity(0.1),
        highlightOpacity: Double = 0.5,
        action: @escaping () -> Void
    ) {
        self.init(action: action) { highlight in
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(imageFont) as! ModifiedContent<Image, _EnvironmentKeyWritingModifier<Font?>>

                Text(title)
            }
        } background: { highlight in
            backgroundColor
                .opacity(highlight ? highlightOpacity : 1)
        }
    }
}

public extension SwipeAction {
    /// Apply this the edge action to auto-highlight it.
    func swipeActionEdgeStyling() -> SwipeAction {
        var view = self
        view.isSwipeEdge = true
        return view
    }

    /// Constrain the action's content size (helpful for text).
    func swipeActionLabelFixedSize(_ value: Bool = true) -> SwipeAction {
        var view = self
        view.labelFixedSize = value
        return view
    }

    /// Additional horizontal padding.
    func swipeActionLabelHorizontalPadding(_ value: Double = 16) -> SwipeAction {
        var view = self
        view.labelHorizontalPadding = value
        return view
    }

    /// The opacity of the swipe actions, determined by `actionsVisibleStartPoint` and `actionsVisibleEndPoint`.
    func swipeActionChangeLabelVisibilityOnly(_ value: Bool) -> SwipeAction {
        var view = self
        view.changeLabelVisibilityOnly = value
        return view
    }
}

public extension SwipeView {
    /// Enable triggering the leading edge via a drag.
    func swipeToTriggerLeadingEdge(_ value: Bool) -> SwipeView {
        var view = self
        view.options.swipeToTriggerLeadingEdge = value
        return view
    }

    /// Enable triggering the trailing edge via a drag.
    func swipeToTriggerTrailingEdge(_ value: Bool) -> SwipeView {
        var view = self
        view.options.swipeToTriggerTrailingEdge = value
        return view
    }

    /// The minimum distance needed to drag to start the gesture. Should be more than 0 for best compatibility with other gestures/buttons.
    func swipeMinimumDistance(_ value: Double) -> SwipeView {
        var view = self
        view.options.swipeMinimumDistance = value
        return view
    }

    /// The style to use (`mask`, `equalWidths`, or `cascade`).
    func swipeActionsStyle(_ value: SwipeActionStyle) -> SwipeView {
        var view = self
        view.options.actionsStyle = value
        return view
    }

    /// The corner radius that encompasses all actions.
    func swipeActionsMaskCornerRadius(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionsMaskCornerRadius = value
        return view
    }

    /// At what point the actions start becoming visible.
    func swipeActionsVisibleStartPoint(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionsVisibleStartPoint = value
        return view
    }

    /// At what point the actions become fully visible.
    func swipeActionsVisibleEndPoint(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionsVisibleEndPoint = value
        return view
    }

    /// The corner radius for each action.
    func swipeActionCornerRadius(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionCornerRadius = value
        return view
    }

    /// The width for each action.
    func swipeActionWidth(_ value: Double) -> SwipeView {
        var view = self
        view.options.actionWidth = value
        return view
    }

    /// Spacing between actions and the label view.
    func swipeSpacing(_ value: Double) -> SwipeView {
        var view = self
        view.options.spacing = value
        return view
    }

    /// The point where the user must drag to expand actions.
    func swipeReadyToExpandPadding(_ value: Double) -> SwipeView {
        var view = self
        view.options.readyToExpandPadding = value
        return view
    }

    /// The point where the user must drag to enter the `triggering` state.
    func swipeReadyToTriggerPadding(_ value: Double) -> SwipeView {
        var view = self
        view.options.readyToTriggerPadding = value
        return view
    }

    /// Ensure that the user must drag a significant amount to trigger the edge action, even if the actions' total width is small.
    func swipeMinimumPointToTrigger(_ value: Double) -> SwipeView {
        var view = self
        view.options.minimumPointToTrigger = value
        return view
    }

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is true.
    func swipeEnableTriggerHaptics(_ value: Bool) -> SwipeView {
        var view = self
        view.options.enableTriggerHaptics = value
        return view
    }

    /// Applies if `swipeToTriggerLeadingEdge/swipeToTriggerTrailingEdge` is false, or when there's no actions on one side.
    func swipeStretchRubberBandingPower(_ value: Double) -> SwipeView {
        var view = self
        view.options.stretchRubberBandingPower = value
        return view
    }

    /// If true, you can change from the leading to the trailing actions in one single swipe.
    func swipeAllowSingleSwipeAcross(_ value: Bool) -> SwipeView {
        var view = self
        view.options.allowSingleSwipeAcross = value
        return view
    }

    /// The animation used for adjusting the content's view when it's triggered.
    func swipeActionContentTriggerAnimation(_ value: Animation) -> SwipeView {
        var view = self
        view.options.actionContentTriggerAnimation = value
        return view
    }

    /// Values for controlling the close animation.
    func swipeOffsetCloseAnimation(stiffness: Double, damping: Double) -> SwipeView {
        var view = self
        view.options.offsetCloseAnimationStiffness = stiffness
        view.options.offsetCloseAnimationDamping = damping
        return view
    }

    /// Values for controlling the expand animation.
    func swipeOffsetExpandAnimation(stiffness: Double, damping: Double) -> SwipeView {
        var view = self
        view.options.offsetExpandAnimationStiffness = stiffness
        view.options.offsetExpandAnimationDamping = damping
        return view
    }

    /// Values for controlling the trigger animation.
    func swipeOffsetTriggerAnimation(stiffness: Double, damping: Double) -> SwipeView {
        var view = self
        view.options.offsetTriggerAnimationStiffness = stiffness
        view.options.offsetTriggerAnimationDamping = damping
        return view
    }
}

/// Modifier for a clipped delete transition effect.
public struct SwipeDeleteModifier: ViewModifier {
    var visibility: Double

    public func body(content: Content) -> some View {
        content
            .mask(
                Color.clear.overlay(
                    SwipeDeleteMaskShape(animatableData: visibility),
                    alignment: .top
                )
            )
    }
}

public extension AnyTransition {
    /// Transition that mimics iOS's default delete transition (clipped to the top).
    static var swipeDelete: AnyTransition {
        .modifier(
            active: SwipeDeleteModifier(visibility: 0),
            identity: SwipeDeleteModifier(visibility: 1)
        )
    }
}

/// Custom shape that changes height as `animatableData` changes.
public struct SwipeDeleteMaskShape: Shape {
    public var animatableData: Double

    public func path(in rect: CGRect) -> Path {
        var maskRect = rect
        maskRect.size.height = rect.size.height * animatableData
        return Path(maskRect)
    }
}

// MARK: - Utilities

/// A style to remove the "press" effect on buttons.
public struct SwipeActionButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        return configuration.label
    }
}

/*
 Get the velocity from a drag gesture.

 From https://github.com/FluidGroup/swiftui-GestureVelocity

 MIT License

 Copyright (c) 2022 Hiroshi Kimura

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */
@propertyWrapper
struct GestureVelocity: DynamicProperty {
    @State var previous: DragGesture.Value?
    @State var current: DragGesture.Value?

    func update(_ value: DragGesture.Value) {
        if current != nil {
            previous = current
        }

        current = value
    }

    func reset() {
        previous = nil
        current = nil
    }

    var projectedValue: GestureVelocity {
        return self
    }

    var wrappedValue: CGVector {
        value
    }

    private var value: CGVector {
        guard
            let previous,
            let current
        else {
            return .zero
        }

        let timeDelta = current.time.timeIntervalSince(previous.time)

        let speedY = Double(
            current.translation.height - previous.translation.height
        ) / timeDelta

        let speedX = Double(
            current.translation.width - previous.translation.width
        ) / timeDelta

        return .init(dx: speedX, dy: speedY)
    }
}

extension Gesture where Value == DragGesture.Value {
    func updatingVelocity(_ velocity: GestureVelocity) -> _EndedGesture<_ChangedGesture<Self>> {
        onChanged { value in
            velocity.update(value)
        }
        .onEnded { _ in
            velocity.reset()
        }
    }
}

/**
 Read a view's size. The closure is called whenever the size itself changes.

 From https://stackoverflow.com/a/66822461/14351818
 */
extension View {
    func readSize(size: @escaping (CGSize) -> Void) -> some View {
        return background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: ContentSizeReaderPreferenceKey.self, value: geometry.size)
                    .onPreferenceChange(ContentSizeReaderPreferenceKey.self) { newValue in
                        DispatchQueue.main.async {
                            size(newValue)
                        }
                    }
            }
            .hidden()
        )
    }
}

struct ContentSizeReaderPreferenceKey: PreferenceKey {
    static var defaultValue: CGSize { return CGSize() }
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}
