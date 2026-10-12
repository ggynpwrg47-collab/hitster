import Foundation

/// Lokal gepflegte BEISPIELDATEN.
///
/// Alle Preise, Angebote, Packungsgrößen, Zutaten, Adressen und Öffnungszeiten sind frei
/// erfunden und dienen nur zur Demonstration. Markennamen werden lediglich als Beispiele
/// verwendet. Die Daten sind als `PriceSource.sampleData` gekennzeichnet.
///
/// Datumsangaben werden relativ zu `now` erzeugt, damit die Angebote beim ersten Start
/// gültig sind. Nach einigen Tagen laufen sie – wie echte Angebote – ab.
public enum SampleData {
    public enum StoreID {
        public static let rewe = "store-rewe-mitte"
        public static let aldi = "store-aldi-nord"
        public static let lidl = "store-lidl-sued"
        public static let edeka = "store-edeka-west"
    }

    public static let homeLocation = GeoPoint(latitude: 51.3127, longitude: 9.4797)

    public static func make(now: Date = Date(), calendar: Calendar = .current) -> AppData {
        func day(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: now) ?? now
        }

        let stores = makeStores()
        let brands = makeBrands()
        let products = makeProducts()

        var prices: [PriceEntry] = []
        var counter = 0
        func regular(_ productID: String, _ storeID: String, _ euros: Double,
                     availability: Availability = .available, source: PriceSource = .sampleData, observedDaysAgo: Int = 2) {
            counter += 1
            prices.append(PriceEntry(
                id: "price-\(counter)-\(productID)-\(storeID)",
                productID: productID,
                storeID: storeID,
                price: Money(euros: euros),
                kind: .regular,
                availability: availability,
                source: source,
                observedAt: day(-observedDaysAgo)
            ))
        }
        func offer(_ productID: String, _ storeID: String, _ euros: Double, from: Int, until: Int) {
            counter += 1
            prices.append(PriceEntry(
                id: "offer-\(counter)-\(productID)-\(storeID)",
                productID: productID,
                storeID: storeID,
                price: Money(euros: euros),
                kind: .offer(validFrom: day(from), validUntil: day(until)),
                source: .sampleData,
                observedAt: day(min(0, from))
            ))
        }

        let rewe = StoreID.rewe, aldi = StoreID.aldi, lidl = StoreID.lidl, edeka = StoreID.edeka

        // Laktosefreie Milch 1 l
        regular("milch-lf-ja", rewe, 1.19)
        regular("milch-lf-minusl", rewe, 1.69)
        regular("milch-lf-minusl", edeka, 1.65)
        offer("milch-lf-minusl", edeka, 1.29, from: -2, until: 5)
        regular("milch-lf-milsani", aldi, 1.09)
        regular("milch-lf-milbona", lidl, 1.09)
        regular("milch-lf-gug", edeka, 1.15)
        // Vollmilch 1 l
        regular("vollmilch-ja", rewe, 1.09)
        regular("vollmilch-weihenstephan", rewe, 1.79)
        regular("vollmilch-weihenstephan", edeka, 1.75)
        regular("vollmilch-milsani", aldi, 0.99)
        regular("vollmilch-milbona", lidl, 0.99)
        regular("vollmilch-gug", edeka, 1.05)
        // Butter 250 g
        regular("butter-kerrygold", rewe, 2.99)
        offer("butter-kerrygold", rewe, 2.22, from: -1, until: 4)
        regular("butter-kerrygold", edeka, 2.89)
        regular("butter-kerrygold", lidl, 2.79)
        regular("butter-ja", rewe, 2.19)
        offer("butter-ja", rewe, 1.79, from: -10, until: -3) // abgelaufen → wird ignoriert
        regular("butter-milsani", aldi, 2.09)
        regular("butter-milbona", lidl, 2.09)
        regular("butter-gug", edeka, 2.15)
        // Spaghetti 500 g
        regular("spaghetti-barilla", rewe, 1.99)
        regular("spaghetti-barilla", edeka, 1.89, availability: .unavailable)
        regular("spaghetti-barilla", lidl, 1.79)
        offer("spaghetti-barilla", lidl, 1.29, from: -3, until: 1) // läuft bald ab
        regular("spaghetti-ja", rewe, 0.99)
        regular("spaghetti-cucina", aldi, 0.89)
        regular("spaghetti-combino", lidl, 0.89)
        regular("spaghetti-gug", edeka, 0.95)
        // Eier 10 Stück
        regular("eier-ja", rewe, 2.79)
        regular("eier-gug", edeka, 2.69)
        regular("eier-freiland", aldi, 2.49)
        regular("eier-freiland", lidl, 2.49)
        // Bananen 1 kg
        regular("bananen", rewe, 1.69)
        regular("bananen", aldi, 1.39)
        regular("bananen", lidl, 1.39)
        regular("bananen", edeka, 1.59)
        regular("bananen-bio-rewe", rewe, 2.29)
        regular("bananen-bio-gutbio", aldi, 1.99)
        // Haferflocken 500 g
        regular("haferflocken-koelln", rewe, 1.99)
        regular("haferflocken-koelln", edeka, 1.89)
        regular("haferflocken-ja", rewe, 0.79)
        regular("haferflocken-gug", edeka, 0.79)
        regular("haferflocken-gutbio", aldi, 0.99)
        regular("haferflocken-crownfield", lidl, 0.75)
        // Kaffee 500 g
        regular("kaffee-jacobs", rewe, 6.99)
        offer("kaffee-jacobs", rewe, 4.99, from: -2, until: 5)
        regular("kaffee-jacobs", edeka, 6.79)
        regular("kaffee-ja", rewe, 4.49)
        regular("kaffee-amaroy", aldi, 4.29)
        regular("kaffee-bellarom", lidl, 4.29)
        regular("kaffee-gug", edeka, 4.39)
        // Toastbrot 500 g
        regular("toast-golden", rewe, 1.69)
        regular("toast-golden", edeka, 1.65, source: .estimate) // geschätzt
        regular("toast-golden", aldi, 1.49)
        regular("toast-golden", lidl, 1.59)
        regular("toast-ja", rewe, 0.99)
        // Joghurt natur 500 g
        regular("joghurt-weihenstephan", rewe, 1.29)
        regular("joghurt-weihenstephan", edeka, 1.25)
        regular("joghurt-ja", rewe, 0.59)
        regular("joghurt-milsani", aldi, 0.55)
        regular("joghurt-milbona", lidl, 0.55, availability: .limited)
        regular("joghurt-alnatura", edeka, 1.19)
        // Passierte Tomaten 500 g
        regular("tomaten-mutti", rewe, 1.79)
        regular("tomaten-mutti", edeka, 1.69, observedDaysAgo: 40) // veraltet
        regular("tomaten-ja", rewe, 0.65)
        regular("tomaten-cucina", aldi, 0.59)
        regular("tomaten-combino", lidl, 0.59)
        // Äpfel 1 kg
        regular("aepfel", rewe, 2.49)
        regular("aepfel", aldi, 1.99)
        regular("aepfel", lidl, 2.19)
        regular("aepfel", edeka, 2.29)
        regular("aepfel-bio-rewe", rewe, 3.49)

        let settings = OptimizationSettings(
            mode: .cheapestWithStoreLimit,
            storeLimit: .two,
            costPerKilometer: Money(cents: 30),
            onlyOpenStores: false,
            offerExpiryWarningDays: 2,
            homeLocation: homeLocation
        )

        return AppData(
            lists: makeLists(now: now),
            stores: stores,
            products: products,
            brands: brands,
            prices: prices,
            settings: settings
        )
    }

    static func makeStores() -> [Store] {
        let hours = OpeningPeriod.mondayToSaturday(from: (7, 0), to: (21, 0))
        return [
            Store(id: StoreID.rewe, chain: .rewe, name: "REWE Musterstadt Mitte", address: "Hauptstraße 12, 12345 Musterstadt",
                  distanceKm: 1.6, location: GeoPoint(latitude: 51.3235, longitude: 9.4797),
                  openingHours: OpeningPeriod.mondayToSaturday(from: (7, 0), to: (22, 0)), isFavorite: true, isIncluded: true),
            Store(id: StoreID.aldi, chain: .aldi, name: "Aldi Musterstadt Nord", address: "Industriestraße 5, 12345 Musterstadt",
                  distanceKm: 2.6, location: GeoPoint(latitude: 51.3127, longitude: 9.5085),
                  openingHours: hours, isIncluded: true),
            Store(id: StoreID.lidl, chain: .lidl, name: "Lidl Musterstadt Süd", address: "Gartenweg 40, 12347 Musterstadt",
                  distanceKm: 4.0, location: GeoPoint(latitude: 51.2848, longitude: 9.4797),
                  openingHours: hours, isIncluded: true),
            Store(id: StoreID.edeka, chain: .edeka, name: "EDEKA Musterstadt West", address: "Am Markt 3, 12349 Musterstadt",
                  distanceKm: 3.3, location: GeoPoint(latitude: 51.3127, longitude: 9.4437),
                  openingHours: hours, isIncluded: true)
        ]
    }

    static func makeBrands() -> [Brand] {
        [
            Brand(id: "brand-ja", name: "Ja!", privateLabelOf: .rewe),
            Brand(id: "brand-rewe-bio", name: "REWE Bio", privateLabelOf: .rewe),
            Brand(id: "brand-gug", name: "Gut & Günstig", privateLabelOf: .edeka),
            Brand(id: "brand-milsani", name: "Milsani", privateLabelOf: .aldi),
            Brand(id: "brand-cucina", name: "Cucina Nobile", privateLabelOf: .aldi),
            Brand(id: "brand-gutbio", name: "GutBio", privateLabelOf: .aldi),
            Brand(id: "brand-amaroy", name: "Amaroy", privateLabelOf: .aldi),
            Brand(id: "brand-milbona", name: "Milbona", privateLabelOf: .lidl),
            Brand(id: "brand-combino", name: "Combino", privateLabelOf: .lidl),
            Brand(id: "brand-crownfield", name: "Crownfield", privateLabelOf: .lidl),
            Brand(id: "brand-bellarom", name: "Bellarom", privateLabelOf: .lidl),
            Brand(id: "brand-minusl", name: "MinusL"),
            Brand(id: "brand-weihenstephan", name: "Weihenstephan"),
            Brand(id: "brand-kerrygold", name: "Kerrygold"),
            Brand(id: "brand-barilla", name: "Barilla"),
            Brand(id: "brand-koelln", name: "Kölln"),
            Brand(id: "brand-jacobs", name: "Jacobs"),
            Brand(id: "brand-golden-toast", name: "Golden Toast"),
            Brand(id: "brand-alnatura", name: "Alnatura"),
            Brand(id: "brand-mutti", name: "Mutti")
        ]
    }

    static func makeProducts() -> [Product] {
        func p(_ id: String, _ name: String, _ generic: String, _ brand: String?, _ size: Quantity,
               organic: Bool = false, ingredients: [String] = [], keywords: [String] = [], category: String) -> Product {
            Product(id: id, name: name, genericName: generic, brandID: brand, packageSize: size,
                    isOrganic: organic, ingredients: ingredients, keywords: keywords, category: category)
        }
        let milk = ["Milch", "Laktase"]
        return [
            p("milch-lf-ja", "Ja! Laktosefreie H-Milch 1,5 %", "Laktosefreie Milch", "brand-ja", Quantity(1, .liter), ingredients: milk, keywords: ["laktosefrei"], category: "Milchprodukte"),
            p("milch-lf-minusl", "MinusL Laktosefreie Milch 1,5 %", "Laktosefreie Milch", "brand-minusl", Quantity(1, .liter), ingredients: milk, keywords: ["laktosefrei"], category: "Milchprodukte"),
            p("milch-lf-milsani", "Milsani Laktosefreie H-Milch", "Laktosefreie Milch", "brand-milsani", Quantity(1, .liter), ingredients: milk, keywords: ["laktosefrei"], category: "Milchprodukte"),
            p("milch-lf-milbona", "Milbona Laktosefreie H-Milch", "Laktosefreie Milch", "brand-milbona", Quantity(1, .liter), ingredients: milk, keywords: ["laktosefrei"], category: "Milchprodukte"),
            p("milch-lf-gug", "Gut & Günstig Laktosefreie Milch", "Laktosefreie Milch", "brand-gug", Quantity(1, .liter), ingredients: milk, keywords: ["laktosefrei"], category: "Milchprodukte"),

            p("vollmilch-ja", "Ja! Frische Vollmilch 3,5 %", "Vollmilch", "brand-ja", Quantity(1, .liter), ingredients: ["Milch"], keywords: ["Milch"], category: "Milchprodukte"),
            p("vollmilch-weihenstephan", "Weihenstephan Frische Vollmilch", "Vollmilch", "brand-weihenstephan", Quantity(1, .liter), ingredients: ["Milch"], keywords: ["Milch"], category: "Milchprodukte"),
            p("vollmilch-milsani", "Milsani Frische Vollmilch", "Vollmilch", "brand-milsani", Quantity(1, .liter), ingredients: ["Milch"], keywords: ["Milch"], category: "Milchprodukte"),
            p("vollmilch-milbona", "Milbona Frische Vollmilch", "Vollmilch", "brand-milbona", Quantity(1, .liter), ingredients: ["Milch"], keywords: ["Milch"], category: "Milchprodukte"),
            p("vollmilch-gug", "Gut & Günstig Vollmilch", "Vollmilch", "brand-gug", Quantity(1, .liter), ingredients: ["Milch"], keywords: ["Milch"], category: "Milchprodukte"),

            p("butter-kerrygold", "Kerrygold Original Irische Butter", "Butter", "brand-kerrygold", Quantity(250, .gram), ingredients: ["Sahne"], category: "Milchprodukte"),
            p("butter-ja", "Ja! Deutsche Markenbutter", "Butter", "brand-ja", Quantity(250, .gram), ingredients: ["Sahne"], category: "Milchprodukte"),
            p("butter-milsani", "Milsani Deutsche Markenbutter", "Butter", "brand-milsani", Quantity(250, .gram), ingredients: ["Sahne"], category: "Milchprodukte"),
            p("butter-milbona", "Milbona Deutsche Markenbutter", "Butter", "brand-milbona", Quantity(250, .gram), ingredients: ["Sahne"], category: "Milchprodukte"),
            p("butter-gug", "Gut & Günstig Markenbutter", "Butter", "brand-gug", Quantity(250, .gram), ingredients: ["Sahne"], category: "Milchprodukte"),

            p("spaghetti-barilla", "Barilla Spaghetti n.5", "Spaghetti", "brand-barilla", Quantity(500, .gram), ingredients: ["Hartweizengrieß"], keywords: ["Nudeln", "Pasta"], category: "Nudeln & Reis"),
            p("spaghetti-ja", "Ja! Spaghetti", "Spaghetti", "brand-ja", Quantity(500, .gram), ingredients: ["Hartweizengrieß"], keywords: ["Nudeln", "Pasta"], category: "Nudeln & Reis"),
            p("spaghetti-cucina", "Cucina Nobile Spaghetti", "Spaghetti", "brand-cucina", Quantity(500, .gram), ingredients: ["Hartweizengrieß"], keywords: ["Nudeln", "Pasta"], category: "Nudeln & Reis"),
            p("spaghetti-combino", "Combino Spaghetti", "Spaghetti", "brand-combino", Quantity(500, .gram), ingredients: ["Hartweizengrieß"], keywords: ["Nudeln", "Pasta"], category: "Nudeln & Reis"),
            p("spaghetti-gug", "Gut & Günstig Spaghetti", "Spaghetti", "brand-gug", Quantity(500, .gram), ingredients: ["Hartweizengrieß"], keywords: ["Nudeln", "Pasta"], category: "Nudeln & Reis"),

            p("eier-ja", "Ja! Freilandeier Größe M", "Eier", "brand-ja", Quantity(10, .piece), ingredients: ["Ei"], keywords: ["Freiland"], category: "Eier"),
            p("eier-gug", "Gut & Günstig Freilandeier M", "Eier", "brand-gug", Quantity(10, .piece), ingredients: ["Ei"], keywords: ["Freiland"], category: "Eier"),
            p("eier-freiland", "Freilandeier Größe M (lose Ware)", "Eier", nil, Quantity(10, .piece), ingredients: ["Ei"], keywords: ["Freiland"], category: "Eier"),

            p("bananen", "Bananen", "Bananen", nil, Quantity(1, .kilogram), keywords: ["Obst"], category: "Obst & Gemüse"),
            p("bananen-bio-rewe", "REWE Bio Bananen", "Bananen", "brand-rewe-bio", Quantity(1, .kilogram), organic: true, keywords: ["Obst", "Bio"], category: "Obst & Gemüse"),
            p("bananen-bio-gutbio", "GutBio Bananen", "Bananen", "brand-gutbio", Quantity(1, .kilogram), organic: true, keywords: ["Obst", "Bio"], category: "Obst & Gemüse"),

            p("haferflocken-koelln", "Kölln Blütenzarte Köllnflocken", "Haferflocken", "brand-koelln", Quantity(500, .gram), ingredients: ["Hafer"], keywords: ["Müsli"], category: "Frühstück"),
            p("haferflocken-ja", "Ja! Haferflocken zart", "Haferflocken", "brand-ja", Quantity(500, .gram), ingredients: ["Hafer"], keywords: ["Müsli"], category: "Frühstück"),
            p("haferflocken-gug", "Gut & Günstig Haferflocken", "Haferflocken", "brand-gug", Quantity(500, .gram), ingredients: ["Hafer"], keywords: ["Müsli"], category: "Frühstück"),
            p("haferflocken-gutbio", "GutBio Haferflocken", "Haferflocken", "brand-gutbio", Quantity(500, .gram), organic: true, ingredients: ["Hafer"], keywords: ["Müsli", "Bio"], category: "Frühstück"),
            p("haferflocken-crownfield", "Crownfield Haferflocken", "Haferflocken", "brand-crownfield", Quantity(500, .gram), ingredients: ["Hafer"], keywords: ["Müsli"], category: "Frühstück"),

            p("kaffee-jacobs", "Jacobs Krönung gemahlen", "Kaffee", "brand-jacobs", Quantity(500, .gram), ingredients: ["Kaffee"], keywords: ["gemahlen"], category: "Getränke"),
            p("kaffee-ja", "Ja! Kaffee gemahlen", "Kaffee", "brand-ja", Quantity(500, .gram), ingredients: ["Kaffee"], keywords: ["gemahlen"], category: "Getränke"),
            p("kaffee-amaroy", "Amaroy Kaffee gemahlen", "Kaffee", "brand-amaroy", Quantity(500, .gram), ingredients: ["Kaffee"], keywords: ["gemahlen"], category: "Getränke"),
            p("kaffee-bellarom", "Bellarom Kaffee gemahlen", "Kaffee", "brand-bellarom", Quantity(500, .gram), ingredients: ["Kaffee"], keywords: ["gemahlen"], category: "Getränke"),
            p("kaffee-gug", "Gut & Günstig Kaffee gemahlen", "Kaffee", "brand-gug", Quantity(500, .gram), ingredients: ["Kaffee"], keywords: ["gemahlen"], category: "Getränke"),

            p("toast-golden", "Golden Toast Buttertoast", "Toastbrot", "brand-golden-toast", Quantity(500, .gram), ingredients: ["Weizenmehl", "Butter", "Gluten"], keywords: ["Brot"], category: "Brot & Backwaren"),
            p("toast-ja", "Ja! Buttertoast", "Toastbrot", "brand-ja", Quantity(500, .gram), ingredients: ["Weizenmehl", "Palmfett", "Gluten"], keywords: ["Brot"], category: "Brot & Backwaren"),

            p("joghurt-weihenstephan", "Weihenstephan Joghurt mild 3,5 %", "Joghurt natur", "brand-weihenstephan", Quantity(500, .gram), ingredients: ["Milch"], keywords: ["Naturjoghurt"], category: "Milchprodukte"),
            p("joghurt-ja", "Ja! Joghurt mild", "Joghurt natur", "brand-ja", Quantity(500, .gram), ingredients: ["Milch"], keywords: ["Naturjoghurt"], category: "Milchprodukte"),
            p("joghurt-milsani", "Milsani Joghurt mild", "Joghurt natur", "brand-milsani", Quantity(500, .gram), ingredients: ["Milch"], keywords: ["Naturjoghurt"], category: "Milchprodukte"),
            p("joghurt-milbona", "Milbona Joghurt mild", "Joghurt natur", "brand-milbona", Quantity(500, .gram), ingredients: ["Milch"], keywords: ["Naturjoghurt"], category: "Milchprodukte"),
            p("joghurt-alnatura", "Alnatura Bio Joghurt mild", "Joghurt natur", "brand-alnatura", Quantity(500, .gram), organic: true, ingredients: ["Milch"], keywords: ["Naturjoghurt", "Bio"], category: "Milchprodukte"),

            p("tomaten-mutti", "Mutti Passata", "Passierte Tomaten", "brand-mutti", Quantity(500, .gram), ingredients: ["Tomaten"], keywords: ["Passata"], category: "Konserven"),
            p("tomaten-ja", "Ja! Passierte Tomaten", "Passierte Tomaten", "brand-ja", Quantity(500, .gram), ingredients: ["Tomaten", "Salz"], keywords: ["Passata"], category: "Konserven"),
            p("tomaten-cucina", "Cucina Nobile Passata", "Passierte Tomaten", "brand-cucina", Quantity(500, .gram), ingredients: ["Tomaten"], keywords: ["Passata"], category: "Konserven"),
            p("tomaten-combino", "Combino Passierte Tomaten", "Passierte Tomaten", "brand-combino", Quantity(500, .gram), ingredients: ["Tomaten"], keywords: ["Passata"], category: "Konserven"),

            p("aepfel", "Äpfel Elstar", "Äpfel", nil, Quantity(1, .kilogram), keywords: ["Obst", "Apfel"], category: "Obst & Gemüse"),
            p("aepfel-bio-rewe", "REWE Bio Äpfel", "Äpfel", "brand-rewe-bio", Quantity(1, .kilogram), organic: true, keywords: ["Obst", "Apfel", "Bio"], category: "Obst & Gemüse")
        ]
    }

    /// Beispiel-Einkaufsliste („Wocheneinkauf“), die im README durchgerechnet wird.
    public static func weeklyList(now: Date = Date()) -> ShoppingList {
        ShoppingList(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000A001")!,
            name: "Wocheneinkauf",
            items: [
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!, query: "Laktosefreie Milch", quantity: 2,
                                 desiredPackageSize: Quantity(1, .liter), requiredBrandID: "brand-minusl"),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!, query: "Butter", quantity: 1),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!, query: "Spaghetti", quantity: 2,
                                 requiredBrandID: "brand-barilla"),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B4")!, query: "Kaffee", quantity: 1),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B5")!, query: "Bananen", quantity: 1,
                                 desiredPackageSize: Quantity(1, .kilogram), prefersOrganic: true),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B6")!, query: "Haferflocken", quantity: 1,
                                 prefersPrivateLabel: true),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B7")!, query: "Eier", quantity: 1),
                ShoppingListItem(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B8")!, query: "Hafermilch Barista", quantity: 1)
            ],
            createdAt: now,
            updatedAt: now
        )
    }

    static func makeLists(now: Date) -> [ShoppingList] {
        let breakfast = ShoppingList(
            name: "Frühstück",
            items: [
                ShoppingListItem(query: "Toastbrot", quantity: 1, excludedIngredients: ["Palmfett"]),
                ShoppingListItem(query: "Joghurt natur", quantity: 2, prefersOrganic: true),
                ShoppingListItem(query: "Vollmilch", quantity: 2),
                ShoppingListItem(query: "Äpfel", quantity: 1, desiredPackageSize: Quantity(1, .kilogram))
            ],
            createdAt: now.addingTimeInterval(-3600),
            updatedAt: now.addingTimeInterval(-3600)
        )
        return [weeklyList(now: now), breakfast]
    }
}
