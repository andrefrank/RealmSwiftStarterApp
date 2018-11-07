//
//  ShowManager.swift
//  RealmSwiftStarterApp
//
//  Created by Andre Frank on 07.11.18.
//  Copyright © 2018 Afapps+. All rights reserved.
//

import Foundation
import RealmSwift
import Alamofire

final class ShowManager{
    //MARK:- Public Singleton
    static let shared:ShowManager?=ShowManager()
    
    //MARK:- Private properties
    private init?(){
        guard let realm=ShowManager._backingRealm else {return nil}
        self.realm=realm
    }
    
    //Endpoint related properties
    private let showsEndpoint="http://api.tvmaze.com/shows"
    private let showsByPageEndpoint="http://api.tvmaze.com/shows?page="
    private let HTTP404_NO_MORE_PAGES=404
    private let ShowsPerPage=250
    //Async queue for loading the pages in a serial background queue
    private let workerQueue = DispatchQueue(label: "com.afapps+.workerQueue", qos: DispatchQoS.background)
    
    private var isLastPage:Bool=false
    private var lastFetchedPage:Int=0
    
    private var _backingPageCache=[Int]()
    private let fetchPageCacheSize:Int=20
    
    //Current stored pages in database
    var pageCache:[Int]{
        get{
            for searchIndex in searchIndexes{
                _backingPageCache.append(searchIndex.page)
            }
            return _backingPageCache
        }
    }
    
    //MARK:- Realm database properties
    static let realmSchema:UInt64=0
    private let realm:Realm
    private static var _backingRealm:Realm?={
        
        //See also notes from realm documentation
        let config = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: ShowManager.realmSchema,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < ShowManager.realmSchema) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically
                }
        })
        
        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config
        return try? Realm()
    }()
    
    var realmDatabase:URL?{
        //Get database directory for realm browser
        return Realm.Configuration.defaultConfiguration.fileURL
        
    }
    
    //Get all pages from SearchIndex in database
    private var searchIndexes: Results<RealmSearchIndex> { return self.realm.objects(RealmSearchIndex.self)
    }
    
    //Get all shows from database
    var searchShows:Results<RealmShow>{
        return self.realm.objects(RealmShow.self)
    }
    
}


//MARK:- Async Request pages methods
extension ShowManager{
    //This method can be used to asynchronoulsy fetch pages
    fileprivate func fetch(_ Page:Int){
        if (!isLastPage && fetchPageCacheSize>lastFetchedPage){
            //Asynchronously put all fetch request in the serial queue
            workerQueue.async {[weak self] in
                //request page
                self?.loadShowsBy(page:(self?.lastFetchedPage)!) {[weak self](shows, page,isEnd,status) in
                    defer{
                        //Check if last page reached from request?
                        self?.isLastPage=isEnd
                        
                        if !isEnd{
                            // recursively fetch next page
                            self?.fetch((self?.lastFetchedPage)!)
                        }
                    }//defer
                    
                    //Append new shows to existing >>not threadsafe"
                    if let shows = shows{
                        //Serial user reside
                        DispatchQueue.main.async {
                            //Add shows to the database
                            self?.addShowsFrom(page: (self?.lastFetchedPage)!, shows: shows)
                        }
                    }//end of if let shows
                    
                    //Get next page
                    self?.lastFetchedPage += 1
                    
                    
                }//loadByShows
            }//serial async queue
            
        }else{
            DispatchQueue.main.async { [weak self] in
                //Do some operations after last page read
                
                
            }
            
        }
        
        
    }
    
    fileprivate func loadShowsBy(page:Int,completion:@escaping (_ shows:[Show]?,_ page:Int?,_ isLast:Bool,_ code:Int)->Void){
        
        
        //1.Create url for each page
        let pageUrl = URL(string: showsByPageEndpoint+"\(page)")
        
        //2. Make the request for the page
        Alamofire.request(pageUrl!).responseJSON {[weak self] (response) in
            switch response.result{
            case .failure:
                //Error ocurred the go back with no values and with the http status
                completion(nil,nil,false,(response.response?.statusCode)!)
                return
            case .success:
                //Read status code to check last page message HTTP 404
                guard let statusCode=response.response?.statusCode else
                    //The guard should not fail - anyway return with no shows
                {completion(nil,nil,true,(response.response?.statusCode)!);return}
                //Last page reached
                if statusCode==self?.HTTP404_NO_MORE_PAGES{
                    completion(nil,nil,true,statusCode)
                    return
                }
                //Read result and decode the array to 'shows'
                let data = response.data!
                let jsonDecoder = JSONDecoder()
                do{
                    var resultShows=[Show]()
                    let shows = try jsonDecoder.decode([Show?].self, from: data)
                    for show in shows{
                        if let show = show{
                            resultShows.append(show)
                        }
                    }
                    completion(resultShows,resultShows.count,false,statusCode)
                    return
                }catch _{
                    
                    
                }
                
                completion(nil,nil,false,statusCode)
                return
            }//end of switch
        }//end alamofire closure
    }//end of method showsBy(...)
    
}//end of extension


//MARK:- Realm database methods
extension ShowManager{
    
   fileprivate func addShowsFrom(page:Int,shows:[Show]){
        do {
            try realm.write {
                let newIndex = RealmSearchIndex()
                newIndex.page = page
                realm.add(newIndex)
                for show in shows{
                    //create RealmShow only with existing Show_id
                    if let showId = show.id{
                        let newShow = RealmShow()
                        
                        newShow.pageIndex=newIndex
                        newShow.id=showId
                        newShow.name=show.name
                        newShow.premiered=show.premiered
                        newShow.rating=show.rating?.average ?? 0.0
                        newShow.status=show.status
                        newShow.summary=show.summary
                        newShow.type=show.type
                        
                        let image=RealmImage()
                        image.setValue(show.image?.medium!, forKey: "medium")
                        image.setValue(show.image?.original!, forKey: "original")
                        
                        newShow.image=image
                        
                        //Only the first genre type of the show will be stored
                        if let genres = show.genres, genres.count>0{
                            newShow.genre=genres[0]
                        }
                        //Add new object to database
                        realm.add(newShow)
                    }
                    
                }//end of for shows
            }//end of realm write
        }catch _{
            
        }
    }//end of realm_addSearchIndex
    
    
    func getRealmShows(with query:String)->Results<RealmShow>?{
        
        do{
            return try Realm().objects(RealmShow.self).filter(query)
        }catch let error{
            print(error.localizedDescription)
            return nil
        }
        
    }
    
    
}//end of realm method extension
