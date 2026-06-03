import SwiftUI
import simd

// MARK: - NamedStarsLayer
// Proper-named stars surfaced as Apple-Maps-style POIs at high zoom.
// Mirrors ConstellationNamesLayer in shape:
//   - one-time filter to the proper-name subset (~300 stars, not 10k)
//   - per-frame projection + screen-cull
//   - draw via `drawPOILabel(category: .namedStar(...))` so the tier
//     engine handles dot → badge → text reveal as the user zooms
//   - publishes hit-rects to `state.namedStarHitRects` once the badge
//     itself is visible, so `ObjectsTrackingOverlay` can drop tap
//     targets that hand off to `state.focus(on: .star(...))`
//
// The layer self-gates on `scale >= artist.namedStarDotIn` so nothing
// renders below that threshold — by design, named-star dots start a
// touch *after* constellation labels finish revealing their text, so
// the canvas reveals information in waves instead of all at once.
struct NamedStarsLayer: EGridLayer {
    /// Proper-name subset, computed once at first access. Iterating
    /// the full 10k-star database every frame would be wasteful — this
    /// filter is the entire reason the layer is cheap.
    ///
    /// Deduped by `name`: the BSC has multiple rows sharing a Bayer
    /// designation (binary-star components — α Cen A / B, etc.), and
    /// drawing two pentagon badges on top of each other would just
    /// stack identical labels. First encountered wins.
    private static let candidates: [EStar] = {
        var seen = Set<String>()
        var out:  [EStar] = []
        for star in StarDatabase.shared.workableStars where star.properName != nil {
            if seen.insert(star.name).inserted { out.append(star) }
        }
        return out
    }()

    /// Reverse lookup for the tap overlay — published hit-rects key
    /// by `star.name` (the catalogue name), and the overlay needs the
    /// EStar back to call `state.focus(on: .star(star))`. Built from
    /// the already-deduped `candidates`, so no collision concerns —
    /// but use a non-trapping initializer anyway so a future data
    /// quirk can't crash app launch.
    private static let candidatesByName: [String: EStar] = Dictionary(
        candidates.map { ($0.name, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// O(1) membership test used by `StarsLayer` to skip stars that
    /// this layer is about to redraw on top. Without this, ~300
    /// proper-named stars get a full `rotate + scale + fill` of their
    /// star path *and* a dot/badge from `NamedStarsLayer` at every
    /// frame above `namedStarDotIn` — the underlying star is then
    /// hidden beneath the badge but still painted.
    static let candidateNames: Set<String> = Set(candidates.map(\.name))

    /// Resolve a star from a published hit-rect key.
    static func star(named name: String) -> EStar? {
        candidatesByName[name]
    }

    /// Extract the `EStar.id` UUID from an `ESkyObject` id of the form
    /// `"star_<uuid>"`, or `nil` for non-star / nil ids. Lets the draw
    /// loop match the promoted star by raw UUID (no per-star string
    /// allocation). Parsed once per frame, not per star.
    static func starUUID(from objectID: String?) -> UUID? {
        guard let objectID, objectID.hasPrefix("star_") else { return nil }
        return UUID(uuidString: String(objectID.dropFirst("star_".count)))
    }

    func draw(in dc: inout EGraphicContext) {
        let stateRef = dc.state
        let scale    = dc.renderedScale

        // Below the dot threshold — clear any stale hit-rects from a
        // previous frame and bail. Skipping the clear when the dict
        // is already empty saves an unnecessary main-queue dispatch.
        guard scale >= artist.namedStarDotIn else {
            if !stateRef.namedStarHitRects.isEmpty {
                DispatchQueue.main.async { stateRef.namedStarHitRects = [:] }
            }
            return
        }

        // FavouritesLayer draws favourited stars with their own badge
        // + breathing halo + earlier thresholds — skip them here so
        // there's no double-render.
        let favouriteNames = Set(dc.state.favouriteStars.map(\.name))
        let tappable      = scale >= artist.namedStarTapMinScale

        // Badge size is constant within `.namedStar` — probe once.
        guard let probe = Self.candidates.first else { return }
        let badgeSize = artist.poiStyle(for: .namedStar(probe)).badgeSize

        var rects: [String: CGRect] = [:]
        if tappable { rects.reserveCapacity(Self.candidates.count) }

        // Promoted star UUIDs, parsed ONCE per frame from the selection
        // ids ("star_<uuid>"). The per-star loop then compares `star.id`
        // (a UUID — zero allocation) instead of building an ESkyObject
        // id string for all ~300 stars every frame, which was pure ARC
        // churn during a selected pan. The string id + `poiPromotion`
        // call now happen only for the ≤2 actually-promoted stars.
        let selStarUUID   = Self.starUUID(from: dc.selectedObjectID)
        let deselStarUUID = Self.starUUID(from: dc.deselectingID)

        for star in Self.candidates where !favouriteNames.contains(star.name) {
            // Honour the magnitude filter — if the user has dialled
            // back to mag ≤ 3, a mag-4 named star shouldn't suddenly
            // pop in just because we know its name.
            guard star.magnitude <= dc.state.magnitudeFilter else { continue }

            let (pRA, pDec) = EPrecession.precess(ra: star.rightAscension, dec: star.declination,
                                                  to: dc.renderedObservationDate)
            let Q = EPrecession.equatorialVector(ra: pRA, dec: pDec)
                .sidereallyRotated(by: dc.localSiderealOffset)
            guard let proj = EProjection.project(Q, viewpoint: dc.viewpoint) else { continue }
            let sc = dc.toScreen(proj)

            // Off-screen cull — no point drawing (or registering a
            // tap target for) something the user can't see.
            guard artist.starPointFallsWithinMarigin(sc, in: dc) else { continue }

            // Cheap UUID compare for the 298 non-promoted stars; only
            // the selected / deselecting star builds the id string +
            // reads its spring.
            let promo: Double = (star.id == selStarUUID || star.id == deselStarUUID)
                ? dc.poiPromotion(forObjectID: ESkyObject.star(star).id)
                : 0
            artist.drawPOILabel(
                at:        sc,
                glyph:     .sfSymbol("star.fill"),
                text:      star.displayName,
                category:  .namedStar(star),
                drawDot:   true,
                promotion: promo,
                in:        &dc
            )

            guard tappable else { continue }
            let hit: CGFloat = max(44, badgeSize + 16)
            rects[star.name] = CGRect(x: sc.x - hit / 2, y: sc.y - hit / 2,
                                      width: hit, height: hit)
        }

        let snapshot = rects
        // Equality-guard — at 120 Hz we'd otherwise republish the
        // same ~hundred-entry dict every frame and re-invalidate
        // ObjectsTrackingOverlay for no reason.
        DispatchQueue.main.async {
            if stateRef.namedStarHitRects != snapshot {
                stateRef.namedStarHitRects = snapshot
            }
        }
    }
}
