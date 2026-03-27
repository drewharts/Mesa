//
//  PlaceTypes.swift
//  loc
//
//  Created by Assistant on 1/9/25.
//

import Foundation

struct PlaceTypes {
    static let recognizedTypes = [
        // Food & Dining
        "American", "Japanese", "Korean", "Mexican", "Italian", "Chinese", "Greek", "Vietnamese",
        "Barbecue", "Indian", "Pizza", "Coffee Shop", "Steakhouse", "Venezuelan", "Columbian", 
        "Peruvian", "Salvadoran", "Argentinian", "Brazilian", "Spanish", "French", "German", 
        "Thai", "Turkish", "Moroccan", "Lebanese", "Egyptian", "Home", "Restaurant", "Cafe",
        "Bakery", "Bar", "Pub", "Food Truck", "Ice Cream", "Dessert", "Seafood", "Sushi",
        "Burger", "Sandwich", "Deli", "BBQ", "Tex-Mex", "Mediterranean", "Middle Eastern",
        "Asian", "Fusion", "Vegetarian", "Vegan", "Gluten-Free", "Fast Food", "Fine Dining",
        "Buffet", "Food Court", "Market", "Grocery", "Convenience Store", "Liquor Store",
        
        // Parks & Nature
        "National Park", "State Park", "City Park", "Regional Park", "Botanical Garden",
        "Zoo", "Aquarium", "Wildlife Sanctuary", "Nature Reserve", "Forest", "Beach",
        "Lake", "River", "Waterfall", "Mountain", "Trail", "Hiking", "Camping", "Recreation Area",
        "Playground", "Dog Park", "Garden", "Arboretum", "Conservatory", "Marina", "Pier",
        "Boardwalk", "Scenic Overlook", "Viewpoint", "Observation Deck", "Canyon", "Cave",
        "Hot Springs", "Geyser", "Volcano", "Island", "Peninsula", "Bay", "Harbor", "Creek",
        "Stream", "Pond", "Reservoir", "Dam", "Bridge", "Tunnel", "Mountain Pass",
        
        // Entertainment & Recreation
        "Movie Theater", "Cinema", "Theater", "Concert Hall", "Arena", "Stadium", "Amphitheater",
        "Museum", "Art Gallery", "Science Center", "Planetarium", "Observatory", "Library",
        "Bookstore", "Arcade", "Bowling Alley", "Mini Golf", "Golf Course", "Tennis Court",
        "Basketball Court", "Soccer Field", "Baseball Field", "Swimming Pool", "Gym",
        "Fitness Center", "Yoga Studio", "Spa", "Salon", "Barber Shop", "Tattoo Parlor",
        "Escape Room", "Laser Tag", "Paintball", "Go-Kart", "Roller Skating", "Ice Skating",
        "Rock Climbing", "Skate Park", "BMX Track", "Horseback Riding", "Fishing", "Hunting",
        "Shooting Range", "Gun Range", "Archery Range", "Driving Range", "Batting Cage",
        
        // Shopping & Retail
        "Mall", "Shopping Center", "Department Store", "Clothing Store", "Shoe Store",
        "Jewelry Store", "Electronics Store", "Computer Store", "Phone Store", "Toy Store",
        "Game Store", "Music Store", "Record Store", "Antique Store", "Thrift Store", "Vintage",
        "Vintage Clothing", "Furniture Store", "Home Goods", "Hardware Store", "Home Improvement", "Garden Center",
        "Pet Store", "Pet Shop", "Veterinary", "Vet", "Pharmacy", "Drug Store", "Optical",
        "Eye Doctor", "Dentist", "Medical", "Hospital", "Clinic", "Urgent Care", "Emergency Room",
        "Bank", "Credit Union", "ATM", "Post Office", "UPS", "FedEx", "Shipping",
        
        // Transportation & Services
        "Airport", "Train Station", "Bus Station", "Subway Station", "Metro Station",
        "Gas Station", "Car Wash", "Auto Repair", "Mechanic", "Car Dealership", "Rental Car",
        "Taxi", "Rideshare", "Parking", "Parking Garage", "Parking Lot", "Rest Area",
        "Visitor Center", "Information Center", "Tourist Office", "Welcome Center",
        "Police Station", "Fire Station", "Ambulance", "Emergency", "City Hall", "Court House",
        "DMV", "License Bureau", "Government Office", "School", "University", "College",
        "Elementary School", "High School", "Middle School", "Daycare", "Preschool",
        
        // Accommodation & Hospitality
        "Hotel", "Motel", "Resort", "Inn", "Bed and Breakfast", "Hostel", "Cabin", "Lodge",
        "Campground", "RV Park", "Trailer Park", "Apartment", "Condominium", "Timeshare",
        "Vacation Rental", "Airbnb", "Guest House", "Cottage", "Villa", "Chalet", "Yurt",
        "Tent", "Glamping", "Dude Ranch", "Spa Resort", "Golf Resort", "Ski Resort",
        
        // Religious & Cultural
        "Church", "Cathedral", "Temple", "Mosque", "Synagogue", "Chapel", "Shrine", "Monastery",
        "Convent", "Cemetery", "Graveyard", "Memorial", "Monument", "Statue", "Fountain",
        "Clock Tower", "Bell Tower", "Lighthouse", "Castle", "Palace", "Fort", "Fortress",
        "Ruins", "Archaeological Site", "Historic Site", "Heritage Site", "Landmark",
        "Cultural Center", "Community Center", "Senior Center", "Youth Center", "Rec Center",
        
        // Business & Professional
        "Office", "Law Office", "Law Firm", "Attorney", "Lawyer", "Real Estate", "Realtor",
        "Insurance", "Financial Advisor", "Investment", "Accounting", "CPA", "Consulting",
        "Marketing", "Advertising", "Design", "Architecture", "Engineering", "Construction",
        "Plumbing", "Electrical", "HVAC", "Roofing", "Landscaping", "Cleaning", "Maintenance",
        "Security", "Locksmith", "Moving", "Storage", "Self Storage", "Warehouse", "Factory",
        "Industrial", "Manufacturing", "Distribution", "Logistics", "Shipping", "Freight",
        
        // Events & Venues
        "Wedding Venue", "Event Space", "Conference Center", "Convention Center", "Exhibition Hall",
        "Fairgrounds", "Racetrack", "Speedway", "Drag Strip", "Horse Track", "Casino",
        "Bingo Hall", "Lottery", "Auction House", "Flea Market", "Farmer's Market", "Craft Fair",
        "Festival Grounds", "Amusement Park", "Theme Park", "Water Park", "Carnival", "Circus",
        "Fair", "Rodeo", "Renaissance Fair", "Comic Con", "Trade Show", "Expo", "Convention",
        
        // Other
        "Landmark", "Attraction", "Tourist Attraction", "Point of Interest", "Destination",
        "Location", "Place", "Site", "Area", "District", "Neighborhood", "Community",
        "Town", "Village", "City", "County", "State", "Country", "Region", "Territory"
    ]
    
    // Restaurant and food-related types that should be included when filtering by "Restaurant"
    static let restaurantTypes: Set<String> = [
        // Cuisine types
        "American", "Japanese", "Korean", "Mexican", "Italian", "Chinese", "Greek", "Vietnamese",
        "Barbecue", "Indian", "Pizza", "Steakhouse", "Venezuelan", "Columbian", 
        "Peruvian", "Salvadoran", "Argentinian", "Brazilian", "Spanish", "French", "German", 
        "Thai", "Turkish", "Moroccan", "Lebanese", "Egyptian", "Restaurant",
        "Seafood", "Sushi", "Burger", "Sandwich", "Deli", "BBQ", "Tex-Mex", 
        "Mediterranean", "Middle Eastern", "Asian", "Fusion", "Vegetarian", "Vegan", 
        "Gluten-Free", "Fast Food", "Fine Dining", "Buffet",
        
        // Food establishments
        "Cafe", "Coffee Shop", "Bakery", "Bar", "Pub", "Food Truck", "Ice Cream", 
        "Dessert", "Food Court"
    ]
    
    static let defaultType = "Place"

    /// Recognized types organized by section for the category correction picker.
    static let groupedTypes: [(section: String, types: [String])] = [
        ("Food & Dining", [
            "American", "Japanese", "Korean", "Mexican", "Italian", "Chinese", "Greek", "Vietnamese",
            "Barbecue", "Indian", "Pizza", "Coffee Shop", "Steakhouse", "Venezuelan", "Columbian",
            "Peruvian", "Salvadoran", "Argentinian", "Brazilian", "Spanish", "French", "German",
            "Thai", "Turkish", "Moroccan", "Lebanese", "Egyptian", "Restaurant", "Cafe",
            "Bakery", "Bar", "Pub", "Food Truck", "Ice Cream", "Dessert", "Seafood", "Sushi",
            "Burger", "Sandwich", "Deli", "BBQ", "Tex-Mex", "Mediterranean", "Middle Eastern",
            "Asian", "Fusion", "Vegetarian", "Vegan", "Gluten-Free", "Fast Food", "Fine Dining",
            "Buffet", "Food Court", "Market", "Grocery", "Convenience Store", "Liquor Store"
        ]),
        ("Parks & Nature", [
            "National Park", "State Park", "City Park", "Regional Park", "Botanical Garden",
            "Zoo", "Aquarium", "Wildlife Sanctuary", "Nature Reserve", "Forest", "Beach",
            "Lake", "River", "Waterfall", "Mountain", "Trail", "Hiking", "Camping", "Recreation Area",
            "Playground", "Dog Park", "Garden", "Arboretum", "Conservatory", "Marina", "Pier",
            "Boardwalk", "Scenic Overlook", "Viewpoint", "Observation Deck", "Canyon", "Cave",
            "Hot Springs", "Geyser", "Volcano", "Island", "Peninsula", "Bay", "Harbor"
        ]),
        ("Entertainment & Recreation", [
            "Movie Theater", "Cinema", "Theater", "Concert Hall", "Arena", "Stadium", "Amphitheater",
            "Museum", "Art Gallery", "Science Center", "Planetarium", "Observatory", "Library",
            "Bookstore", "Arcade", "Bowling Alley", "Mini Golf", "Golf Course", "Tennis Court",
            "Basketball Court", "Soccer Field", "Baseball Field", "Swimming Pool", "Gym",
            "Fitness Center", "Yoga Studio", "Spa", "Salon", "Barber Shop",
            "Escape Room", "Laser Tag", "Rock Climbing", "Skate Park", "Ice Skating", "Roller Skating"
        ]),
        ("Shopping & Retail", [
            "Mall", "Shopping Center", "Department Store", "Clothing Store", "Shoe Store",
            "Jewelry Store", "Electronics Store", "Toy Store", "Game Store", "Music Store",
            "Record Store", "Antique Store", "Thrift Store", "Vintage", "Furniture Store",
            "Home Goods", "Hardware Store", "Garden Center", "Pet Store", "Pharmacy"
        ]),
        ("Accommodation & Hospitality", [
            "Hotel", "Motel", "Resort", "Inn", "Bed and Breakfast", "Hostel", "Cabin", "Lodge",
            "Campground", "Vacation Rental", "Airbnb", "Guest House", "Cottage", "Villa",
            "Glamping", "Spa Resort", "Golf Resort", "Ski Resort"
        ]),
        ("Religious & Cultural", [
            "Church", "Cathedral", "Temple", "Mosque", "Synagogue", "Chapel", "Shrine", "Monastery",
            "Cemetery", "Memorial", "Monument", "Lighthouse", "Castle", "Palace", "Fort",
            "Ruins", "Archaeological Site", "Historic Site", "Heritage Site", "Landmark",
            "Cultural Center", "Community Center"
        ]),
        ("Events & Venues", [
            "Wedding Venue", "Event Space", "Conference Center", "Convention Center",
            "Fairgrounds", "Racetrack", "Casino", "Auction House", "Flea Market", "Farmer's Market",
            "Amusement Park", "Theme Park", "Water Park", "Festival Grounds"
        ]),
        ("Other", [
            "Attraction", "Tourist Attraction", "Point of Interest", "Destination", "Place"
        ])
    ]
} 