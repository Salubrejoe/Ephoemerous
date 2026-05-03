// MARK: - Known Star Data
extension EStar {
    var properName: String? { Self.properNames[name] }
    var distanceLY: Double?  { Self.distances[name]  }
    var displayName: String  { properName ?? name    }

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

    // Distances in light-years (Hipparcos / Gaia DR2)
    private static let distances: [String: Double] = [
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
}
