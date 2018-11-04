//
//  Show.swift
//  RealmSwiftStarterApp
//
//  Created by Andre Frank on 02.11.18.
//  Copyright © 2018 Afapps+. All rights reserved.
//

import Foundation

// To parse the JSON, add this file to your project and do:
//
//   let show = try? newJSONDecoder().decode(Show.self, from: jsonData)

import Foundation
import RealmSwift


//-->Realm only allows classes
//-->When using custom objects Realm is expecting that each custom object is derived from 'Object'
//-->Ream doesn't allow uninitialised properties
//-->Realm doesn't allow Arrays in Realm Object class


//class to store available pages in database
class RealmSearchIndex:Object{
    @objc dynamic var page:Int=0
}

//Due to the fact that arrays and RealmSwift aren't compatible
//A genre type
class RealmGenre:Object{
    @objc dynamic var genre:String=""
}

//class for the result of the search Index with 'shows'
class RealmShow:Object{
     @objc dynamic var id: Int=0
     //@objc dynamic var url: String?
     @objc dynamic var name:String?
     @objc dynamic var type: String?
     @objc dynamic var status: String?
     @objc dynamic var premiered: String?
     @objc dynamic var rating: RealmRating?
     @objc dynamic var image: RealmImage?
     @objc dynamic var summary: String?
     //@objc dynamic var updated: Int=0
    
    //holds a list of compatible genre types
    private let _backingGenres=List<RealmGenre>()
    
    //This will force Realm not to store the computed property
    override static func ignoredProperties() -> [String] {
        return ["genres"]
    }
    
    //The reference of search index
    @objc dynamic var pageIndex:RealmSearchIndex!
    
    //Computed wrapper property to make Array of [genres] readable for Realm
    var genres: [String] {
        get {
            return _backingGenres.map { $0.genre}
        }
        set {
            _backingGenres.removeAll()
            //Fills _backingGenres with each genre in the array
            _backingGenres.append(objectsIn: newValue.map({ (genre) -> RealmGenre in
                let realGenre=RealmGenre()
                realGenre.setValue(genre, forKey: "genre")
                return realGenre
            }))
        }
    }
}


struct Show: Codable {
    let id: Int?
    //let url: String?
    let name, type: String?
    let genres: [String]?
    let status: String?
    let premiered: String?
    let rating: Rating?
    let image: Image?
    let summary: String?
    //let updated: Int?
    
    
    enum CodingKeys: String, CodingKey {
        case id, /*url,*/ name, type, genres, status, premiered, rating, image, summary/*, updated*/
    }
}

class RealmImage:Object{
    @objc dynamic var medium:String?
    @objc dynamic var original:String?
    
}

struct Image: Codable {
    let medium, original: String?
}

class RealmRating:Object{
    @objc dynamic var average:Double=0.0
}

struct Rating: Codable {
    let average: Double?
}



