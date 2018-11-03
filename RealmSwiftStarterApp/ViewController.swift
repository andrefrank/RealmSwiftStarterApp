//
//  ViewController.swift
//  RealmSwiftStarterApp
//
//  Created by Andre Frank on 01.11.18.
//  Copyright © 2018 Afapps+. All rights reserved.
//

import UIKit
import Alamofire
import RealmSwift

class ViewController: UIViewController {
    
    
    //used http Endpoints
    private let showsEndpoint="http://api.tvmaze.com/shows"
    private let showsByPageEndpoint="http://api.tvmaze.com/shows?page="
    
    //No more page available at endpoint
    private let HTTP404_NO_MORE_PAGES=404
    
    let workerQueue = DispatchQueue(label: "com.afapps+.workerQueue", qos: DispatchQoS.background)
    
    //Temporary empty Cached shows
    var cachedShows=[Show]()
    
    var lastFetchedPage=0
    let maxCacheSize=10
    var isLastPage=false
    
    lazy var realm:Realm={
        let config = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: 2,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < 1) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically
                }
        })
        
        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config
        return try! Realm()
    }()
        
    lazy var searchIndexes: Results<RealmSearchIndex> = { self.realm.objects(RealmSearchIndex.self) }()
   
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    
    }

    @IBAction func searchShowButtonPressed(_ sender: Any) {
        print(Realm.Configuration.defaultConfiguration.fileURL)
        
        for searchIndex in self.searchIndexes{
            print("Cached page:\(searchIndex.page)")
        }
        //Fetch pages starting with the next uncached page
        fetch(searchIndexes.count+1)
    }
    
}


extension ViewController{
    
    fileprivate func fetch(_ Page:Int){
        
        if (!isLastPage && maxCacheSize>lastFetchedPage){
            //Call method in main queue (all updated values reside in main)
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
                        self?.cachedShows += shows
                        //Serial user reside
                        DispatchQueue.main.async {
                            //Do some database operation here after page read
                            self?.realm_addSearchIndex(page: (self?.lastFetchedPage)!, shows: shows)
                        }
                    }//if New shows
                    
                    //Get next page
                    self?.lastFetchedPage += 1
                    
                    
                }//loadByShows
            }//serial async queue
            
        }else{
            DispatchQueue.main.async {
                //Do some database operations after last page read
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
extension ViewController{
    
    func realm_addSearchIndex(page:Int,shows:[Show]){
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
                        
                        let rating = RealmRating()
                        rating.average=show.rating?.average ?? 0
                        
                        newShow.rating=rating
                        newShow.status=show.status
                        
                        let image=RealmImage()
                        image.setValue(show.image?.medium!, forKey: "medium")
                        image.setValue(show.image?.original!, forKey: "original")
                        
                        newShow.image=image
                        
                        newShow.summary=show.summary
                        newShow.type=show.type
                        newShow.updated=show.updated ?? 0
                        
                        if let genres = show.genres{
                            newShow.genres=genres
                        }
                        
                        
                        
                        realm.add(newShow)
                    }
                    
                }//end of for shows
            }//end of realm write
        
        
        }catch let error{
            
        }
        
        
    }//end of realm_addSearchIndex
    
    
    
}//end of realm method extension

