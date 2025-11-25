import Foundation

struct ShareableLightweightList: Codable, Identifiable {
    let id: String
    let name: String
    let city: String
    let userId: String
    
    init(from lightweightList: LightweightPlaceList, userId: String) {
        self.id = lightweightList.list_id
        self.name = lightweightList.name
        self.city = lightweightList.city ?? ""
        self.userId = userId
    }
    
    init(id: String, name: String, city: String, userId: String) {
        self.id = id
        self.name = name
        self.city = city
        self.userId = userId
    }
    
    var deepLinkURL: URL? {
        var components = URLComponents()
        components.scheme = "loc"
        components.host = "list"
        components.path = "/\(id)"
        
        var queryItems: [URLQueryItem] = []
        queryItems.append(URLQueryItem(name: "name", value: name))
        queryItems.append(URLQueryItem(name: "city", value: city))
        queryItems.append(URLQueryItem(name: "userId", value: userId))
        
        components.queryItems = queryItems
        return components.url
    }
    
    static func from(url: URL) -> ShareableLightweightList? {
        guard url.scheme == "loc",
              url.host == "list",
              !url.pathComponents.isEmpty else {
            return nil
        }
        
        let pathComponents = url.pathComponents
        guard pathComponents.count > 1 else { return nil }
        
        let listId = String(pathComponents[1])
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            return nil
        }
        
        guard let name = queryItems.first(where: { $0.name == "name" })?.value,
              let city = queryItems.first(where: { $0.name == "city" })?.value,
              let userId = queryItems.first(where: { $0.name == "userId" })?.value else {
            return nil
        }
        
        return ShareableLightweightList(id: listId, name: name, city: city, userId: userId)
    }
}
