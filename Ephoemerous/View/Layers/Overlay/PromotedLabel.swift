import SwiftUI
import UIKit
import simd

// MARK: - SkyLabPromotedLabelOverlay
// The selected object's POI label, FORCED visible at any zoom and laid out
// the Apple-Maps / production way: the badge SPRINGS UP off the point
// (leaving a precise-location dot behind) and the name slides in CENTERED
// BELOW it. Handles the badge-style objects — star / sun / moon / planet;
// a selected CONSTELLATION promotes as an emphasised name in its own layer
// (no badge, like production), so this overlay skips it.
//
// One counter-scaled unit anchored on the object: the container's centre
// is the precise location (so the dot sits exactly on the point and stays
// put under the 1/pinch counter-scale); the badge is lifted above it, the
// name dropped below. A single `promo` spring (0→1 on appear) drives the
// lift, the badge enlargement, and the dot/name fade.
struct PromotedLabel: View {

    let camera:    SkyCamera
    let selection: ESkyObject?
    let date:      Date
    let pinch:     CGFloat
    /// Live map rotation — counter-rotated so the pin stays screen-upright
    /// while the sky spins (Apple-Maps), pivoting on its location dot.
    var rotation:  Angle = .zero
    /// Is the selected object remembered? Drives the persistent corner heart,
    /// and the false→true flip fires the celebration (burst + pop + haptic).
    var isFavourite: Bool = false

    /// Only stars can be doubles, and only the rewarding ones are marked.
    private var isShowpieceDouble: Bool {
        if case .star(let s) = selection { return s.multiplicity?.isShowpiece == true }
        return false
    }

    private var labelStyle: POILabelView.LabelStyle {
        switch selection {
        case .star(_):
                .star
        case .sun:
                .star
        case .moon:
                .planetoids
        case .planet(_):
                .planetoids
        case .constellation(_):
                .planetoids
        case nil:
                .planetoids
        }
    }
    
    var body: some View {
        ZStack {
            if let obj = selection,
               let poi = SkyLabObjects.poiMark(obj, date: date),
               let sc  = SkyLabObjects.screen(obj, camera: camera, date: date) {
                SkyLabPromotedPin(category: poi.category,
                                  name:     poi.name,
                                  labelStyle: labelStyle,
                                  favourite: isFavourite,
                                  isDouble:  isShowpieceDouble)
                    .rotationEffect(-rotation, anchor: .center)
                    .scaleEffect(1 / pinch)
                    .position(sc)
                    .id(obj.id)                      // re-spring on a new object
                    .transition(.opacity)            // soft demotion
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - SkyLabPromotedPin
private struct SkyLabPromotedPin: View {

    let category:   POICategory
    let name:       String
    let labelStyle: POILabelView.LabelStyle
    /// Remembered state of the object this pin stands for.
    let favourite:  Bool
    /// A double worth splitting — earns the companion pip, same as the
    /// canvas labels (see `EStarMultiplicity.isShowpiece`).
    let isDouble:   Bool

    /// 0 = flat (badge on the point), 1 = fully promoted pin. Springs up
    /// on appear — the underdamped overshoot is the Apple-Maps pop.
    @State private var promo: Double = 0

    /// Celebration state, driven only by the false→true Remember flip.
    /// `burst` runs a one-shot 0→1 ring expansion; `pop` is the badge's
    /// there-and-back squash. Both rest invisible/neutral between flips.
    @State private var burst: Double = 1          // 1 == spent (invisible)
    @State private var pop:   Bool   = false
    @State private var popBack: Task<Void, Never>? = nil

    /// Fixed local canvas; centre == the precise location (the object).
    private let box = CGSize(width: 220, height: 140)

    private var style: EArtist.POICategoryStyle { EArtist.shared.poiStyle(for: category) }

    var body: some View {
        let a        = EArtist.shared
        let badge    = style.badgeSize
        let lift     = promo * a.poiSelectLiftFactor * badge          // badge rises
        let scale    = 1 + promo * (a.poiSelectScale - 1)             // badge enlarges
        let nameDrop = a.poiSelectNameDrop
        let r        = a.poiSelectDotRadius
        let cx       = box.width / 2
        let cy       = box.height / 2
        let badgeY   = cy - lift
        let onScreen = badge * scale                                  // badge px on screen
        let popScale = pop ? 1.22 : 1                                 // celebration squash

        ZStack {
            // Precise-location dot — the spot the badge lifted off, the
            // name hangs under. Fades in with the promotion.
            Circle()
                .fill(style.gradientBottom)
                .frame(width: r * 2, height: r * 2)
                .shadow(color: .black.opacity(0.35), radius: 1.5)
                .opacity(promo)
                .position(x: cx, y: cy)

            // Sonar burst — a pink ring that springs off the badge on the
            // moment of Remember and fades as it grows. THE attention-grab:
            // the canvas is static, so this radiating pulse pulls the eye
            // straight to the object you just saved.
            Circle()
                .stroke(Self.heartTint, lineWidth: 2.5 * (1 - burst))
                .frame(width: onScreen, height: onScreen)
                .scaleEffect(0.6 + burst * 1.9)
                .opacity((1 - burst) * 0.9)
                .position(x: cx, y: badgeY)
                .allowsHitTesting(false)

            // Badge — reuse the POI badge styling (name off), lifted and
            // enlarged. scaleEffect anchors on its own centre, so it grows
            // in place at the lifted point. The extra `popScale` is the
            // celebration squash — a quick swell that settles back.
            // `borderScaleCompensation` pre-shrinks the casing stroke by the
            // same factor `.scaleEffect` is about to enlarge it by, so the
            // orb grows without the outline turning into a bold halo.
            POILabelView(category:    category,
                         text:        "",
                         labelStyle: labelStyle,
                         badgeReveal: 1,
                         nameReveal:  0,
                         borderScaleCompensation: 1 / (scale * popScale),
                         companionReveal: isDouble ? 1 : 0)
                .scaleEffect(scale * popScale)
                .position(x: cx, y: badgeY)

            // Corner heart — the persistent Remembered mark, springing in
            // on the flip and riding the badge's top-trailing corner (matches
            // the field hearts, one pink voice everywhere).
            FavouriteHeartMark(size: 13,
                               borderScaleCompensation: 1 / max(popScale, 0.2))
                .scaleEffect(favourite ? popScale : 0.2)
                .opacity(favourite ? 1 : 0)
                .position(x: cx + onScreen * 0.42,
                          y: badgeY - onScreen * 0.42)
                .animation(.spring(response: 0.3, dampingFraction: 0.5),
                           value: favourite)

            // Name — centred below the dot, primary ink, real outline
            // casing (same OutlinedText the flat label uses).
            OutlinedText(text:      name,
                         fill:      .primary,
                         stroke:    style.border,
                         lineWidth: 1.5,
                         font:      Self.nameFont)
                .fixedSize()
                .opacity(promo)
                .position(x: cx, y: cy + nameDrop + Self.nameHalfHeight)
        }
        .frame(width: box.width, height: box.height)
        .onAppear {
            withAnimation(.bouncy) {
                promo = 1
            }
        }
        // Only a genuine flip while the pin is alive celebrates — selecting
        // an already-remembered object shows the heart with no fanfare
        // (onChange never fires on initial value).
        .onChange(of: favourite) { _, nowFav in
            if nowFav { celebrate() } else { deCelebrate() }
        }
        .onDisappear { popBack?.cancel() }
    }

    /// The Remember moment: success haptic, sonar burst, badge squash.
    private func celebrate() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        burst = 0
        withAnimation(.easeOut(duration: 0.6)) { burst = 1 }

        popBack?.cancel()
        popBack = Task { @MainActor in
            withAnimation(.spring(response: 0.16, dampingFraction: 0.45)) { pop = true }
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.34, dampingFraction: 0.6)) { pop = false }
        }
    }

    /// Forget: a soft acknowledgement, no fanfare. The heart fades out on
    /// its own `favourite` spring.
    private func deCelebrate() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    /// One favourite tint everywhere — matches `FavouriteHeart` and the
    /// search sheet's REMEMBERED header.
    /// The celebration burst rides the heart's own colour — one pink
    /// voice, defined by `FavouriteHeartMark`.
    private static let heartTint = FavouriteHeartMark.bright

    /// Footnote serif bold (CoreText needs a concrete UIFont) — matches the
    /// flat label's name font.
    private static let nameFont: UIFont = {
        let base = UIFont.preferredFont(forTextStyle: .headline)
        var desc = base.fontDescriptor
        desc = desc.withDesign(.serif) ?? desc
        desc = desc.withSymbolicTraits(.traitBold) ?? desc
        return UIFont(descriptor: desc, size: base.pointSize)
    }()

    /// Rough half-height of the name, so `.position` lands its TOP at
    /// `cy + nameDrop` (the text hangs just below the precise dot).
    private static let nameHalfHeight: CGFloat = nameFont.lineHeight / 2
}
