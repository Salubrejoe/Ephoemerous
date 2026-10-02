import Foundation
import Observation
import UIKit

// MARK: - HeroSource
// One hand-picked photograph per solar-system body, shown as the body
// itself in its rendered hero sky (see `HeroBanner`). Picked, not searched:
// NASA's library answers "Saturn" with diagrams before photographs, so each
// body names the exact frame it wears. Every pick is a body on black; the
// store cuts the black away so the body sits straight on our sky.
//
// Licensing: NASA imagery is not copyrighted and may be used commercially,
// provided nothing implies NASA endorses the app and no NASA insignia is
// shown — these are plain science photographs, each with its credit line
// shown under the title. Spacecraft and stars wear no photo.
struct HeroSource {

    /// How much of the frame the body fills, so it can be sized exactly.
    enum Fit {
        /// A disc covering this fraction of the image's SHORTER side.
        case disc(Double)
        /// Saturn: its rings span this fraction of the image's width.
        case rings(Double)
    }

    let url:    URL
    /// Shown under the title, as the licence asks.
    let credit: String
    let fit:    Fit
    /// Unit-space crop applied after download (x, y, width, height), for
    /// frames that hold more than one picture or carry a caption.
    var crop:   CGRect? = nil

    static func nasa(_ id: String, _ rendition: String, credit: String, fit: Fit, crop: CGRect? = nil) -> HeroSource {
        HeroSource(url:    URL(string: "https://images-assets.nasa.gov/image/\(id)/\(id)~\(rendition).jpg")!,
                   credit: credit,
                   fit:    fit,
                   crop:   crop)
    }

    /// The photo of the body itself, or nil for everything that has none.
    /// Fits were measured from each frame's pixels.
    static func photo(for object: SkyObject) -> HeroSource? {
        switch object {
        case .sun:  return .nasa("PIA18167",  "orig",  credit: "NASA/SDO", fit: .disc(0.80),
                                 crop: CGRect(x: 0, y: 0, width: 1, height: 0.9))     // trim the caption strip
        case .moon: return .nasa("S90-55757", "large", credit: "NASA/JPL (Galileo)", fit: .disc(0.91))
        case .planet(let p):
            switch p.name {
            case Strings.Planets.mercury: return .nasa("PIA15162", "large",  credit: "NASA/JHUAPL/Carnegie Institution of Washington", fit: .disc(0.91))
            case Strings.Planets.venus:   return .nasa("PIA23791", "orig",   credit: "NASA/JPL-Caltech", fit: .disc(0.99),
                                                        crop: CGRect(x: 0.515, y: 0, width: 0.485, height: 1))
            case Strings.Planets.mars:    return .nasa("PIA00407", "large",  credit: "NASA/JPL/USGS", fit: .disc(1.0))
            case Strings.Planets.jupiter: return .nasa("PIA02873", "orig",   credit: "NASA/JPL/University of Arizona", fit: .disc(0.90))
            case Strings.Planets.saturn:  return .nasa("PIA21345", "orig",   credit: "NASA/JPL-Caltech/Space Science Institute", fit: .rings(0.93))
            case Strings.Planets.uranus:  return .nasa("PIA18182", "medium", credit: "NASA/JPL-Caltech", fit: .disc(0.80))
            case Strings.Planets.neptune: return .nasa("PIA01492", "large",  credit: "NASA/JPL", fit: .disc(0.84))
            default:                      return nil
            }
        case .star, .constellation, .spacecraft:
            return nil
        }
    }
}

// MARK: - HeroImageStore
// Fetches each hero photo once and keeps it: in memory for the session, on
// disk (Caches) across launches, so a header that has been seen works
// offline. One request per body, ever — until the system purges Caches.
//
// Each photo is CUT OUT on arrival: scaled down to the small size it's
// shown at, and its black sky turned transparent (alpha ramps up with
// brightness just above black), so the body sits on the rendered sky with
// no box around it — no blend mode to depend on.
@Observable
final class HeroImageStore {

    static let shared = HeroImageStore()

    enum Status { case loading, ready(UIImage), unavailable }

    private(set) var status: [String: Status] = [:]

    /// Longest side a cut-out keeps — far more than a hero ever shows.
    private static let cutoutSide: CGFloat = 480

    private init() {}

    func status(for object: SkyObject) -> Status {
        status[object.id] ?? .loading
    }

    /// Loads the object's photo if it has one and it isn't loaded yet.
    @MainActor
    func load(_ object: SkyObject) async {
        guard let source = HeroSource.photo(for: object) else { return }
        if case .ready = status[object.id] { return }
        status[object.id] = .loading
        let file = Self.cacheURL(for: object)
        if let cached = try? Data(contentsOf: file), let image = UIImage(data: cached) {
            status[object.id] = .ready(image)
            return
        }
        guard let data   = await Self.fetch(source.url),
              let photo  = UIImage(data: data),
              let cutout = Self.cutout(photo, crop: source.crop)
        else {
            status[object.id] = .unavailable
            return
        }
        try? cutout.pngData()?.write(to: file, options: .atomic)
        status[object.id] = .ready(cutout)
    }

    // MARK: Plumbing

    private static func fetch(_ url: URL) async -> Data? {
        let request = URLRequest(url: url, timeoutInterval: 30)
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return data
    }

    private static func cacheURL(for object: SkyObject) -> URL {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HeroCutouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let safe = object.id.replacingOccurrences(of: "/", with: "_")
        return dir.appendingPathComponent("\(safe).png")
    }

    /// Crop, scale down, and make the black sky transparent.
    private static func cutout(_ photo: UIImage, crop unit: CGRect?) -> UIImage? {
        guard var cg = photo.cgImage else { return nil }
        if let unit {
            let w = CGFloat(cg.width), h = CGFloat(cg.height)
            let rect = CGRect(x: unit.minX * w, y: unit.minY * h, width: unit.width * w, height: unit.height * h).integral
            guard let part = cg.cropping(to: rect) else { return nil }
            cg = part
        }
        let scale  = min(1, cutoutSide / CGFloat(max(cg.width, cg.height)))
        let width  = max(1, Int(CGFloat(cg.width)  * scale))
        let height = max(1, Int(CGFloat(cg.height) * scale))
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let buffer = ctx.data
        else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Alpha from brightness: true black → clear, anything a little above
        // the sky's noise floor → fully opaque. Premultiplied, so colour
        // scales with alpha.
        let px = buffer.bindMemory(to: UInt8.self, capacity: width * height * 4)
        let floor = 10.0, full = 34.0
        for i in stride(from: 0, to: width * height * 4, by: 4) {
            let lum   = 0.299 * Double(px[i]) + 0.587 * Double(px[i + 1]) + 0.114 * Double(px[i + 2])
            let alpha = min(1, max(0, (lum - floor) / (full - floor)))
            px[i]     = UInt8(Double(px[i])     * alpha)
            px[i + 1] = UInt8(Double(px[i + 1]) * alpha)
            px[i + 2] = UInt8(Double(px[i + 2]) * alpha)
            px[i + 3] = UInt8(255 * alpha)
        }
        guard let out = ctx.makeImage() else { return nil }
        return UIImage(cgImage: out)
    }
}
