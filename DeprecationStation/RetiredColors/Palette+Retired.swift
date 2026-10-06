// Retired from `Palette` (Night audit housekeeping, 2026-10-06).
// NOT compiled — kept so the names, docs and asset pairings are on record.
// The matching colour sets sit beside this file, in this folder's subfolders;
// to revive one, move its `.colorset` back under `Assets.xcassets/Palette/`.
//
// Also retired with them:
//   Artist.eclColor / eclWidth / horizonFillColor / userPuckConeColor
//   Planet.color (the second, uncatalogued set of planet tints)
//   Color.base* / grad* / spot* (Color+UIColor.swift)

struct PaletteRetired {
    /// Aim sky-wash tint — the blue the night sky lifts toward where the
    /// phone is pointed (`SkyAimWashLayer`). Stored opaque; alpha is
    /// applied at draw time via the blob opacity + horizon fade.
    let skyAim: Color = Color("skyAim")


    /// Ecliptic squircle stroke.
    let ecliptic: Color = Color("ecliptic")

    // MARK: Horizon

    /// Below-horizon wash (the `.fillOutsideCurve` colour).
    let horizonFill: Color = Color("horizonFill")

    /// Twilight-band strokes (civil / nautical / astronomical).
    let twilightBand: Color = Color("twilightBand")


    // MARK: Constellations

    /// Default constellation stick-figure stroke.
    let constellationLine: Color = Color("constellationLine")

    /// Placeholder pill that sits in for a constellation label at the
    /// in-between zoom tier.
    let constellationPlaceholderFill: Color = Color("placeholderFill")

    // MARK: Myth gradients (POI badges)

    let perseus              : Gradient = (Color("mythPerseusTop"),  Color("mythPerseusBottom"))
    let hercules             : Gradient = (Color("mythHerculesTop"), Color("mythHerculesBottom"))
    let argo                 : Gradient = (Color("mythArgoTop"),     Color("mythArgoBottom"))
    let zeus                 : Gradient = (Color("mythZeusTop"),     Color("mythZeusBottom"))
    let orion                : Gradient = (Color("mythOrionTop"),    Color("mythOrionBottom"))
    let orpheus              : Gradient = (Color("mythOrpheusTop"),  Color("mythOrpheusBottom"))
    let mythNone             : Gradient = (Color("mythNoneTop"),     Color("mythNoneBottom"))
    let mythForeverInvisible : Gradient = (Color("mythForeverInvisibleTop"),
                                            Color("mythForeverInvisibleBottom"))


    // MARK: User location puck

    let userPuckDisc: Color = Color("puckDisc")
    let userPuckRing: Color = Color("puckRing")
    let userPuckCone: Color = Color("puckCone")


    // MARK: Artist — puck + aim-cone constants

    var userPuckSize            : CGFloat { 22 }
    var userPuckConeRadius      : CGFloat { 90 }
    /// Hushed — "you are here" is ambient whisper-tier, and the cone was the
    /// loudest shape on the canvas (metadata louder than the stars it points
    /// at). Length stays honest (tip on the aimed point); only the volume
    /// drops. ▼ TWEAK ▼
    var userPuckConeOpacity     : Double  { 0.16 }
    var userPuckConeMinHalfAngle: Double  { 8 }    // degrees
    var userPuckConeMaxHalfAngle: Double  { 60 }   // degrees
    /// Pitch→length honesty for the aim cone (1 = tip on the aimed point).
    var aimConeLengthGain       : Double  { 1.0 }
    /// Clamp display altitude off the zenith (where azimuth spins).
    var aimConeMaxAltitudeDeg   : Double  { 86 }
    /// Floor at the horizon so the tip doesn't shoot past the rim.
    var aimConeMinAltitudeDeg   : Double  { 0 }
}
