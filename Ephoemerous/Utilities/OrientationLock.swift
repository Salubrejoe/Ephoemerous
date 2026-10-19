import UIKit

// MARK: - OrientationLock
// Which ways the interface may turn, decided per window. The Info.plist
// offers iPhone portrait and both landscapes (`~iphone`) — the most any
// iPhone window may take — and this narrows it, because the plist can only
// split iPhone from iPad and iPhone Duo is an iPhone that turns:
//   iPad, and any regular-width window   every way
//     (the Duo's inner display)
//   the closed Duo, whose system keeps   portrait and both landscapes
//     a side rail
//   every other iPhone                   portrait, as it always has been
final class OrientationLock: NSObject, UIApplicationDelegate {

    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        guard let traits = window?.traitCollection else { return .portrait }
        if traits.userInterfaceIdiom != .phone      { return .all }
        if traits.horizontalSizeClass == .regular   { return .all }
        if Self.hasSideRail(traits)                 { return .allButUpsideDown }
        return .portrait
    }

    /// Ask every window to read its orientations again — when the rail
    /// arrives or leaves (the Duo closing onto its outer display), what the
    /// window may do has changed, and UIKit keeps the answer it read first.
    @MainActor
    static func refresh() {
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            for window in scene.windows {
                window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
        }
    }

    /// The system places a vertical bar here — iPhone Duo's outer display.
    private static func hasSideRail(_ traits: UITraitCollection) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        return traits.verticalBarEdge != .unspecified
    }
}

#if DEBUG
// MARK: - Screenshot seeding
extension OrientationLock {
    /// `-landscape left|right` turns the window into that landscape at
    /// launch — the simulator can't rotate the Duo from the command line.
    /// `left` is UIKit's landscape-left: the home side on the left.
    @MainActor
    static func seedLandscape() async {
        // After the window has asked `supportedInterfaceOrientationsFor`
        // once — a request before that is checked against the plist alone.
        try? await Task.sleep(for: .seconds(1))
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-landscape"), i + 1 < args.count else { return }
        let mask: UIInterfaceOrientationMask = args[i + 1] == "left" ? .landscapeLeft : .landscapeRight
        refresh()
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                MemoryLog.note("landscape: \(error.localizedDescription)")
            }
        }
    }
}
#endif
