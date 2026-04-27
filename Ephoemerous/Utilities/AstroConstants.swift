import SwiftUI

// MARK: - All astronomical constants in one place.
// Sources: Meeus "Astronomical Algorithms" 2nd ed., IAU 1976/2006, VSOP87.
//
// Design rule:
//   • True angles (obliquity, base angles, etc.) → Angle, so callers get
//     both .degrees and .radians for free without manual conversion.
//   • Polynomial *rates* (e.g. 481267.88123421 °/century) stay Double —
//     they are only angles after multiplying by T, which happens at call site.
//   • VSOP87 amplitude/phase/frequency terms stay Double — they are
//     dimensionless coefficients combined at call site.
//   • Rendering scalars stay Double.

enum AstroConstants {

    // -------------------------------------------------------------------------
    // MARK: Obliquity of the ecliptic (J2000.0)
    // -------------------------------------------------------------------------
    /// Mean obliquity ε at J2000.0 (Meeus §22)
    static let obliquity:         Angle = .degrees(23.4393)
    static let arcticCircle:      Angle = .degrees(66.5607)   // = 90° − ε
    static let antarcticCircle:   Angle = .degrees(-66.5607)
    static let tropicCancer:      Angle = .degrees(23.4393)   // = ε
    static let tropicCapricorn:   Angle = .degrees(-23.4393)  // = −ε

    // -------------------------------------------------------------------------
    // MARK: Julian date arithmetic
    // -------------------------------------------------------------------------
    /// Julian date of Unix epoch (1970-01-01 00:00 UTC)
    static let julianUnixEpoch:       Double = 2_440_587.5
    /// Julian date of J2000.0 (2000-01-01 12:00 TT)
    static let julianJ2000:           Double = 2_451_545.0
    /// Julian days per Julian century
    static let julianDaysPerCentury:  Double = 36_525.0
    /// Seconds per Julian day
    static let secondsPerDay:         Double = 86_400.0
    /// Sidereal / solar day ratio
    static let siderealRatio:         Double = 1.00273790935

    // -------------------------------------------------------------------------
    // MARK: GMST polynomial (IAU 1982, seconds of time)
    // -------------------------------------------------------------------------
    static let gmst_c0: Double =    24_110.54841
    static let gmst_c1: Double = 8_640_184.812866
    static let gmst_c2: Double =         0.093104
    static let gmst_c3: Double =        -6.2e-6

    // -------------------------------------------------------------------------
    // MARK: IAU 1976 precession constants (arc-seconds × k → radians at use site)
    // -------------------------------------------------------------------------
    static let prec_zeta_c0:  Double = 2306.2181
    static let prec_zeta_c1:  Double =    1.39656
    static let prec_zeta_c2:  Double =   -0.000139
    static let prec_zeta_c3:  Double =    0.30188
    static let prec_zeta_c4:  Double =   -0.000344
    static let prec_zeta_c5:  Double =    0.017998

    static let prec_z_c3:     Double =    1.09468
    static let prec_z_c4:     Double =    0.000066
    static let prec_z_c5:     Double =    0.018203

    static let prec_theta_c0: Double = 2004.3109
    static let prec_theta_c1: Double =   -0.85330
    static let prec_theta_c2: Double =   -0.000217   // also used for c4
    static let prec_theta_c3: Double =   -0.42665
    static let prec_theta_c5: Double =   -0.041775

    // -------------------------------------------------------------------------
    // MARK: Sun — Meeus §25 low-precision
    // Base angles are Angle; polynomial rates stay Double (°/century).
    // -------------------------------------------------------------------------
    /// Geometric mean longitude L₀ base
    static let sun_L0_base:       Angle  = .degrees(280.46646)
    static let sun_L0_c1:         Double =  36_000.76983   // °/century
    static let sun_L0_c2:         Double =       0.0003032 // °/century²

    /// Mean anomaly M base
    static let sun_M_base:        Angle  = .degrees(357.52911)
    static let sun_M_c1:          Double =  35_999.05029   // °/century
    static let sun_M_c2:          Double =      -0.0001537 // °/century²

    /// Equation of centre coefficients (all in degrees)
    static let sun_C1_c0:         Double =   1.914602
    static let sun_C1_c1:         Double =  -0.004817
    static let sun_C1_c2:         Double =  -0.000014
    static let sun_C2_c0:         Double =   0.019993
    static let sun_C2_c1:         Double =  -0.000101
    static let sun_C3:            Double =   0.000289

    /// Omega — ascending node of Moon's orbit (for aberration/nutation)
    static let sun_omega_base:    Angle  = .degrees(125.04)
    static let sun_omega_c1:      Double = -1_934.136     // °/century
    static let sun_aberration:    Double = -0.00569       // degrees
    static let sun_nutation:      Double = -0.00478       // degrees (× sin ω)

    // -------------------------------------------------------------------------
    // MARK: Moon — Meeus §47 low-precision
    // Base angles are Angle; rates stay Double (°/century).
    // -------------------------------------------------------------------------
    /// Mean longitude L₀
    static let moon_L0_base:      Angle  = .degrees(218.3164477)
    static let moon_L0_c1:        Double = 481_267.88123421  // °/century

    /// Mean anomaly M (Moon)
    static let moon_M_base:       Angle  = .degrees(134.9633964)
    static let moon_M_c1:         Double = 477_198.8676313   // °/century

    /// Sun's mean anomaly Ms
    static let moon_Ms_base:      Angle  = .degrees(357.5291092)
    static let moon_Ms_c1:        Double =  35_999.0502909   // °/century

    /// Argument of latitude F
    static let moon_F_base:       Angle  = .degrees(93.2720950)
    static let moon_F_c1:         Double = 483_202.0175233   // °/century

    /// Elongation D
    static let moon_D_base:       Angle  = .degrees(297.8501921)
    static let moon_D_c1:         Double = 445_267.1114034   // °/century

    /// Longitude perturbation amplitudes (degrees)
    static let moon_lam_ev:       Double = 6.288774   // evection
    static let moon_lam_var:      Double = 1.274027   // variation
    static let moon_lam_ann:      Double = 0.658314   // annual equation
    static let moon_lam_A3:       Double = 0.213618
    static let moon_lam_A4:       Double = 0.185116
    static let moon_lam_A5:       Double = 0.114332
    static let moon_lam_A6:       Double = 0.058793
    static let moon_lam_A7:       Double = 0.057066
    static let moon_lam_A8:       Double = 0.053322
    static let moon_lam_A9:       Double = 0.045758
    static let moon_lam_A10:      Double = 0.040923
    static let moon_lam_A11:      Double = 0.034720
    static let moon_lam_A12:      Double = 0.030383

    /// Latitude perturbation amplitudes (degrees)
    static let moon_bet_B1:       Double = 5.128122
    static let moon_bet_B2:       Double = 0.280602
    static let moon_bet_B3:       Double = 0.277693
    static let moon_bet_B4:       Double = 0.173237
    static let moon_bet_B5:       Double = 0.055413
    static let moon_bet_B6:       Double = 0.046271
    static let moon_bet_B7:       Double = 0.032573

    /// Illuminated-fraction phase-angle coefficients (degrees)
    static let moon_phase_c1:     Double = 6.289
    static let moon_phase_c2:     Double = 2.100
    static let moon_phase_c3:     Double = 1.274
    static let moon_phase_c4:     Double = 0.658
    static let moon_phase_c5:     Double = 0.214
    static let moon_phase_c6:     Double = 0.110

    // -------------------------------------------------------------------------
    // MARK: Planets — VSOP87 truncated (Meeus Ch 31–37)
    // All amplitude/phase/frequency terms are dimensionless Double coefficients.
    // VSOP L sums are multiplied by vsop_scale after summation.
    // -------------------------------------------------------------------------
    static let vsop_scale:        Double = 1e-8

    // --- Earth ---
    static let earth_L0_A0:  Double = 175_347_046.0
    static let earth_L0_A1:  Double =   3_341_656.0;  static let earth_L0_P1: Double = 4.6709623;  static let earth_L0_F1: Double =  6_283.0758500
    static let earth_L0_A2:  Double =      34_894.0;  static let earth_L0_P2: Double = 4.62610;    static let earth_L0_F2: Double = 12_566.15170
    static let earth_L1_A0:  Double = 628_331_966_747.0
    static let earth_L1_A1:  Double =       206_059.0; static let earth_L1_P1: Double = 2.678235;   static let earth_L1_F1: Double = 6_283.07585
    static let earth_R0_A0:  Double = 100_013_989.0
    static let earth_R0_A1:  Double =   1_670_700.0;  static let earth_R0_P1: Double = 3.0984635;  static let earth_R0_F1: Double = 6_283.0758500

    // --- Mercury ---
    static let mercury_L_A0: Double = 440_250_710.0
    static let mercury_L_A1: Double =  40_989_415.0;  static let mercury_L_P1: Double = 1.4864338;  static let mercury_L_F1: Double = 26_087.9031416
    static let mercury_L_A2: Double =   5_046_294.0;  static let mercury_L_P2: Double = 4.4778549;  static let mercury_L_F2: Double = 52_175.8062831
    static let mercury_R_A0: Double =  39_528_272.0;  static let mercury_R_A1: Double = 7_834_132.0; static let mercury_R_P1: Double = 6.1923372

    // --- Venus ---
    static let venus_L_A0:   Double = 317_614_667.0
    static let venus_L_A1:   Double =   1_353_968.0;  static let venus_L_P1: Double = 5.5931332;    static let venus_L_F1: Double = 10_213.2855462
    static let venus_R_A0:   Double =  72_334_821.0;  static let venus_R_A1: Double =   489_824.0;   static let venus_R_P1: Double = 4.021518

    // --- Mars ---
    static let mars_L_A0:    Double = 1_223_514_352.0
    static let mars_L_A1:    Double =    40_660_012.0; static let mars_L_P1: Double = 6.0538088;    static let mars_L_F1: Double = 3_340.6124267
    static let mars_R_A0:    Double =   152_699_551.0; static let mars_R_A1: Double = 14_184_953.0; static let mars_R_P1: Double = 3.47971284

    // --- Jupiter ---
    static let jupiter_L_A0: Double =   599_471_033.0
    static let jupiter_L_A1: Double =    52_993_480.0; static let jupiter_L_P1: Double = 0.2467248; static let jupiter_L_F1: Double = 529.6909651
    static let jupiter_R_A0: Double =   520_887_429.0; static let jupiter_R_A1: Double = 25_209_327.0; static let jupiter_R_P1: Double = 3.49108289

    // --- Saturn ---
    static let saturn_L_A0:  Double =   874_016_757.0
    static let saturn_L_A1:  Double =    21_413_299.0; static let saturn_L_P1: Double = 3.2411768;  static let saturn_L_F1: Double = 213.2990954
    static let saturn_R_A0:  Double =   955_758_136.0; static let saturn_R_A1: Double = 52_921_382.0; static let saturn_R_P1: Double = 2.39226220

    // --- Uranus ---
    static let uranus_L_A0:  Double =   548_129_294.0
    static let uranus_L_A1:  Double =     7_502_543.0; static let uranus_L_P1: Double = 6.1580358;  static let uranus_L_F1: Double = 74.7815986
    static let uranus_R_A0:  Double = 1_922_879_639.0; static let uranus_R_A1: Double = 88_784_984.0; static let uranus_R_P1: Double = 5.60737913

    // --- Neptune ---
    static let neptune_L_A0: Double =   531_188_633.0
    static let neptune_L_A1: Double =     3_606_985.0; static let neptune_L_P1: Double = 4.4400216; static let neptune_L_F1: Double = 38.1330356
    static let neptune_R_A0: Double = 3_007_013_205.0; static let neptune_R_A1: Double = 27_062_259.0; static let neptune_R_P1: Double = 5.24270

    // -------------------------------------------------------------------------
    // MARK: Rendering / display
    // -------------------------------------------------------------------------
    /// Canvas star dot: max(dotMinR, (dotScale − mag) × dotFactor) / 2
    static let dotMinRadius:      Double = 0.6
    static let dotScale:          Double = 6.0
    static let dotFactor:         Double = 0.55
    /// Twinkle animation
    static let twinkleAmplitude:  Double = 0.2
    static let twinkleFrequency:  Double = 2.5
    static let twinklePhaseRA:    Double = 17.3
    static let twinklePhaseDec:   Double =  7.9
    /// Planet dot: max(planetDotMinR, (planetDotScale − baseMag) × planetDotFactor) / 2
    static let planetDotScale:    Double = 5.0
    static let planetDotFactor:   Double = 0.55
    static let planetDotMinR:     Double = 1.5
    static let planetGlowRatio:   Double = 3.0   // glowR = r × ratio
    /// Moon canvas dot
    static let moonBaseRadius:    Double = 5.0
    static let moonGlowRatio:     Double = 3.5   // glowR = base × ratio
    static let moonGlowOpacity:   Double = 0.25  // scaled by illumination fraction
    static let moonLimbOpacity:   Double = 0.92  // lit hemisphere fill
    static let moonRimOpacity:    Double = 0.40  // stroke
    /// Sun canvas disc diameter
    static let sunDiscDiameter:   Double = 20.0
    /// List row dot: max(listDotMin, min(listDotMax, (listDotScale − mag) × listFactor))
    static let listDotMin:        Double =  4.0
    static let listDotMax:        Double = 14.0
    static let listDotScale:      Double =  6.5
    static let listDotFactor:     Double =  2.2
    /// Detail view hero dot
    static let detailDotMin:      Double = 10.0
    static let detailDotMax:      Double = 28.0
    static let detailDotFactor:   Double =  4.5
    /// Magnitude filter
    static let defaultMagCap:     Double =  6.5
    static let magRangeMin:       Double = -2.0
    static let magRangeMax:       Double =  8.0
}
