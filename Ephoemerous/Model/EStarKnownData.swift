
// MARK: - Known Star Data

extension EStar {

    /// IAU proper name for well-known stars, keyed by computed name string
    var properName: String? {
        Self.properNames[name]
    }

    /// Distance in light-years for well-known stars
    var distanceLY: Double? {
        Self.distances[name]
    }

    /// Display name: proper name if available, otherwise the Bayer designation
    var displayName: String {
        properName ?? name
    }

    private static let properNames: [String: String] = [
        "α Tau" : "Aldebaran",
        "η Tau" : "Alcyone",
        "γ Gem" : "Alhena",
        "α Boo" : "Arcturus",
        "γ Ori" : "Bellatrix",
        "α Ori" : "Betelgeuse",
        "α Aur" : "Capella",
        "α Gem" : "Castor",
        "α Per" : "Mirfak",
        "ζ UMa" : "Mizar",
        "β Gem" : "Pollux",
        "α CMi" : "Procyon",
        "α Leo" : "Regulus",
        "β Ori" : "Rigel",
        "α CMa" : "Sirius",
    ]

    // Distances in light-years (Hipparcos / IAU best values)
    private static let distances: [String: Double] = [
        "α Tau" :  65.3,   // Aldebaran
        "η Tau" : 440.0,   // Alcyone
        "γ Gem" : 109.0,   // Alhena
        "α Boo" :  36.7,   // Arcturus
        "γ Ori" : 250.0,   // Bellatrix
        "α Ori" : 700.0,   // Betelgeuse (updated 2020 Hipparcos revision)
        "α Aur" :  42.9,   // Capella
        "α Gem" :  51.0,   // Castor
        "α Per" : 510.0,   // Mirfak
        "ζ UMa" :  82.9,   // Mizar
        "β Gem" :  34.0,   // Pollux
        "α CMi" :  11.5,   // Procyon
        "α Leo" :  79.3,   // Regulus
        "β Ori" : 860.0,   // Rigel
        "α CMa" :   8.6,   // Sirius
    ]
}
