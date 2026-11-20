//
//  PlaceTaxonomy.swift
//  loc
//
//  The data behind the list tag chips: a canonical taxonomy of specific tags (Sushi, Cocktails, Vintage Clothing,
//  Records, ...) organized under groups (Food, Drinks, Coffee & Sweets, Shopping, Culture, Outdoors, Stay,
//  Services). Each tag lists the phrases that earn it: Google snake_case types ("sushi_restaurant") and Google
//  human labels ("Sushi restaurant") normalize to the same text, so one phrase covers both. `category` phrases
//  match as whole words inside a normalized category, `exact` phrases must be the entire category, and `name`
//  phrases are a few conservative keywords matched against the place's name. The matching engine and the
//  precedence rules (primary category, family filtering) live in ListTypeFilter; unit tested in
//  PlaceTaxonomyTests and ListTypeFilterTests.
//
//  Generated from measured category frequencies across all places (see cc-logs/category_frequencies.csv).
//

import Foundation

/// The broad bucket a tag belongs to.
enum PlaceTagGroup: String, CaseIterable {
    case food = "Food"
    case drinks = "Drinks"
    case coffeeAndSweets = "Coffee & Sweets"
    case shopping = "Shopping"
    case culture = "Culture"
    case outdoors = "Outdoors"
    case stay = "Stay"
    case services = "Services"

    /// The family this group belongs to; a place only keeps tags from one family (see ListTypeFilter).
    var family: PlaceTagFamily {
        switch self {
        case .food: return .dining
        case .drinks: return .dining
        case .coffeeAndSweets: return .dining
        case .shopping: return .shopping
        case .culture: return .culture
        case .outdoors: return .outdoors
        case .stay: return .stay
        case .services: return .services
        }
    }
}

/// Groups whose tags can co-exist on one place: food, drinks and coffee & sweets are all "dining".
enum PlaceTagFamily: Hashable {
    case dining, shopping, culture, outdoors, stay, services
}

/// One tag and the phrases that earn it.
struct PlaceTagRule {
    let tag: String
    let group: PlaceTagGroup
    let category: [String]
    let exact: [String]
    let name: [String]
    /// Name-word prefixes (a word merely starting with the phrase, e.g. "SUSHIRO" for "sushi"). Keep rare.
    let namePrefix: [String]
    /// Tags this tag always brings along (Sushi implies Japanese).
    let implies: [String]
    /// Tags a category earning this rule must not also earn (Vintage Clothing suppresses Clothing).
    let suppresses: [String]

    /// Creates a rule, normalizing every phrase the same way categories and names are normalized.
    init(_ tag: String, _ group: PlaceTagGroup, category: [String] = [], exact: [String] = [], name: [String] = [],
         namePrefix: [String] = [], implies: [String] = [], suppresses: [String] = []) {
        self.tag = tag
        self.group = group
        self.category = category.map(PlaceTaxonomy.padded)
        self.exact = exact.map(PlaceTaxonomy.padded)
        self.name = name.map(PlaceTaxonomy.padded)
        self.namePrefix = namePrefix.map { PlaceTaxonomy.padded($0).trimmingCharacters(in: .whitespaces) }
        self.implies = implies
        self.suppresses = suppresses
    }
}

enum PlaceTaxonomy {
    /// Lowercased, accent-folded text with punctuation removed, wrapped in spaces so whole words match.
    static func padded(_ text: String) -> String {
        let folded = text.folding(options: .diacriticInsensitive, locale: nil).lowercased()
        let spaced = String(folded.map { $0.isLetter || $0.isNumber ? $0 : " " })
        return " " + spaced.split(separator: " ").joined(separator: " ") + " "
    }

    /// Cuisine tags that make the generic "Asian" tag redundant.
    static let specificAsianTags: Set<String> = Set(["Sushi", "Omakase", "Ramen", "Japanese", "Korean BBQ", "Korean", "Thai", "Vietnamese", "Chinese", "Indian", "Taiwanese", "Filipino", "Southeast Asian"])

    /// Generic categories that still mark a dining place when they are a place's first (primary) label.
    static let diningHints: Set<String> = Set(diningHintPhrases.map { PlaceTaxonomy.padded($0).trimmingCharacters(in: .whitespaces) })

    private static let diningHintPhrases: [String] = ["restaurant", "restaurants", "food", "meal takeaway", "meal delivery", "takeout", "delivery", "family", "caterer"]

    /// Categories that say nothing about what a place is (Google structural types, non-venue businesses,
    /// ambiguous labels); ignored. Compared after normalization.
    static let genericCategories: Set<String> = Set(genericPhrases.map { PlaceTaxonomy.padded($0).trimmingCharacters(in: .whitespaces) })

    private static let genericPhrases: [String] = [
        "academic department", "accounting", "administrative area level 1", "administrative area level 3", "adult education school",
        "after school program", "airport", "apartment building", "apartment complex", "architect", "architecture firm", "archive",
        "artist", "arts organization", "atm", "auto broker", "bank", "banquet hall", "book publisher", "bridge", "buffet", "building",
        "bus station", "bus stop", "business center", "business management consultant", "business park", "business school", "canal",
        "car dealer", "car rental", "car repair", "caterer", "catering food and drink supplier", "cemetery", "charity", "children s camp",
        "city government office", "city hall", "clothing alteration service", "college", "commercial printer", "community center",
        "community college", "computer service", "condominium complex", "conference center", "construction", "consultant",
        "convention center", "corporate office", "courthouse", "coworking space", "cultural association", "custom tailor",
        "day care center", "delivery", "delivery service", "dentist", "department of motor vehicles", "design agency",
        "digital printing service", "discount store", "doctor", "donations center", "drug store", "drugstore", "e commerce service",
        "educational", "educational institution", "electric utility company", "engineer", "engineering consultant", "entertainment agency",
        "establishment", "estate", "event planner", "event venue", "events venue", "family", "fashion designer", "fax service",
        "ferry terminal", "finance", "financial institution", "food", "food and drink", "food court", "food producer", "forestry service",
        "fraternal organization", "free parking lot", "function room facility", "funeral home", "fusion", "gas station",
        "general contractor", "general store", "geocode", "gift shop", "government office", "graphic designer", "grill", "harbor",
        "health", "higher secondary school", "homeopathic pharmacy", "hospital", "house", "housing development",
        "income tax help association", "insurance agency", "interior designer", "international airport", "internet cafe", "internist",
        "kiosk", "knife manufacturer", "laundry", "lawyer", "light rail station", "local government office", "locality", "locksmith",
        "lounge", "masonic center", "meal delivery", "meal takeaway", "meat dish", "media company", "medical center", "medical clinic",
        "medical laboratory", "meeting planning service", "military base", "mobile caterer", "moving company", "neighborhood",
        "non profit organization", "notary public", "nutritionist", "optician", "optometrist", "outdoor activity organiser", "painter",
        "parking", "parking garage", "parking lot", "performing arts group", "pet groomer", "pharmacy", "photo lab", "photographer",
        "photography service", "photography studio", "place", "plumber", "point of interest", "police", "political", "portrait studio",
        "post office", "postal code", "premise", "preschool", "print shop", "private hospital", "private university", "publisher",
        "railroad company", "real estate agency", "rehabilitation center", "religious school", "restaurant", "retirement home", "rice",
        "route", "school", "self service", "senior citizen center", "shipping service", "sign shop", "small plates", "social club",
        "social services organization", "soup", "souvenir", "storage", "store", "street address", "subpremise", "subway station",
        "summer camp organizer", "supplier", "takeaway", "takeout", "talent agency", "tax preparation", "tenant ownership",
        "tour operator", "tourist attraction", "town square", "train depot", "train station", "training center", "transit",
        "transit station", "transport hub", "transportation service", "travel agency", "truck dealer", "university", "used car dealer",
        "used truck dealer", "variety store", "veterinarian", "veterinary care", "visitor center", "volunteer organization", "wedding",
        "wedding buffet", "wedding planner", "wedding venue", "wellness program", "wholesaler", "wi fi spot"
    ]

    /// Tags in display-priority order (a place's tags are listed in this order).
    static let rules: [PlaceTagRule] = [
        // MARK: Food
        PlaceTagRule("Sushi", .food, category: ["sushi"], name: ["sushi"], namePrefix: ["sushi"], implies: ["Japanese"]),
        PlaceTagRule("Omakase", .food, category: ["omakase"], name: ["omakase"], implies: ["Japanese"]),
        PlaceTagRule("Ramen", .food, category: ["ramen"], name: ["ramen"], implies: ["Japanese"]),
        PlaceTagRule("Japanese", .food,
                     category: [
                         "japanese", "izakaya", "yakitori", "tempura", "udon", "soba", "tonkatsu", "katsudon", "kaiseki", "ryotei", "yakiniku",
                         "teppanyaki", "unagi", "fugu", "takoyaki", "gyudon", "shabu shabu", "sukiyaki", "kushiyaki", "syokudo", "teishoku",
                         "okonomiyaki", "donburi", "japanized"
                     ],
                     exact: ["日式乡土料理餐馆", "食堂和定食餐馆", "和食店", "定食屋", "일본 음식점", "야키니쿠 전문식당", "스시/초밥집"],
                     name: ["japanese", "izakaya", "yakitori"]),
        PlaceTagRule("Korean BBQ", .food, category: ["korean barbecue", "korean bbq"], name: ["kbbq", "korean bbq"], implies: ["Korean"]),
        PlaceTagRule("Korean", .food, category: ["korean", "seolleongtang"], name: ["korean"]),
        PlaceTagRule("Thai", .food, category: ["thai"], exact: ["สแน็คบาร์"], name: ["thai"]),
        PlaceTagRule("Vietnamese", .food, category: ["vietnamese", "pho"], name: ["vietnamese", "pho"]),
        PlaceTagRule("Chinese", .food,
                     category: [
                         "chinese", "dim sum", "dumpling", "szechuan", "sichuan", "cantonese", "shanghainese", "mandarin", "fujian",
                         "hong kong", "wok", "offal pot cooking", "cha chaan teng"
                     ],
                     exact: ["中餐馆", "中式点心餐馆", "上海风味餐馆", "川菜馆", "中国面馆", "面馆", "中菜館", "四川酒家", "台灣餐廳", "提供配送服务的中餐馆", "小吃店"],
                     name: ["dim sum", "dumpling", "dumplings"]),
        PlaceTagRule("Taiwanese", .food, category: ["taiwanese"], name: ["taiwanese"]),
        PlaceTagRule("Filipino", .food, category: ["filipino"], name: ["filipino"]),
        PlaceTagRule("Southeast Asian", .food,
                     category: ["southeast asian", "malaysian", "singaporean", "cambodian", "laotian", "indonesian", "nyonya", "burmese", "hawker"],
                     name: ["malaysian", "singaporean"]),
        PlaceTagRule("Mexican", .food,
                     category: ["mexican", "taco", "tacos", "taqueria", "burrito", "tex mex", "tortilla"],
                     name: ["taqueria", "taco", "tacos", "burrito"]),
        PlaceTagRule("Italian", .food,
                     category: ["italian", "trattoria", "osteria", "neapolitan", "tuscan", "roman"],
                     name: ["trattoria", "osteria", "italian"]),
        PlaceTagRule("Pizza", .food, category: ["pizza", "pizzeria"], name: ["pizza", "pizzeria"]),
        PlaceTagRule("French", .food, category: ["french", "bistro", "brasserie", "creperie"], name: ["bistro", "brasserie"]),
        PlaceTagRule("Indian", .food,
                     category: ["indian", "biryani", "punjabi", "rajasthani", "south asian", "pakistani", "nepalese", "sri lankan"],
                     name: ["indian"]),
        PlaceTagRule("Israeli", .food, category: ["israeli"], name: ["israeli"]),
        PlaceTagRule("Middle Eastern", .food,
                     category: [
                         "middle eastern", "lebanese", "turkish", "falafel", "kebab", "shawarma", "persian", "syrian", "arab", "afghan",
                         "armenian", "egyptian", "gyro", "sfiha", "doner", "uzbeki"
                     ],
                     name: ["falafel", "kebab", "shawarma"]),
        PlaceTagRule("Mediterranean", .food, category: ["mediterranean"], name: ["mediterranean"]),
        PlaceTagRule("American", .food,
                     category: ["cajun", "creole", "soul food", "country food"],
                     exact: [
                         "american", "new american", "traditional american", "modern american", "contemporary american", "hawaiian",
                         "californian", "floridian", "new england", "southern us", "southwestern us", "mid atlantic us"
                     ]),
        PlaceTagRule("Asian", .food, exact: ["asian", "pan asian", "asian fusion", "tibetan"]),
        PlaceTagRule("Greek", .food, category: ["greek"], name: ["greek"]),
        PlaceTagRule("Spanish", .food,
                     category: ["spanish", "tapas", "andalusian", "catalonian", "basque", "castilian", "churreria"],
                     name: ["tapas"]),
        PlaceTagRule("Latin American", .food,
                     category: [
                         "latin american", "south american", "central american", "peruvian", "brazilian", "argentinian", "colombian",
                         "ecuadorian", "chilean", "venezuelan", "salvadoran", "nuevo latino"
                     ]),
        PlaceTagRule("Caribbean", .food, category: ["caribbean", "jamaican", "cuban", "dominican", "puerto rican", "haitian"]),
        PlaceTagRule("African", .food, category: ["african", "ethiopian", "nigerian", "moroccan", "senegalese"]),
        PlaceTagRule("European", .food,
                     category: [
                         "european", "german", "british", "scandinavian", "danish", "swedish", "polish", "russian", "ukrainian", "hungarian",
                         "austrian", "swiss", "georgian", "serbian", "croatian", "portuguese", "continental"
                     ],
                     exact: ["irish", "western"]),
        PlaceTagRule("Steak", .food, category: ["steak house", "steakhouse", "steak", "chophouse"], name: ["steakhouse", "steak house"]),
        PlaceTagRule("Seafood", .food,
                     category: ["seafood", "oyster", "crab house", "fish", "fish chips", "oyster bar"],
                     name: ["seafood", "oyster", "oysters"]),
        PlaceTagRule("BBQ", .food, category: ["barbecue", "bbq", "smokehouse"], name: ["barbecue", "bbq"]),
        PlaceTagRule("Burgers", .food, category: ["burger", "burgers", "hamburger"], name: ["burger", "burgers"]),
        PlaceTagRule("Sandwiches", .food,
                     category: ["sandwich", "sandwiches", "deli", "delicatessen", "cheesesteak", "hoagie", "sub shop"],
                     name: ["sandwich", "sandwiches", "deli"]),
        PlaceTagRule("Fast Food", .food, category: ["fast food", "hot dog", "snack bar"]),
        PlaceTagRule("Noodles", .food, category: ["noodle", "noodles"], name: ["noodle", "noodles"]),
        PlaceTagRule("Hot Pot", .food, category: ["hot pot", "hotpot"], name: ["hot pot", "hotpot"]),
        PlaceTagRule("Vegan", .food, category: ["vegan", "vegetarian"], name: ["vegan"]),
        PlaceTagRule("Healthy", .food, category: ["salad", "health food", "organic", "raw food", "gluten free"]),
        PlaceTagRule("Halal", .food, category: ["halal"], name: ["halal"]),
        PlaceTagRule("Kosher", .food, category: ["kosher"], name: ["kosher"]),
        PlaceTagRule("Diner", .food, category: ["diner", "pancake", "cafeteria"], name: ["diner"]),
        PlaceTagRule("Brunch", .food, category: ["brunch", "breakfast"], name: ["brunch"]),
        PlaceTagRule("Lunch", .food, category: ["lunch"], exact: ["食堂"]),
        PlaceTagRule("Fine Dining", .food, category: ["fine dining", "haute"]),
        PlaceTagRule("Chicken", .food, category: ["chicken", "wings"], name: ["fried chicken"]),
        // MARK: Coffee & Sweets
        PlaceTagRule("Bakery", .coffeeAndSweets,
                     category: ["bakery", "patisserie", "bagel", "bagels", "pastry", "pastries", "pie shop", "pretzel", "croissant"],
                     name: ["bakery", "patisserie", "boulangerie", "bagel", "bagels"]),
        PlaceTagRule("Dessert", .coffeeAndSweets,
                     category: [
                         "dessert", "candy", "chocolate", "confectionery", "confectionary", "cake shop", "cupcake", "cookie", "donut",
                         "doughnut", "sundae", "rice cake", "popcorn", "fruit parlor"
                     ],
                     name: ["dessert", "desserts"]),
        PlaceTagRule("Ice Cream", .coffeeAndSweets,
                     category: ["ice cream", "gelato", "frozen yogurt", "frozen custard"],
                     name: ["ice cream", "gelato", "creamery"]),
        PlaceTagRule("Coffee", .coffeeAndSweets,
                     category: ["coffee", "cafe", "espresso", "kissaten"],
                     exact: ["カフェ・喫茶"],
                     name: ["coffee", "espresso", "roasters", "roastery", "cafe"]),
        PlaceTagRule("Matcha", .coffeeAndSweets, category: ["matcha"], name: ["matcha"]),
        PlaceTagRule("Tea", .coffeeAndSweets,
                     category: ["tea house", "tea store", "tea room", "tea shop", "bubble tea", "boba", "tea market place"],
                     name: ["tea house", "teahouse"]),
        PlaceTagRule("Juice Bar", .coffeeAndSweets, category: ["juice bar", "juice shop", "smoothie", "acai", "soft drinks"], name: ["juice bar"]),
        // MARK: Drinks
        PlaceTagRule("Natural Wine", .drinks, category: ["natural wine"], name: ["natural wine"], implies: ["Wine Bar"]),
        PlaceTagRule("Wine Bar", .drinks, category: ["wine bar", "enoteca", "vinoteca"], name: ["wine bar", "vino"]),
        PlaceTagRule("Cocktails", .drinks,
                     category: ["cocktail", "cocktails", "speakeasy", "tiki bar", "mixology"],
                     name: ["cocktail", "cocktails", "speakeasy"]),
        PlaceTagRule("Brewery", .drinks,
                     category: ["brewery", "brewpub", "microbrewery", "beer garden", "beer hall", "taproom", "craft beer"],
                     exact: ["beer"],
                     name: ["brewery", "brewing", "brewpub"]),
        PlaceTagRule("Winery", .drinks, category: ["winery", "vineyard", "distillery", "cider mill"], name: ["winery", "distillery"]),
        PlaceTagRule("Nightclub", .drinks, category: ["night club", "nightclub", "dance club", "disco club"], exact: ["club"], implies: ["Bar"]),
        PlaceTagRule("Bar", .drinks,
                     exact: [
                         "bar", "bars", "pub", "gastropub", "irish pub", "lounge bar", "sports bar", "dive bar", "tavern", "saloon",
                         "bar grill", "bar and grill", "live music bar", "hookah bar", "dart bar", "cider bar", "tapas bar", "酒吧"
                     ],
                     name: ["pub"]),
        // MARK: Shopping
        PlaceTagRule("Vintage Clothing", .shopping,
                     category: [
                         "vintage clothing", "vintage", "used clothing", "second hand store", "second hand clothing", "second hand shop",
                         "secondhand", "thrift store", "thrift shop", "consignment", "resale"
                     ],
                     exact: ["古着屋", "thrift"],
                     name: ["vintage", "thrift", "consignment", "secondhand"],
                     suppresses: ["Clothing"]),
        PlaceTagRule("Clothing", .shopping,
                     category: [
                         "clothing store", "clothing shop", "clothing", "apparel", "boutique", "menswear", "womenswear", "outerwear",
                         "sportswear", "swimwear", "work clothes", "tailor", "tuxedo"
                     ],
                     exact: ["服装店", "服裝店", "衣料品店", "fashion"]),
        PlaceTagRule("Shoes", .shopping, category: ["shoe store", "shoe shop", "boot store", "shoes"]),
        PlaceTagRule("Jewelry", .shopping, category: ["jewelry", "jeweler", "jewellery"], name: ["jewelry"]),
        PlaceTagRule("Bags & Accessories", .shopping,
                     category: [
                         "fashion accessories", "bag shop", "handbags", "handbag", "luggage", "hat shop", "belt shop", "watch store",
                         "sunglasses", "leather goods", "leather coats", "saddlery", "wig shop"
                     ]),
        PlaceTagRule("Antiques", .shopping,
                     category: ["antique", "antiques", "collectibles", "flea market", "estate liquidator", "memorabilia", "stamp shop"],
                     name: ["antique", "antiques"]),
        PlaceTagRule("Furniture", .shopping,
                     category: [
                         "furniture store", "furniture shop", "furniture accessories", "home furniture", "used furniture",
                         "used office furniture", "upholstery", "carpet store", "rug store"
                     ],
                     name: ["furniture"]),
        PlaceTagRule("Home Goods", .shopping,
                     category: [
                         "home goods", "household goods", "homeware", "home decor", "kitchen supply", "candle store", "lighting", "knife store",
                         "mexican goods", "oriental goods"
                     ],
                     exact: ["家居用品店"]),
        PlaceTagRule("Hardware", .shopping,
                     category: [
                         "hardware store", "home improvement", "paint store", "electrical supply", "tool store", "flooring", "do it yourself",
                         "countertop store"
                     ]),
        PlaceTagRule("Books", .shopping,
                     category: ["book store", "bookstore", "book shop", "bookshop", "magazine store"],
                     name: ["bookstore", "bookshop", "book store"]),
        PlaceTagRule("Records", .shopping,
                     category: ["record store", "record shop", "vinyl", "cd store"],
                     name: ["record store", "record shop", "records"]),
        PlaceTagRule("Art Supplies", .shopping,
                     category: [
                         "art supply", "art supplies", "craft store", "hobby store", "yarn store", "needlework", "stationery", "school supply",
                         "picture frame", "greeting card", "poster store", "handicraft"
                     ]),
        PlaceTagRule("Flowers", .shopping,
                     category: ["florist", "flower market", "flower designer", "plant nursery", "garden center"],
                     name: ["florist"]),
        PlaceTagRule("Wine Shop", .shopping,
                     category: [
                         "wine store", "wine shop", "liquor store", "bottle shop", "beer store", "wine cellar", "wine wholesaler",
                         "alcoholic beverage", "wine club"
                     ],
                     name: ["wine shop", "wine store", "wine merchant", "liquor"]),
        PlaceTagRule("Cheese", .shopping,
                     category: ["cheese shop", "cheese store", "fromagerie", "cheesemonger"],
                     exact: ["cheese"],
                     name: ["cheese shop", "cheesemonger"]),
        PlaceTagRule("Grocery", .shopping,
                     category: [
                         "grocery", "supermarket", "hypermarket", "convenience store", "greengrocer", "farmers market", "fresh food market",
                         "produce market", "fruit and vegetable", "wholesale food", "wholesale grocer", "organic food store",
                         "health food store", "natural goods", "farm shop", "traditional market"
                     ],
                     exact: ["market", "markets"],
                     name: ["grocery", "supermarket"]),
        PlaceTagRule("Specialty Food", .shopping,
                     category: [
                         "butcher", "butchers", "seafood market", "fish store", "fish market", "poultry store", "meat products", "ham shop",
                         "cold cut", "charcuterie", "spice store", "pasta shop", "seafood wholesaler", "meat wholesaler", "oyster supplier",
                         "tortilla shop", "produce wholesaler", "tea wholesaler", "coffee wholesaler", "specialty food"
                     ],
                     name: ["butcher", "charcuterie"]),
        PlaceTagRule("Beauty", .shopping,
                     category: [
                         "cosmetics store", "perfume store", "beauty supply", "beauty product", "health and beauty", "aromatherapy",
                         "toiletries", "barber supply", "vitamin", "supplements"
                     ]),
        PlaceTagRule("Electronics", .shopping,
                     category: ["electronics store", "computer store", "cell phone store", "camera store", "appliance store"]),
        PlaceTagRule("Sporting Goods", .shopping,
                     category: [
                         "sporting goods", "outdoor sports", "outdoor clothing", "camping store", "golf shop", "ski shop", "snowboard shop",
                         "bicycle shop", "bicycle store", "canoe kayak store", "fishing store", "hunting store", "hunting and fishing",
                         "exercise equipment", "baseball goods", "surplus"
                     ]),
        PlaceTagRule("Toys & Games", .shopping, category: ["toy store", "game store", "used game store"]),
        PlaceTagRule("Pet Store", .shopping, category: ["pet store", "pet supply", "reptile store", "goldfish store", "tropical fish store"]),
        PlaceTagRule("Shopping Mall", .shopping, category: ["shopping mall", "shopping center", "department store", "outlet store", "duty free"]),
        // MARK: Culture
        PlaceTagRule("Museum", .culture, category: ["museum"], name: ["museum"]),
        PlaceTagRule("Art Gallery", .culture, category: ["art gallery", "gallery", "art dealer", "art center", "art studio", "sculpture"]),
        PlaceTagRule("Theater", .culture,
                     category: [
                         "theater", "theatre", "cinema", "movie theater", "performing arts", "dinner theater", "comedy club", "amphitheater",
                         "theater production", "theater company"
                     ]),
        PlaceTagRule("Music Venue", .culture, category: ["music venue", "live music venue", "concert hall", "jazz club", "musical club"]),
        PlaceTagRule("Landmark", .culture,
                     category: [
                         "landmark", "historical place", "monument", "castle", "fortress", "archaeological site", "observation deck",
                         "observatory", "cultural center"
                     ]),
        PlaceTagRule("Library", .culture, category: ["library"]),
        PlaceTagRule("Place of Worship", .culture,
                     category: ["place of worship", "church", "temple", "shrine", "mosque", "synagogue", "religious destination", "seminary"],
                     exact: ["佛寺"]),
        // MARK: Outdoors
        PlaceTagRule("Park", .outdoors,
                     category: [
                         "city park", "state park", "national park", "dog park", "botanical garden", "community garden", "arboretum",
                         "playground", "picnic ground"
                     ],
                     exact: ["park", "parks", "garden", "gardens"]),
        PlaceTagRule("Hiking", .outdoors, category: ["hiking", "mountain peak", "mountain range", "mountain pass", "trail"]),
        PlaceTagRule("Beach", .outdoors, category: ["beach", "lido", "swimming lake"]),
        PlaceTagRule("Nature", .outdoors,
                     category: [
                         "natural feature", "nature preserve", "national reserve", "wildlife refuge", "lake", "river", "waterfall", "bay",
                         "island", "archipelago", "scenic spot", "vista point", "national forest", "ravine", "peninsula", "plateau",
                         "canoeing area", "fishing area", "sea", "cycling park"
                     ]),
        PlaceTagRule("Camping", .outdoors, category: ["campground", "camping farm", "camp"]),
        PlaceTagRule("Recreation", .outdoors,
                     category: [
                         "amusement park", "theme park", "water park", "skatepark", "bowling alley", "golf course", "golf club", "indoor golf",
                         "zoo", "video arcade", "laser tag", "go karting", "roller skating", "pool hall", "sports complex", "stadium",
                         "swimming pool", "rock climbing", "high ropes", "horseback riding", "boat tour", "ski resort", "bocce",
                         "basketball court", "athletic field", "wildlife and safari park", "wildlife park", "hang gliding", "marina",
                         "amusement center", "recreation center", "rowing club", "sports club", "water sports"
                     ]),
        // MARK: Stay
        PlaceTagRule("Hotel", .stay,
                     category: [
                         "hotel", "lodging", "motel", "inn", "hostel", "guest house", "bed breakfast", "extended stay", "lodge",
                         "indoor lodging", "villa", "resort hotel"
                     ],
                     exact: ["resort"],
                     name: ["hotel"]),
        PlaceTagRule("Vacation Rental", .stay,
                     category: [
                         "holiday apartment", "vacation rental", "holiday home", "farmstay", "rorbu", "self catering", "serviced accommodation",
                         "cabin rental", "vacation home rental"
                     ]),
        // MARK: Services
        PlaceTagRule("Spa", .services, category: ["spa", "sauna", "bathhouse", "thermal baths", "massage", "reflexologist", "wellness center"]),
        PlaceTagRule("Fitness", .services, category: ["gym", "fitness", "yoga", "pilates"]),
        PlaceTagRule("Salon", .services, category: ["hair care", "hair salon", "beauty salon", "barber shop", "nail salon"]),
        PlaceTagRule("Classes", .services, category: ["cooking school", "cooking class", "pottery classes", "dance school", "art school"]),
    ]
}
