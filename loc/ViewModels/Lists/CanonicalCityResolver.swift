//
//  CanonicalCityResolver.swift
//  loc
//
//  Pure city-boundary rule for per-city lists (mirror of Mesa-backend services/city_resolver.py; keep the
//  tables in sync). NYC boroughs/neighborhoods/ZIPs -> "New York City"; dense cities -> the city;
//  car metros (Atlanta, LA, ...) -> the metro name; NY/PA/NJ outside any city -> "Upstate NY" /
//  "Pennsylvania" / "New Jersey". Unit tested in CanonicalCityResolverTests.
//

import Foundation

enum CanonicalCityResolver {
    static let nyc = "New York City"
    static let upstateNY = "Upstate NY"
    static let longIsland = "Long Island"

    private static let stateCodes: Set<String> = [
        "AL","AK","AZ","AR","CA","CO","CT","DE","DC","FL","GA","HI","ID","IL","IN","IA","KS","KY","LA","ME","MD","MA",
        "MI","MN","MS","MO","MT","NE","NV","NH","NJ","NM","NY","NC","ND","OH","OK","OR","PA","RI","SC","SD","TN","TX",
        "UT","VT","VA","WA","WV","WI","WY"
    ]

    private static let nycLocalities: Set<String> = [
        "new york", "new york city", "nyc", "manhattan", "brooklyn", "queens", "bronx", "the bronx", "staten island",
        "flushing", "astoria", "long island city", "jackson heights", "elmhurst", "east elmhurst", "forest hills",
        "ridgewood", "sunnyside", "woodside", "corona", "jamaica", "bayside", "rego park", "kew gardens",
        "college point", "whitestone", "fresh meadows", "howard beach", "far rockaway", "rockaway beach",
        "maspeth", "middle village", "glendale", "ozone park", "richmond hill", "williamsburg", "greenpoint",
        "bushwick", "brighton beach", "coney island", "bay ridge", "sheepshead bay", "bensonhurst", "canarsie",
        "inwood", "harlem", "east harlem", "washington heights", "riverdale", "fordham", "hunts point",
        "st george", "saint george", "tottenville", "great kills", "oakland gardens", "little neck", "douglaston",
        "springfield gardens", "south ozone park", "woodhaven", "briarwood", "hollis", "rosedale", "laurelton",
        "cambria heights", "queens village", "bellerose", "arverne", "broad channel", "rockaway park",
        "belle harbor", "breezy point", "roosevelt island", "steinway", "red hook", "park slope",
        "bedford stuyvesant", "crown heights", "flatbush", "east new york", "dumbo", "carroll gardens",
        "cobble hill", "boerum hill", "fort greene", "prospect heights", "gravesend", "midwood", "marine park",
        "mill basin", "bergen beach", "borough park", "sunset park", "kensington", "windsor terrace",
        "greenwood heights", "bronxdale", "throgs neck", "city island", "pelham bay", "morris park",
        "kingsbridge", "mott haven", "longwood", "belmont"
    ]
    private static let sureNYC: Set<String> = ["new york", "new york city", "nyc", "manhattan", "brooklyn", "queens", "bronx", "the bronx", "staten island"]
    private static let ambiguousNYC: Set<String> = [
        "jamaica", "glendale", "belmont", "kensington", "richmond hill", "longwood", "corona", "hollis", "riverdale",
        "elmhurst", "whitestone", "bayside", "fordham", "inwood", "harlem", "sunnyside", "woodside", "rosedale",
        "arverne", "steinway", "midwood", "flatbush"
    ]
    private static let tokyoWards: Set<String> = [
        "chiyoda", "chuo", "minato", "shinjuku", "bunkyo", "taito", "sumida", "koto", "shinagawa", "meguro", "ota",
        "setagaya", "shibuya", "nakano", "suginami", "toshima", "kita", "arakawa", "itabashi", "nerima", "adachi",
        "katsushika", "edogawa"
    ]
    private static let nycCounties: Set<String> = ["new york county", "kings county", "queens county", "bronx county", "richmond county"]
    private static let nycZip3: Set<String> = ["100", "101", "102", "103", "104", "111", "112", "113", "114", "116"]
    private static let longIslandZip3: Set<String> = ["110", "115", "117", "118", "119"]

    /// (state, folded locality) -> display name.
    private static let denseCities: [String: String] = [
        "CA|san francisco": "San Francisco", "IL|chicago": "Chicago", "MA|boston": "Boston",
        "MA|cambridge": "Cambridge", "DC|washington": "Washington DC", "PA|philadelphia": "Philadelphia",
        "PA|pittsburgh": "Pittsburgh", "WA|seattle": "Seattle", "OR|portland": "Portland",
        "LA|new orleans": "New Orleans", "NJ|jersey city": "Jersey City", "NJ|hoboken": "Hoboken", "NJ|newark": "Newark"
    ]

    private static let metroSpecs: [(name: String, state: String, localities: [String])] = [
        ("Atlanta", "GA", ["atlanta", "decatur", "marietta", "sandy springs", "roswell", "alpharetta", "smyrna",
                           "brookhaven", "dunwoody", "east point", "college park", "kennesaw", "chamblee", "doraville",
                           "tucker", "avondale estates", "stone mountain", "lawrenceville", "duluth", "johns creek",
                           "hapeville", "clarkston", "vinings", "scottdale", "milton", "peachtree corners"]),
        ("Los Angeles", "CA", ["los angeles", "santa monica", "beverly hills", "west hollywood", "culver city",
                               "pasadena", "glendale", "burbank", "inglewood", "long beach", "venice", "hollywood",
                               "malibu", "torrance", "manhattan beach", "hermosa beach", "redondo beach", "el segundo",
                               "sherman oaks", "studio city", "encino", "north hollywood", "compton", "alhambra",
                               "van nuys", "woodland hills", "sun valley", "marina del rey", "monterey park",
                               "san gabriel", "south pasadena", "arcadia", "downey", "west los angeles"]),
        ("Houston", "TX", ["houston", "bellaire", "pasadena", "sugar land", "katy", "the woodlands", "pearland",
                           "humble", "spring", "cypress", "stafford", "missouri city", "west university place"]),
        ("Dallas", "TX", ["dallas", "plano", "irving", "richardson", "frisco", "garland", "addison", "carrollton",
                          "mckinney", "allen", "farmers branch", "grand prairie", "mesquite", "lewisville", "denton"]),
        ("Phoenix", "AZ", ["phoenix", "scottsdale", "tempe", "mesa", "chandler", "glendale", "gilbert", "peoria",
                           "paradise valley", "surprise", "goodyear", "avondale", "fountain hills"]),
        ("Salt Lake City", "UT", ["salt lake city", "murray", "sandy", "millcreek", "south salt lake", "west valley city",
                                  "midvale", "holladay", "draper", "west jordan", "south jordan", "taylorsville",
                                  "cottonwood heights", "bountiful"]),
        ("Miami", "FL", ["miami", "miami beach", "coral gables", "hialeah", "north miami", "north miami beach",
                         "key biscayne", "doral", "surfside", "bal harbour", "miami gardens", "homestead"]),
        ("Las Vegas", "NV", ["las vegas", "paradise", "henderson", "north las vegas", "spring valley", "enterprise",
                             "winchester", "sunrise manor"])
    ]
    private static let metros: [String: String] = {
        var m: [String: String] = [:]
        for spec in metroSpecs { for l in spec.localities { m["\(spec.state)|\(l)"] = spec.name } }
        return m
    }()

    private static let stateRegions: [String: String] = ["NY": upstateNY, "PA": "Pennsylvania", "NJ": "New Jersey"]

    /// Canonical list city, or nil when neither the address nor the stored city says. No network.
    static func resolve(address: String?, storedCity: String?) -> String? {
        let parsed = parse(address)
        var locality = parsed.locality
        var stored = (storedCity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if stored.hasPrefix("Greater ") { stored = String(stored.dropFirst("Greater ".count)) }
        var storedKey = SavedLibraryBuilder.foldKey(stored)
        var countyHint: String?
        if storedKey.hasSuffix(" county") { countyHint = storedKey; stored = ""; storedKey = "" }
        let isNYCName = ["new york", "new york city", "nyc"].contains(storedKey)
        if !isNYCName, SavedLibraryBuilder.usStateNames.contains(storedKey) || SavedLibraryBuilder.countryNames.contains(storedKey) {
            stored = ""; storedKey = ""
        }
        if locality == nil, !stored.isEmpty { locality = stored }
        let locKey = locality.map { SavedLibraryBuilder.foldKey($0) } ?? storedKey
        let state = parsed.state
        let zip3 = parsed.zip.flatMap { z -> String? in z.count >= 5 ? String(z.prefix(3)) : nil }

        if state == "NY" {
            if let z = zip3, longIslandZip3.contains(z) { return longIsland }
            if let z = zip3, nycZip3.contains(z) { return nyc }
            if zip3 == nil, nycLocalities.contains(locKey) || (countyHint.map { nycCounties.contains($0) } ?? false) { return nyc }
            return upstateNY
        }
        if state == nil {
            if sureNYC.contains(locKey) || (nycLocalities.contains(locKey) && !ambiguousNYC.contains(locKey)) { return nyc }
            if locKey == "washington" { return "Washington DC" }
            if locKey.hasSuffix(" city"), tokyoWards.contains(String(locKey.dropLast(5))) { return "Tokyo" }
            if let hk = ["Hong Kong", "Singapore"].first(where: { (address ?? "").localizedCaseInsensitiveContains($0) }) { return hk }
            if let a = address, a.localizedCaseInsensitiveContains("tokyo") || a.contains("東京") { return "Tokyo" }
            if locKey.hasPrefix("berlin") { return "Berlin" }
            if zip3 != nil, let z = zip3, nycZip3.contains(z) { return nyc }
            if isNYCName { return nyc }
            if parsed.hasCountry { return locality }
            return countyHint == nil ? locality : nil
        }
        if let state {
            if let d = denseCities["\(state)|\(locKey)"] { return d }
            if let m = metros["\(state)|\(locKey)"] { return m }
            if let r = stateRegions[state] { return r }
        }
        return locality
    }

    private struct Parsed {
        var locality: String?
        var state: String?
        var zip: String?
        var hasCountry = false
    }

    private static func parse(_ address: String?) -> Parsed {
        var p = Parsed()
        guard let addr = address?.trimmingCharacters(in: .whitespacesAndNewlines), !addr.isEmpty else { return p }
        let pattern = #"(?:^|,)\s*([A-Za-z .]+?),?\s+([A-Z]{2})(?:\s+(\d{5})(?:-\d{4})?)?\s*(?:,\s*(?:USA|US|United States))?\s*$"#
        if let re = try? NSRegularExpression(pattern: pattern),
           let m = re.firstMatch(in: addr, range: NSRange(addr.startIndex..., in: addr)),
           let cityR = Range(m.range(at: 1), in: addr), let stR = Range(m.range(at: 2), in: addr),
           stateCodes.contains(String(addr[stR])) {
            p.locality = String(addr[cityR]).trimmingCharacters(in: .whitespaces)
            p.state = String(addr[stR])
            if let zR = Range(m.range(at: 3), in: addr) { p.zip = String(addr[zR]) }
            p.hasCountry = true
            return p
        }
        // Non-US (or unparseable): the existing locality reader.
        p.locality = SavedLibraryBuilder.locality(fromAddress: addr)
        p.hasCountry = p.locality != nil
        if let loc = p.locality, SavedLibraryBuilder.foldKey(addr).contains("tokyo"), SavedLibraryBuilder.foldKey(loc).hasSuffix(" city") || SavedLibraryBuilder.foldKey(loc) == "tokyo" {
            p.locality = "Tokyo"
        }
        return p
    }
}
