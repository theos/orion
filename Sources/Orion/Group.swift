import Foundation

/// A marker type which allows grouping and deferring the
/// initialization of hooks.
///
/// # Declaring a Group
///
/// In order to create a group, simply declare a type (usually a `struct`)
/// which conforms to `HookGroup`.
///
/// Hooks are assigned to groups by setting the `AnyHook.Group` associatedtype
/// to the desired group (usually using a `typealias`; see the example below).
/// Every hook belongs to exactly one group. By default, all hooks are part
/// of `DefaultGroup`.
///
/// # Activating a Group
///
/// When a group is _activated_, it refers to the enabling of all of the
/// hooks in that group. A group can be activated at most once.
///
/// The group `DefaultGroup` is automatically activated during Orion's
/// initialization sequence. Custom groups, on the other hand, are **not**
/// activated automatically. You may choose to activate a custom group
/// whatever you like (but at most once), or choose to not activate it at all.
///
/// In order to activate a group, create a new instance of the group's type,
/// and call `activate()` on it. Orion will then enable all of the hooks
/// assigned to that group. The instance on which you called `activate()`
/// will be saved by Orion and will become accessible to the group's hooks via
/// the `AnyHook.group` accessor. This means that you can add properties to
/// your group's type which can effectively be used as "arguments" that are
/// passed during activation.
///
/// # Example
///
/// The following is a snippet of a tweak which activates `NewStuff` on
/// iOS 14 or higher, and `OldStuff` on older iOS versions. In the former
/// case, a boolean argument is passed to indicate whether the device has
/// a notch. The class names used in this tweak are for demonstrative
/// purposes only; there's no guarantee that classes with these names actually
/// exist.
///
/// ```
/// struct iOS14Stuff: HookGroup {
///     let hasNotch: Bool
/// }
///
/// struct iOS13Stuff: HookGroup {}
///
/// class CallBarHook: ClassHook<UIView> {
///     typealias Group = iOS14Stuff
///     static let targetName = "SBCallBarView"
///     // ...
/// }
///
/// class AppLibraryHook: ClassHook<UIView> {
///     typealias Group = iOS14Stuff
///     static let targetName =
///         group.hasNotch ? "SBModernAppLibraryView" : "SBAppLibraryView"
///     // ...
/// }
///
/// class CallScreenHook: ClassHook<UIView> {
///     typealias Group = iOS13Stuff
///     static let targetName = "SBCallScreenView"
///     // ...
/// }
///
/// struct MyTweak: Tweak {
///     init() {
///         if #available(iOS 14, *) {
///             let hasNotch = // ...
///             iOS14Stuff(hasNotch: hasNotch).activate()
///         } else {
///             iOS13Stuff().activate()
///         }
///     }
/// }
/// ```
public protocol HookGroup {
    /// Called after all of the hooks in the group have been activated.
    ///
    /// A default implementation is provided, which does nothing.
    func groupDidActivate()
}

/// :nodoc:
extension HookGroup {
    public func groupDidActivate() {}

    fileprivate static var id: ObjectIdentifier {
        ObjectIdentifier(self)
    }
}

/// The default group which hooks are assigned to. Hooks which belong
/// to this group are automatically activated during Orion's standard
/// initialization process.
///
/// Orion activates hooks assigned to this group after calling
/// `Tweak.init()` but prior to calling `Tweak.tweakDidActivate()`.
///
/// - See: `HookGroup`
public struct DefaultGroup: HookGroup {}

// shared throughout a process in binary framework mode, so we
// have to consider the possibility of multiple tweaks using
// Orion simultaneously
class GroupRegistry {
    private enum GroupState {
        // we're not really using `tweak` atm but it could be useful in the
        // future, for example if we decide to allow handling errors for groups
        case pendingActivation(_ tweak: Tweak.Type?, _ activate: () -> Void)
        case activated(_ tweak: Tweak.Type?, _ group: HookGroup)
    }

    private let groupsLock = ReadWriteLock()
    private var groups: [ObjectIdentifier: GroupState] = [
        DefaultGroup.id: .activated(nil, DefaultGroup())
    ]

    static let shared = GroupRegistry()
    private init() {}

    // returns default hooks which should be activated immediately
    func register(_ hooks: [_GlueAnyHook.Type], tweak: Tweak.Type, backend: Backend) -> [_GlueAnyHook.Type] {
        var newGroups = Dictionary(grouping: hooks) { $0.groupType.id }
        let defaultHooks = newGroups.removeValue(forKey: DefaultGroup.id)
        if !newGroups.isEmpty {
            groupsLock.withWriteLock {
                for (groupID, hooks) in newGroups {
                    switch groups[groupID] {
                    case nil:
                        groups[groupID] = .pendingActivation(tweak) {
                            backend.activate(hooks: hooks, in: tweak)
                        }
                    case .pendingActivation:
                        orionError("Group \(hooks[0].groupType) has already been registered")
                    case .activated:
                        orionError("Group \(hooks[0].groupType) has already been activated")
                    }
                }
            }
        }
        return defaultHooks ?? []
    }

    func activate<T: HookGroup>(_ group: T) {
        let groupID = T.id
        // no point in using a read lock first since any non-failure case
        // will always require promoting to a write lock
        // swiftlint:disable:next unneeded_parentheses_in_closure_argument
        let activation = groupsLock.withWriteLock { () -> (() -> Void)? in
            switch groups[groupID] {
            case nil:
                // assuming all else has gone well, this means the group isn't
                // associated with any hooks. Return an empty activation block
                // but make sure to mark the group as activated to preserve
                // the correct semantics (isActive, double-activation being
                // an error, etc)
                groups[groupID] = .activated(nil, group)
                return nil
            case let .pendingActivation(tweak, activation):
                groups[groupID] = .activated(tweak, group)
                return activation
            case .activated:
                orionError("Group '\(T.self)' has already been activated")
            }
        }
        activation?()
        group.groupDidActivate()
    }

    func group<T: HookGroup>(ofType _: T.Type) -> T {
        let groupID = T.id
        return groupsLock.withReadLock { () -> T in
            switch groups[groupID] {
            case nil:
                orionError("Group '\(T.self)' has not been registered with Orion")
            case .pendingActivation:
                orionError("Group '\(T.self)' has not been activated")
            case .activated(_, let group as T):
                return group
            case .activated(_, let group):
                orionError("Expected to find group of type '\(T.self)' but found '\(type(of: group))'")
            }
        }
    }

    func isGroupActive<T: HookGroup>(ofType _: T.Type) -> Bool {
        let groupID = T.id
        return groupsLock.withReadLock {
            switch groups[groupID] {
            case nil, .pendingActivation:
                return false
            case .activated:
                return true
            }
        }
    }
}

extension HookGroup {
    /// Whether or not the group has been activated (by calling
    /// `activate()` on an instance of it) yet.
    public static var isActive: Bool {
        GroupRegistry.shared.isGroupActive(ofType: self)
    }

    /// Activates the group, enabling all hooks assigned to it.
    ///
    /// The instance on which this method is called will be saved and can
    /// henceforth be retrieved via the `AnyHook.group` property on any hook
    /// assigned to this group.
    ///
    /// - Warning: For any particular group type, this method can be called
    /// at most once.
    ///
    /// - See: `HookGroup` for more info on group activation.
    public func activate() {
        GroupRegistry.shared.activate(self)
    }
}

/// :nodoc:
extension AnyHook {
    static func loadGroup() -> Group {
        GroupRegistry.shared.group(ofType: Group.self)
    }
}
