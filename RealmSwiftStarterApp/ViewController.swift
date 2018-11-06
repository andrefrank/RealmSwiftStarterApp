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

//MARK:- Main Viewcontroller class
class ViewController: UIViewController {
    
    //MARK:- Visible Controls
    @IBOutlet weak var showIndexStepper: UIStepper!
    @IBOutlet weak var showTableView:UITableView!
    @IBOutlet weak var showCountLabel: UILabel!
    
    //MARK:- Properties to scroll shows with the stepper / tableview
    //Fixed cell height
    
    //Normally the height of the tableView should be recalculated dynamically
    //In this case it is a fixed layout from Storyboard
    let fixedCellHeight:CGFloat=65
    let maxVisibleCells:Int=20
    
    
    //cached shows for table view
    private var cachedShows=[RealmShow]()
    
    //The showTailIndex controls the content of the tableView and the local database cache
    private var _backingRequestedIndex:Int=0
    private var showTailIndex:Int=0{
        willSet{
            //illegal index
            guard newValue>=0 else {return}
            
            //Store requeste index
            _backingRequestedIndex=newValue
            
            //Calculate upper range für new index
            let upperRange = newValue + maxVisibleCells
            
            print("Upper range:\(upperRange)")
            
            //Check if query contains the requested subset with 'id'
            //Clear cachedShows
            guard let realmShows=getRealmShows(with: "id >= \(newValue) && id <= \(upperRange)") else {return}
            if realmShows.count>0{
                cachedShows.removeAll(keepingCapacity: true)
                print("\(realmShows.count) amount of shows will be in cachedSows")
                for realmShow in realmShows{
                    cachedShows.append(realmShow)
                }
                showTableView.reloadData()
                
                showTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: UITableView.ScrollPosition.top, animated: true)
                showCountLabel.text="\(searchShows.count) show localy stored"
                
            //Reload new page from endpoint
            } else {
                print("New shows should be reloaded - because not found in local database")
                reloadRealmShowsFromAPI()
            }
        }
    }
    
    func getRealmShows(with query:String)->Results<RealmShow>?{
        
        do{
            return try Realm().objects(RealmShow.self).filter(query)
        }catch let error{
            print(error.localizedDescription)
            return nil
        }
        
    }
    
    //MARK:- Properties for cache load
    //used http Endpoints
    private let showsEndpoint="http://api.tvmaze.com/shows"
    private let showsByPageEndpoint="http://api.tvmaze.com/shows?page="
    
    //No more page available at endpoint
    private let HTTP404_NO_MORE_PAGES=404
    private let ShowsPerPage=250
    
    //Pages to additionally cache - increase this number to save more shows in local
    //database
    let maxCacheSize=1
    
    // This will be the calculated value of the top stack page
    var incrementalCacheSize=0
    
    //These properties need to be strong since async calls
    //Signal lastPage loaded
    var isLastPage=false
    //Return from async read operation
    var lastFetchedPage=0
    
    //Async queue for loading the pages through SearchIndex in background tasks
    let workerQueue = DispatchQueue(label: "com.afapps+.workerQueue", qos: DispatchQoS.background)
    
    //MARK:- Realm properties
    
    //Realm schema constant - increment this value each time when the structure of the RealmShow has been changed
    let realmSchema:UInt64=0
    
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
    var searchIndexes: Results<RealmSearchIndex> { return self.realm.objects(RealmSearchIndex.self)
    }
    
    //Get all shows from database
    var searchShows:Results<RealmShow>{
        return self.realm.objects(RealmShow.self)
    }
    
    
    //MARK: - ViewController Methods
    
    func reloadRealmShowsFromAPI(){
       
        //Calculate page from requested show
        let page=Int(showTailIndex/ShowsPerPage)
        
        //Fetch pages starting with the requested uncached page
        lastFetchedPage=page
        
        //incremental cachSize to set top stack page limit
        incrementalCacheSize=lastFetchedPage+maxCacheSize
        
        //Load new shows into the database
        fetch(lastFetchedPage)
    }
   
    //MARK:- ViewController Overridables
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    
        //Connecting Controller to the tableView
        showTableView.delegate=self
        showTableView.dataSource=self
        
        //Restore Userdefaults
        let appDelegate=UIApplication.shared.delegate as! AppDelegate
        let appDefaults=appDelegate.loaddAppDefaults()
        
        //Get database directory for realm browser
        print(Realm.Configuration.defaultConfiguration.fileURL)
        
        
        //Update UI
        showTailIndex=appDefaults.lastShowIndex
        showIndexStepper.value=Double(showTailIndex)
        
    }
    
    //In IOS-Simulator this will not called -> pListInfo-Entry Background-Mode = NO
    override func viewWillDisappear(_ animated: Bool) {
        let appDelegate=UIApplication.shared.delegate as! AppDelegate
        //Save app defaults
        appDelegate.saveAppDefaults(AppDefaults(lastShowIndex:showTailIndex))
        
        super.viewWillDisappear(animated)
    }
    
    //MARK:- Action methods
    @IBAction func showIndexButtonTouched(_ sender: Any) {
        showTailIndex=Int(showIndexStepper.value)
        print("Stepper value:\(showTailIndex) + ")
    }
    
    @IBAction func saveUserDefaultsButtonTouched(_ sender: Any) {
        //Save changes to UserDefault - Only  a test
        //>>>>>>>>> This should be used in AppDelegate Terminate
        let appDelegate=UIApplication.shared.delegate as! AppDelegate
        //Save app defaults
        appDelegate.saveAppDefaults(AppDefaults(lastShowIndex:showTailIndex))
    }
    
    @IBAction func refreshShowsButtonTouched(_ sender: Any) {
        //Reset tableView to the beginning of the local database
        showTailIndex=0
        showIndexStepper.value=0
    }
    
}

//MARK:- Async Request pages methods
extension ViewController{
    fileprivate func fetch(_ Page:Int){
        if (!isLastPage && incrementalCacheSize>lastFetchedPage){
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
                //This should refresh the tableView
                self?.showTailIndex=(self?._backingRequestedIndex)!
                
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
    
    func addShowsFrom(page:Int,shows:[Show]){
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
}//end of realm method extension


//MARK:- TableView methods
extension ViewController:UITableViewDelegate,UITableViewDataSource{
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cachedShows.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "showCell")
           
        print(indexPath.row)
            //Just for unit tests - Read the RealmShow object
        cell?.textLabel?.text=cachedShows[indexPath.row].name
        cell?.detailTextLabel?.text="\(cachedShows[indexPath.row].id)"

        return cell!
    }
    
   
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        //Force fixed cell height
        return fixedCellHeight
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
      
        
        let isReachingEnd = scrollView.contentOffset.y >= 0
            && scrollView.contentOffset.y >= (scrollView.contentSize.height - scrollView.frame.size.height)
    
        if isReachingEnd{
           
           
        }else if scrollView.contentOffset.y<0{
          
        }
    }

}
