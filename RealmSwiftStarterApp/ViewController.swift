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
    
    @IBOutlet weak var showTableView:UITableView!
    
    //used http Endpoints
    private let showsEndpoint="http://api.tvmaze.com/shows"
    private let showsByPageEndpoint="http://api.tvmaze.com/shows?page="
    
    //No more page available at endpoint
    private let HTTP404_NO_MORE_PAGES=404
    
    //Realm schema constant - increment this value each time when the structure of the RealmShow has been changed
    let realmSchema:UInt64=3
    
    let workerQueue = DispatchQueue(label: "com.afapps+.workerQueue", qos: DispatchQoS.background)
    
    //Temporary empty Cached shows
    var cachedShows=[Show]()
    
    
    let maxCacheSize=10
    var incrementalCacheSize=0
    
    var isLastPage=false
    var lastFetchedPage=0
    
    lazy var realm:Realm={
        
        //See also notes from realm documentation
        let config = Realm.Configuration(
            // Set the new schema version. This must be greater than the previously used
            // version (if you've never set a schema version before, the version is 0).
            schemaVersion: self.realmSchema,
            
            // Set the block which will be called automatically when opening a Realm with
            // a schema version lower than the one set above
            migrationBlock: { migration, oldSchemaVersion in
                // We haven’t migrated anything yet, so oldSchemaVersion == 0
                if (oldSchemaVersion < self.realmSchema) {
                    // Nothing to do!
                    // Realm will automatically detect new properties and removed properties
                    // And will update the schema on disk automatically
                }
        })
        
        // Tell Realm to use this new configuration object for the default Realm
        Realm.Configuration.defaultConfiguration = config
        return try! Realm()
    }()
    
    //Get all pages from SearchIndex in database
    lazy var searchIndexes: Results<RealmSearchIndex> = { self.realm.objects(RealmSearchIndex.self) }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    
        //Connecting Controller to tableView
        showTableView.delegate=self
        showTableView.dataSource=self
        
        
    }
    
    

    @IBAction func searchShowButtonPressed(_ sender: Any) {
        //Get database directory for realm browser
        print(Realm.Configuration.defaultConfiguration.fileURL)
       
        //Fetch pages starting with the next uncached page
        lastFetchedPage=searchIndexes.count==0 ? 0 : searchIndexes.count+1
        //Set incremental cachSize
        incrementalCacheSize=searchIndexes.count+maxCacheSize
        
        fetch(lastFetchedPage)
    }
    
}


extension ViewController{
    
    fileprivate func fetch(_ Page:Int){
        
        if (!isLastPage && incrementalCacheSize>=lastFetchedPage){
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
        
        
        }catch let error{
            
        }
        
        
    }//end of realm_addSearchIndex
    
    
}//end of realm method extension



extension ViewController:UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "showCell")
        return cell!
    }
    
    
    //Möglichkeit 1: eigenen View programmtechnisch anlegen oder über NIB-File
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if tableView.headerView(forSection: section)==nil{
            
            let header = UIView()
            let label = UILabel()
            label.font = UIFont(name: "Futura", size: 38)!
            label.textColor = UIColor.green
            label.text="Header in grün"
            header.addSubview(label)
            return header
            
        }else{
            
            return tableView.headerView(forSection: section)
            
        }
    }
    
    
    //Möglichkeit 2: Nutze den bereits vorhandenen Standard Header mit View
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        
        if let header = view as? UITableViewHeaderFooterView{
            header.textLabel?.font = UIFont(name: "Futura", size: 38)!
            header.textLabel?.textColor = UIColor.green
        }
        
    }
    
    
}
