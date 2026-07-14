// MARK: - Known Star Data
extension EStar {
    var properName: String? { Self.properNames[name] }
    var distanceLY: Double?  { Self.distances[name]  }
    var displayName: String  { properName ?? name    }
    
    var distanceMeters: Double? { if let distanceLY { distanceLY * 9_460_730_472_580_800 } else { nil } }

    // IAU-approved proper names (Bayer designation -> IAU name)
    private static let properNames: [String: String] = [
        // Orion
        "α Ori" : "Betelgeuse",
        "β Ori" : "Rigel",
        "γ Ori" : "Bellatrix",
        "δ Ori" : "Mintaka",
        "ε Ori" : "Alnilam",
        "ζ Ori" : "Alnitak",
        "κ Ori" : "Saiph",
        "ι Ori" : "Hatysa",
        // Canis Major / Minor
        "α CMa" : "Sirius",
        "ε CMa" : "Adhara",
        "δ CMa" : "Wezen",
        "β CMa" : "Mirzam",
        "η CMa" : "Aludra",
        "α CMi" : "Procyon",
        "β CMi" : "Gomeisa",
        // Scorpius
        "α Sco" : "Antares",
        "λ Sco" : "Shaula",
        "θ Sco" : "Sargas",
        "μ Sco" : "Graffias",
        "δ Sco" : "Dschubba",
        "π Sco" : "Fang",
        "ε Sco" : "Larawag",
        "κ Sco" : "Girtab",
        "υ Sco" : "Lesath",
        // Centaurus
        "α Cen" : "Rigil Kentaurus",
        "β Cen" : "Hadar",
        "θ Cen" : "Menkent",
        // Taurus
        "α Tau" : "Aldebaran",
        "η Tau" : "Alcyone",
        "β Tau" : "Elnath",
        // Gemini
        "α Gem" : "Castor",
        "β Gem" : "Pollux",
        "γ Gem" : "Alhena",
        "μ Gem" : "Tejat",
        "η Gem" : "Propus",
        // Leo
        "α Leo" : "Regulus",
        "β Leo" : "Denebola",
        "γ Leo" : "Algieba",
        "δ Leo" : "Zosma",
        "θ Leo" : "Chertan",
        // Virgo
        "α Vir" : "Spica",
        "ε Vir" : "Vindemiatrix",
        "γ Vir" : "Porrima",
        // Bootes
        "α Boo" : "Arcturus",
        "ε Boo" : "Izar",
        "β Boo" : "Nekkar",
        "η Boo" : "Muphrid",
        // Auriga
        "α Aur" : "Capella",
        "ι Aur" : "Hassaleh",
        // Cygnus
        "α Cyg" : "Deneb",
        "β Cyg" : "Albireo",
        "γ Cyg" : "Sadr",
        "ε Cyg" : "Gienah",
        // Aquila
        "α Aql" : "Altair",
        "β Aql" : "Alshain",
        "γ Aql" : "Tarazed",
        // Lyra
        "α Lyr" : "Vega",
        "β Lyr" : "Sheliak",
        "γ Lyr" : "Sulafat",
        // Carina / Vela / Puppis
        "α Car" : "Canopus",
        "β Car" : "Miaplacidus",
        "ε Car" : "Avior",
        "α Vel" : "Suhail",
        "γ Vel" : "Regor",
        "α Pup" : "Naos",
        // Eridanus
        "α Eri" : "Achernar",
        "β Eri" : "Cursa",
        "θ Eri" : "Acamar",
        // Cetus
        "α Cet" : "Menkar",
        "β Cet" : "Diphda",
        // Ursa Major / Minor
        "α UMa" : "Dubhe",
        "β UMa" : "Merak",
        "γ UMa" : "Phecda",
        "δ UMa" : "Megrez",
        "ε UMa" : "Alioth",
        "ζ UMa" : "Mizar",
        "η UMa" : "Alkaid",
        "α UMi" : "Polaris",
        "β UMi" : "Kochab",
        "γ UMi" : "Pherkad",
        // Perseus / Cassiopeia / Andromeda
        "α Per" : "Mirfak",
        "β Per" : "Algol",
        "α Cas" : "Schedar",
        "β Cas" : "Caph",
        "γ Cas" : "Navi",
        "δ Cas" : "Ruchbah",
        "ε Cas" : "Segin",
        "α And" : "Alpheratz",
        "β And" : "Mirach",
        "γ And" : "Almach",
        // Pegasus
        "α Peg" : "Markab",
        "β Peg" : "Scheat",
        "γ Peg" : "Algenib",
        "ε Peg" : "Enif",
        // Ophiuchus / Hercules
        "α Oph" : "Rasalhague",
        "ζ Oph" : "Han",
        "α Her" : "Rasalgethi",
        "β Her" : "Kornephoros",
        "α CrB" : "Alphecca",
        "α Ser" : "Unukalhai",
        // Sagittarius
        "ε Sgr" : "Kaus Australis",
        "σ Sgr" : "Nunki",
        "λ Sgr" : "Kaus Borealis",
        "δ Sgr" : "Kaus Media",
        "ζ Sgr" : "Ascella",
        "γ Sgr" : "Alnasl",
        // Capricornus / Aquarius
        "α Cap" : "Algedi",
        "β Cap" : "Dabih",
        "δ Cap" : "Deneb Algedi",
        "α Aqr" : "Sadalsuud",
        "β Aqr" : "Sadalmelik",
        // Southern
        "α PsA" : "Fomalhaut",
        "α Gru" : "Alnair",
        "α Phe" : "Ankaa",
        "α TrA" : "Atria",
        "α Cru" : "Acrux",
        "β Cru" : "Mimosa",
        "γ Cru" : "Gacrux",
        // Aries / Corvus / Hydra / Libra / misc
        "α Ari" : "Hamal",
        "β Ari" : "Sheratan",
        "γ Crv" : "Gienah",
        "β Crv" : "Kraz",
        "δ Crv" : "Algorab",
        "α Hya" : "Alphard",
        "α CVn" : "Cor Caroli",
        "α Lib" : "Zubenelgenubi",
        "β Lib" : "Zubeneschamali",
        "α Lep" : "Arneb",
        "β Lep" : "Nihal",
        "α Col" : "Phact",
        "α Del" : "Sualocin",
        "β Del" : "Rotanev",
        "α Psc" : "Alrescha",
        "α Sge" : "Sham",
        "α Vul" : "Anser",
    ]

    // Distances in light-years (Hipparcos / Gaia DR2). Merged once from
    // the hand-curated core + the extended sweep (every Bayer star to
    // mag ≈ 4.0, added for the HR diagram's density) — chunked so no
    // single literal slows the type-checker. Core wins on any overlap.
    private static let distances: [String: Double] = {
        var d = distancesCore
        d.merge(distancesExtendedA) { core, _ in core }
        d.merge(distancesExtendedB) { core, _ in core }
        return d
    }()

    private static let distancesCore: [String: Double] = [
        // Orion
        "α Ori" :   700.0,   // Betelgeuse
        "β Ori" :   860.0,   // Rigel
        "γ Ori" :   250.0,   // Bellatrix
        "δ Ori" :   900.0,   // Mintaka
        "ε Ori" :  1344.0,   // Alnilam
        "ζ Ori" :   800.0,   // Alnitak
        "κ Ori" :   720.0,   // Saiph
        "ι Ori" :  1350.0,   // Hatysa
        // CMa / CMi
        "α CMa" :     8.6,   // Sirius
        "ε CMa" :   431.0,   // Adhara
        "δ CMa" :  1600.0,   // Wezen
        "β CMa" :   500.0,   // Mirzam
        "η CMa" :  3200.0,   // Aludra
        "α CMi" :    11.5,   // Procyon
        // Scorpius
        "α Sco" :   550.0,   // Antares
        "λ Sco" :   700.0,   // Shaula
        "θ Sco" :   300.0,   // Sargas
        "δ Sco" :   401.0,   // Dschubba
        "ε Sco" :    65.0,   // Larawag
        "κ Sco" :   483.0,   // Girtab
        "υ Sco" :   580.0,   // Lesath
        // Centaurus
        "α Cen" :     4.4,   // Rigil Kentaurus
        "β Cen" :   390.0,   // Hadar
        "θ Cen" :    61.0,   // Menkent
        // Taurus
        "α Tau" :    65.3,   // Aldebaran
        "η Tau" :   440.0,   // Alcyone
        "β Tau" :   130.0,   // Elnath
        // Gemini
        "α Gem" :    51.0,   // Castor
        "β Gem" :    34.0,   // Pollux
        "γ Gem" :   109.0,   // Alhena
        "μ Gem" :   230.0,   // Tejat
        // Leo
        "α Leo" :    79.3,   // Regulus
        "β Leo" :    36.2,   // Denebola
        "γ Leo" :   130.0,   // Algieba
        "δ Leo" :    58.4,   // Zosma
        "θ Leo" :   165.0,   // Chertan
        // Virgo
        "α Vir" :   250.0,   // Spica
        "ε Vir" :   102.0,   // Vindemiatrix
        "γ Vir" :    38.6,   // Porrima
        // Bootes
        "α Boo" :    36.7,   // Arcturus
        "ε Boo" :   203.0,   // Izar
        "η Boo" :    37.2,   // Muphrid
        // Auriga
        "α Aur" :    42.9,   // Capella
        "ι Aur" :   512.0,   // Hassaleh
        // Cygnus
        "α Cyg" :  2600.0,   // Deneb
        "γ Cyg" :  1800.0,   // Sadr
        "ε Cyg" :    72.0,   // Gienah
        // Aquila
        "α Aql" :    16.7,   // Altair
        "γ Aql" :   461.0,   // Tarazed
        // Lyra
        "α Lyr" :    25.0,   // Vega
        // Carina / Vela / Puppis
        "α Car" :   310.0,   // Canopus
        "β Car" :   113.0,   // Miaplacidus
        "ε Car" :   632.0,   // Avior
        "α Vel" :   116.0,   // Suhail
        "γ Vel" :   840.0,   // Regor
        "α Pup" :  1400.0,   // Naos
        // Eridanus
        "α Eri" :   139.0,   // Achernar
        "β Eri" :    89.0,   // Cursa
        "θ Eri" :   161.0,   // Acamar
        // Cetus
        "β Cet" :    96.3,   // Diphda
        "α Cet" :   220.0,   // Menkar
        // Ursa Major / Minor
        "α UMa" :   123.0,   // Dubhe
        "β UMa" :    79.7,   // Merak
        "γ UMa" :    83.7,   // Phecda
        "δ UMa" :    81.4,   // Megrez
        "ε UMa" :    81.0,   // Alioth
        "ζ UMa" :    82.9,   // Mizar
        "η UMa" :   101.0,   // Alkaid
        "α UMi" :   431.0,   // Polaris
        "β UMi" :   126.0,   // Kochab
        // Perseus / Cassiopeia / Andromeda
        "α Per" :   510.0,   // Mirfak
        "β Per" :    90.0,   // Algol
        "α Cas" :   228.0,   // Schedar
        "β Cas" :    54.7,   // Caph
        "γ Cas" :   613.0,   // Navi
        "δ Cas" :    99.4,   // Ruchbah
        "ε Cas" :   441.0,   // Segin
        "α And" :    97.0,   // Alpheratz
        "β And" :   197.0,   // Mirach
        "γ And" :   355.0,   // Almach
        // Pegasus
        "α Peg" :   133.0,   // Markab
        "β Peg" :   196.0,   // Scheat
        "ε Peg" :   690.0,   // Enif
        // Ophiuchus / Hercules
        "α Oph" :    46.7,   // Rasalhague
        "ζ Oph" :   366.0,   // Han
        "α Her" :   360.0,   // Rasalgethi
        "β Her" :   139.0,   // Kornephoros
        // Sagittarius
        "ε Sgr" :   143.0,   // Kaus Australis
        "σ Sgr" :   228.0,   // Nunki
        "λ Sgr" :    77.3,   // Kaus Borealis
        "δ Sgr" :   306.0,   // Kaus Media
        "ζ Sgr" :    88.0,   // Ascella
        // Southern
        "α PsA" :    25.1,   // Fomalhaut
        "α Gru" :   101.0,   // Alnair
        "α Phe" :    77.0,   // Ankaa
        "α TrA" :   391.0,   // Atria
        "α Cru" :   320.0,   // Acrux
        "β Cru" :   280.0,   // Mimosa
        "γ Cru" :    88.0,   // Gacrux
        // Misc
        "α Ari" :    66.0,   // Hamal
        "β Ari" :    59.6,   // Sheratan
        "γ Crv" :   165.0,   // Gienah
        "β Crv" :   146.0,   // Kraz
        "α Hya" :   177.0,   // Alphard
        "α CVn" :   110.0,   // Cor Caroli
        "α Lib" :    77.0,   // Zubenelgenubi
        "β Lib" :   160.0,   // Zubeneschamali
        "α Lep" :  1280.0,   // Arneb
        "β Lep" :   159.0,   // Nihal
        "α Col" :   261.0,   // Phact
        "α Del" :   254.0,   // Sualocin
        "β Del" :   101.0,   // Rotanev
    ]

    // Extended sweep, part A — every remaining Bayer star to mag ≈ 4.0.
    // Hipparcos-era values, good to ~10%; fine for the HR diagram, worth
    // a curation pass if anything more precise ever leans on them.
    private static let distancesExtendedA: [String: Double] = [
        "β Aur" :    81.1,   // Menkalinan
        "α Pav" :   179.0,   // Peacock
        "δ Vel" :    80.6,   // Alsephina
        "β Gru" :   170.0,   // Tiaki
        "γ Cen" :   130.0,
        "λ Vel" :   545.0,   // Suhail
        "α CrB" :    75.0,   // Alphecca
        "γ Dra" :   154.0,   // Eltanin
        "ζ Pup" :  1080.0,
        "ι Car" :   690.0,   // Aspidiske
        "α Lup" :   460.0,
        "ε Cen" :   430.0,
        "η Cen" :   308.0,
        "η Oph" :    88.0,   // Sabik
        "α Cep" :    49.0,   // Alderamin
        "κ Vel" :   570.0,
        "ζ Cen" :   384.0,
        "δ Cen" :   410.0,
        "β Sco" :   400.0,   // Acrab
        "θ Aur" :   166.0,   // Mahasim
        "α Ser" :    74.0,   // Unukalhai
        "β Lup" :   524.0,
        "α Mus" :   315.0,
        "μ Vel" :   117.0,
        "π Pup" :   810.0,
        "δ Oph" :   171.0,   // Yed Prior
        "η Dra" :    92.0,   // Athebyne
        "ι Cen" :    59.0,
        "θ Car" :   460.0,
        "β Oph" :    82.0,   // Cebalrai
        "γ Lup" :   420.0,
        "β Dra" :   380.0,   // Rastaban
        "β Hyi" :    24.3,
        "δ Cru" :   345.0,
        "ζ Her" :    35.0,
        "ρ Pup" :    63.5,   // Tureis
        "τ Sco" :   470.0,   // Paikauhale
        "γ Peg" :   390.0,   // Algenib
        "β Ara" :   600.0,
        "β TrA" :    40.0,
        "ζ Per" :   750.0,
        "α Hyi" :    71.8,
        "α Tuc" :   200.0,
        "δ Cap" :    38.7,   // Deneb Algedi
        "δ Cyg" :   165.0,   // Fawaris
        "γ TrA" :   184.0,
        "ε Per" :   640.0,
        "π Sco" :   590.0,   // Fang
        "π Sgr" :   510.0,   // Albaldah
        "σ Sco" :   700.0,   // Alniyat
        "β CMi" :   160.0,   // Gomeisa
        "β Aqr" :   540.0,   // Sadalsuud
        "γ Per" :   240.0,
        "τ Pup" :   174.0,
        "η Peg" :   195.0,   // Matar
        "α Ara" :   270.0,
        "γ Eri" :   200.0,   // Zaurak
        "δ Crv" :    87.0,   // Algorab
        "α Aqr" :   760.0,   // Sadalmelik
        "ε Gem" :   840.0,   // Mebsuta
        "ε Leo" :   250.0,   // Algenubi
        "γ Sgr" :    97.0,   // Alnasl
        "ε Aur" :  2000.0,   // Almaaz
        "ζ Aql" :    83.0,   // Okab
        "β Tri" :   127.0,
        "γ Hya" :   134.0,
        "ε Crv" :   320.0,
        "ζ Tau" :   440.0,   // Tianguan
        "γ Gru" :   210.0,   // Aldhanab
        "δ Per" :   520.0,
        "υ Car" :  1400.0,
        "ψ UMa" :   145.0,
        "ζ CMa" :   360.0,   // Furud
        "ο CMa" :  2500.0,
        "γ Boo" :    87.0,   // Seginus
        "ι Sco" :  1900.0,
        "μ Cen" :   510.0,
        "ο Cet" :   300.0,   // Mira
        "β Mus" :   340.0,
        "γ UMi" :   487.0,   // Pherkad
        "μ UMa" :   230.0,   // Tania Australis
        "δ Dra" :    97.0,   // Altais
        "β Cap" :   340.0,   // Dabih
        "β Cyg" :   420.0,   // Albireo
        "μ Sco" :   500.0,
        "α Ind" :   100.0,
        "ζ Hya" :   167.0,
        "η Sgr" :   146.0,
        "ν Hya" :   144.0,
        "β Col" :    87.0,   // Wazn
        "α Lyn" :   200.0,
        "ζ Ara" :   490.0,
        "κ Cen" :   540.0,
        "λ Cen" :   410.0,
        "δ Her" :    75.0,   // Sarin
        "ι UMa" :    47.3,   // Talitha
        "π Her" :   380.0,
        "ζ Dra" :   330.0,   // Aldhibah
        "η Aur" :   243.0,   // Haedus
        "θ UMa" :    44.0,
        "ν Pup" :   420.0,
        "φ Sgr" :   240.0,
        "α Cir" :    54.0,
        "ε Lep" :   210.0,
        "π Ori" :    26.3,   // Tabit
        "ζ Cyg" :   143.0,
        "κ Oph" :    92.0,
        "γ Cep" :    45.0,   // Errai
        "δ Lup" :   900.0,
        "β Cep" :   690.0,   // Alfirk
        "θ Aql" :   290.0,
        "γ Hyi" :   214.0,
        "γ Lyr" :   620.0,   // Sulafat
        "ε Oph" :   110.0,   // Yed Posterior
        "σ Pup" :   180.0,
        "η Ser" :    60.5,
        "α Dor" :   169.0,
        "α Pic" :    97.0,
        "δ And" :   105.0,
        "δ Aqr" :   113.0,   // Skat
        "θ Oph" :   440.0,
        "π Hya" :   100.0,
        "η Gem" :   380.0,   // Propus
        "ι Dra" :   101.0,   // Edasich
        "σ Lib" :   290.0,   // Brachium
        "β Phe" :   200.0,
        "μ Lep" :   186.0,
        "τ Sgr" :   120.0,
        "ω Car" :   340.0,
        "η Sco" :    73.0,
        "γ Ara" :  1100.0,
        "ν Oph" :   150.0,
        "ξ Pup" :  1200.0,   // Azmidi
        "α Ret" :   162.0,
        "ζ Cep" :   730.0,
        "δ Aql" :    50.6,
        "η Ori" :   900.0,
        "ξ Gem" :    58.7,   // Alzirr
        "ο UMa" :   180.0,   // Muscida
        "ε Lup" :   510.0,
        "ζ Vir" :    74.0,   // Heze
        "δ Vir" :   200.0,   // Auva
        "ε Hya" :   130.0,   // Ashlesha
        "ρ Per" :   310.0,
        "ζ Peg" :   200.0,   // Homam
        "θ Tau" :   150.0,
        "α Tri" :    63.0,   // Mothallah
        "γ Phe" :   235.0,
        "ζ Lup" :   117.0,
        "η Lup" :   490.0,
        "ν Cen" :   440.0,
        "β Pav" :   135.0,
        "μ Her" :    27.4,
        "η Cep" :    47.0,
        "ζ Leo" :   270.0,   // Adhafera
        "η Cas" :    19.4,   // Achird
        "λ Aql" :   125.0,
        "β Lyr" :   960.0,   // Sheliak
        "η Cet" :   124.0,   // Dheneb
        "λ UMa" :   138.0,   // Tania Borealis
        "γ Cet" :    80.0,   // Kaffaljidhma
        "γ Sge" :   260.0,
        "δ Boo" :   122.0,
        "λ Tau" :   480.0,
        "σ CMa" :  1100.0,   // Unurgunite
        "χ Car" :   450.0,
        "μ Peg" :   106.0,   // Sadalbari
        "ν UMa" :   400.0,   // Alula Borealis
        "ε Gru" :   130.0,
    ]

    // Extended sweep, part B — continuation (see A).
    private static let distancesExtendedB: [String: Double] = [
        "β Boo" :   225.0,   // Nekkar
        "τ Cet" :    11.9,
        "α Tel" :   280.0,
        "ξ Sgr" :   370.0,
        "β Cnc" :   290.0,   // Tarf
        "η Leo" :  1270.0,
        "ι Cep" :   115.0,
        "ο Leo" :   135.0,   // Subra
        "δ Gem" :    60.5,   // Wasat
        "ε Tau" :   147.0,   // Ain
        "η Her" :   112.0,
        "θ Peg" :    92.0,   // Biham
        "μ Ser" :   156.0,
        "δ Eri" :    29.5,   // Rana
        "λ Ori" :  1100.0,   // Meissa
        "ξ Hya" :   130.0,
        "ξ Ser" :   105.0,
        "φ Vel" :  1600.0,
        "ζ Lep" :    70.5,
        "ι Lup" :   350.0,
        "δ Crt" :   163.0,
        "δ Pav" :    19.9,
        "ι Cet" :   275.0,
        "υ Eri" :   214.0,   // Theemin
        "φ Eri" :   155.0,
        "φ Lup" :   320.0,
        "α Cap" :   106.0,   // Algedi
        "κ Gem" :   143.0,
        "χ Dra" :    27.0,
        "λ Gem" :   100.0,
        "ρ Boo" :   160.0,
        "υ Lib" :   195.0,
        "ε Cru" :   230.0,   // Ginan
        "γ Lep" :    29.0,
        "θ Cet" :   115.0,
        "θ Gem" :   197.0,
        "κ UMa" :   360.0,   // Alkaphrah
        "ο Tau" :   210.0,
        "τ Ori" :   555.0,
        "ψ Vel" :    61.0,
        "β Vir" :    35.7,   // Zavijava
        "λ Hya" :   110.0,
        "δ Ara" :   187.0,
        "δ Mus" :    91.0,
        "ζ Sco" :   130.0,
        "η Pav" :   350.0,
        "η Psc" :   350.0,   // Alpherg
        "ο And" :   690.0,
        "λ Mus" :   128.0,
        "α Dra" :   303.0,   // Thuban
        "β Ind" :   600.0,
        "γ Tau" :   154.0,   // Prima Hyadum
        "ζ Cas" :   600.0,   // Fulu
        "θ Ara" :  1000.0,
        "τ Lib" :   365.0,
        "β Ser" :   155.0,
        "α Pyx" :   880.0,
        "β CrB" :   114.0,   // Nusakan
        "γ Cap" :   157.0,   // Nashira
        "γ Psc" :   138.0,
        "τ Eri" :   300.0,
        "ξ Her" :   135.0,
        "χ Eri" :    57.0,
        "β Aql" :    44.7,   // Alshain
        "ε Ser" :    70.0,
        "η Lep" :    49.0,
        "χ UMa" :   196.0,   // Taiyangshou
        "δ Aur" :   140.0,
        "ξ Cyg" :  1200.0,
        "τ Cyg" :    68.0,
        "ε Eri" :    10.5,   // Ran
        "ζ Cet" :   235.0,   // Baten Kaitos
        "ζ Cap" :   386.0,
        "λ Aqr" :   365.0,   // Hydor
        "ξ Tau" :   210.0,
        "γ Her" :   195.0,
        "γ Oph" :    95.0,
        "δ Cep" :   890.0,
        "ζ Aur" :   790.0,   // Saclateni
        "ξ Dra" :   112.0,   // Grumium
        "β Dor" :  1040.0,
        "δ Tau" :   155.0,   // Secunda Hyadum
        "η Ara" :   310.0,
        "η Per" :  1300.0,   // Miram
        "ι Peg" :    38.0,
        "ν Oct" :    64.0,
        "α Lac" :   102.0,
        "β Vol" :   107.0,
        "ε Aqr" :   230.0,   // Albali
        "κ Cyg" :   124.0,
        "ν Per" :   560.0,
        "ο Sgr" :   142.0,
        "γ Vol" :   142.0,
        "ζ Gem" :  1100.0,   // Mekbuda
        "ι Cyg" :   121.0,
        "ι Gem" :   330.0,
        "δ Ser" :   230.0,
        "ι Her" :   455.0,
        "κ Per" :   113.0,   // Misam
        "υ UMa" :   115.0,
        "δ Lep" :   115.0,
        "μ Hya" :   245.0,
        "σ Ori" :  1150.0,
        "δ Sge" :   550.0,
        "λ And" :    84.0,
        "λ Oph" :   170.0,   // Marfik
        "α Aps" :   410.0,
        "ε Dra" :   148.0,   // Tyl
        "ο Her" :   340.0,
        "ο Per" :  1000.0,   // Atik
        "φ Cen" :   465.0,
        "γ Aqr" :   164.0,   // Sadachbia
        "γ CrB" :   146.0,
        "λ Dra" :   333.0,   // Giausar
        "α Sct" :   199.0,
        "β Pic" :    63.4,
        "β Ret" :   100.0,
        "γ Ser" :    36.3,
        "δ Col" :   237.0,
        "δ TrA" :   620.0,
        "ρ Leo" :  5000.0,
        "ω CMa" :   920.0,
        "α Hor" :   115.0,
        "θ Her" :   750.0,
        "μ Sgr" :  3600.0,   // Polis
        "τ Cen" :   132.0,
        "α For" :    46.0,   // Dalim
        "γ Mus" :   325.0,
        "ε Col" :   280.0,
        "κ Dra" :   460.0,
        "κ Lup" :   180.0,
        "μ And" :   130.0,
        "υ Cen" :   425.0,
        "ε Phe" :   140.0,
        "θ Hya" :   130.0,
        "μ Leo" :   124.0,   // Rasalas
        "μ Vir" :    61.0,
        "ρ Sco" :   470.0,   // Iklil
        "γ Aps" :   150.0,
        "η Cyg" :   139.0,
        "η Eri" :   137.0,   // Azha
        "η Vir" :   265.0,   // Zaniah
        "π Cen" :   320.0,
        "τ Her" :   310.0,
        "η Aql" :  1400.0,
        "ι Gru" :   185.0,
        "γ Lib" :   160.0,   // Zubenelhakrabi
        "ι Hya" :   260.0,
        "ν Tau" :   117.0,
        "σ Cen" :   410.0,
        "α Equ" :   190.0,   // Kitalpha
        "ε Her" :   155.0,
        "ζ Phe" :   280.0,   // Wurren
        "α Mon" :   144.0,
        "ν Eri" :   560.0,
        "ρ Sgr" :   122.0,
        "δ Cnc" :   130.0,   // Asellus Australis
        "ι Leo" :    79.0,
        "κ Phe" :    77.0,
        "ν Cyg" :   375.0,
        "δ Phe" :   142.0,
        "ζ Vol" :   134.0,
        "λ Peg" :   395.0,
        "ν CMa" :    64.0,
        "τ Per" :   250.0,
        "χ Lup" :   200.0,
        "ε Pav" :   105.0,
        "η Col" :   530.0,
        "κ CMa" :   660.0,
        "ρ Cen" :   345.0,
        "ω Sco" :   470.0,
        "α Sgr" :   182.0,   // Rukbat
        "β Pyx" :   420.0,
        "δ Gru" :   300.0,
        "ν Aur" :   215.0,
        "γ Mon" :   500.0,
        "δ Vol" :   660.0,
        "γ Tuc" :    75.0,
        "α Vol" :   125.0,
        "υ Cet" :   300.0,
    ]
}
