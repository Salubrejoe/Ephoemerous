import SwiftUI
import simd

// MARK: - HeroBanner
// The picture at the top of an expanded detail sheet. Always a rendered
// patch of sky (`SkyHeroView`) from the app's own star catalogue:
//   • constellation — framed on its figure
//   • star          — centred on the star, with a halo
//   • planet        — centred on where it is now: a precise dot on the true
//                     position, and the planet's NASA photograph floating
//                     above it at promoted-pin size — the same grammar as the
//                     pin on the canvas, the photo standing in for the badge
//   • Sun, Moon     — at their TRUE angular size (~½°) on their position, the
//                     field zoomed until that half degree is as wide as
//                     Saturn's hero; the Moon masked to tonight's phase
//   • spacecraft    — pinned like a planet, wearing its silhouette
// Until a photo arrives (or if it never does) the body's badge stands in.
// Full-bleed, fading into the sheet at its foot so the title can ride it.
struct HeroBanner: View {

    @Environment(AppState.self) private var state

    let object: SkyObject

    private let artist = Artist.shared
    private var store:  HeroImageStore { .shared }
    /// The banner's height — `heroHeight` at rest; a sheet scrolling its
    /// body up can pass less, so the header gives the grid more room.
    var height: CGFloat = Artist.shared.heroHeight
    /// See `SkyHeroView.ground`.
    var ground: Bool = true
    /// Show the real photographs of the planets, Sun and Moon. Off on the
    /// place cards, which wear the app's own badges — prettier, and of a
    /// piece with the sky the object was tapped on.
    var photos: Bool = true
    /// Label and link the constellation figure's stars (the place card).
    var figureMarks: Bool = false

    /// The credit line the body's photograph carries, if it has one.
    var credit: String? { HeroSource.photo(for: object)?.credit }

    var body: some View {
        ZStack {
            SkyHeroView(focus: focus, ground: ground)
            subject
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .mask(LinearGradient(stops: [.init(color: .black, location: 0.5),
                                     .init(color: .clear, location: 1)],
                             startPoint: .top, endPoint: .bottom))
        // Over the fade, so the names stay legible to the bottom stars.
        .overlay {
            if figureMarks, case .constellation(let c) = object {
                HeroFigureMarks(scene: SkyHeroScene(focus: .constellation(c)))
            }
        }
        .task(id: object.id) { if photos { await store.load(object) } }
    }

    // MARK: Sky

    private var observer: SatelliteSky.Observer {
        SatelliteSky.Observer(latitude:  state.origin.latitude.radians,
                              longitude: state.origin.longitude.radians)
    }

    /// Half the field shown above and below centre, radians. The Sun and
    /// Moon get the field that makes their true ½° exactly as wide as
    /// Saturn's hero (rings and all) — magnified, but still to scale with
    /// the stars around them. Everything else gets a wide patch.
    private var halfField: Double {
        switch object {
        case .sun:  return luminaryHalfField(for: artist.sunAngularDiameter)
        case .moon: return luminaryHalfField(for: artist.moonAngularDiameter)
        default:    return artist.heroBodyHalfField
        }
    }

    private func luminaryHalfField(for angle: Double) -> Double {
        let target = Double(artist.heroLuminaryDiameter)
        return atan(Double(height) * tan(angle / 2) / target)
    }

    /// Points per radian (tangent unit) at the centre — the scale the sky
    /// is drawn at, so true sizes can be drawn in it.
    private var pointsPerTangent: CGFloat { height / CGFloat(2 * tan(halfField)) }

    private var focus: SkyHeroScene.Focus {
        switch object {
        case .constellation(let c): return .constellation(c)
        case .star(let s):          return .star(s)
        default:
            // A craft with no orbit data for this date has no place; the
            // pole stands in rather than collapsing the header.
            return .point(object.equatorialDirection(at: state.observationDate, from: observer) ?? SIMD3(0, 0, 1),
                          halfField: halfField)
        }
    }

    // MARK: Subject

    @ViewBuilder
    private var subject: some View {
        switch object {
        case .constellation, .star:
            EmptyView()                          // the sky IS the subject
        case .sun, .moon:
            luminary
        case .planet(let p):
            pinned(.planet(p)) { planetPhoto(p) }
        case .spacecraft(let craft):
            pinned(.spacecraft(craft)) {
                let size = artist.poiStyle(for: .spacecraft(craft)).badgeSize * artist.poiSelectScale
                SpacecraftGlyph(craft:      craft,
                                casing:     artist.poiBadgeCasing,
                                lineWidth:  artist.poiTextBorderWidth,
                                fullDetail: true,
                                masked:     false)
                    .frame(width: size, height: size)
            }
        }
    }

    /// The promoted-pin grammar: a precise dot on the true position at the
    /// centre, the subject lifted above it.
    private func pinned<Content: View>(_ category: POICategory,
                                       @ViewBuilder _ content: () -> Content) -> some View {
        let style = artist.poiStyle(for: category)
        let r     = artist.poiSelectDotRadius
        return ZStack {
            Circle()
                .fill(style.gradientBottom)
                .frame(width: r * 2, height: r * 2)
                .shadow(color: .black.opacity(0.35), radius: 1.5)
            content()
                .offset(y: -artist.poiSelectLiftFactor * style.badgeSize)
        }
    }

    /// A planet's photograph at promoted-badge size: the disc spans what
    /// the enlarged badge would, Saturn's rings what the ringed badge's do.
    @ViewBuilder
    private func planetPhoto(_ planet: Planet) -> some View {
        let category = POICategory.planet(planet)
        let diameter = artist.poiStyle(for: category).badgeSize * artist.poiSelectScale
        if photos, case .ready(let image) = store.status(for: object), let source = HeroSource.photo(for: object) {
            switch source.fit {
            case .disc(let fraction):
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: diameter / fraction, height: diameter / fraction)
            case .rings(let fraction):
                Image(uiImage: image).resizable().scaledToFit()
                    .frame(width: diameter * artist.saturnRingOuter.width / fraction)
            }
        } else {
            badge(category, sizeScale: artist.poiSelectScale)
        }
    }

    /// The Sun or the Moon at its true angular size on its position.
    @ViewBuilder
    private var luminary: some View {
        let angle    = object == .sun ? artist.sunAngularDiameter : artist.moonAngularDiameter
        let diameter = CGFloat(2 * tan(angle / 2)) * pointsPerTangent
        let category: POICategory = object == .sun ? .sun : .moon
        let phase    = BadgePhase.of(category, date: state.observationDate, latitude: state.origin.latitude)
        ZStack {
            if object == .sun {
                // The Sun's glare, so a half-degree disc still reads as THE Sun.
                // Sized to the picture, so it fades out before the frame's
                // edge instead of being clipped flat by it.
                let glow = min(diameter * 5, height * 0.95)
                Circle()
                    .fill(RadialGradient(colors: [artist.palette.sun.top.opacity(0.45), .clear],
                                         center: .center, startRadius: 0, endRadius: glow / 2))
                    .frame(width: glow, height: glow)
            }
            if photos, case .ready(let image) = store.status(for: object),
               case .disc(let fraction) = HeroSource.photo(for: object)?.fit {
                let photo = Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: diameter / fraction, height: diameter / fraction)
                if let phase {
                    // Tonight's Moon, not Galileo's: masked to the lit shape.
                    photo.mask(MoonPhaseShape(phase: phase).frame(width: diameter, height: diameter))
                        .opacity(phase.isNew ? 0.15 : 1)
                } else {
                    photo
                }
            } else {
                badge(category, sizeScale: diameter / artist.poiStyle(for: category).badgeSize)
            }
        }
    }

    /// The body's own badge, standing in for a photo not yet (or never) here.
    private func badge(_ category: POICategory, sizeScale: CGFloat) -> some View {
        POILabelView(category:   category,
                     text:       "",
                     // The Sun wears the star's pentagon squircle, as on the sky.
                     labelStyle: category == .sun ? .star : .planetoids,
                     nameReveal: 0,
                     phase:      BadgePhase.of(category, date: state.observationDate,
                                               latitude: state.origin.latitude),
                     richDetail: true,
                     sizeScale:  sizeScale)
    }
}
