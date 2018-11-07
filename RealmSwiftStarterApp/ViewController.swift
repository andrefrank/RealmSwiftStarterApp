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
   
    
    //cached shows for table view (fixed size
    private var cachedShows=Array<RealmShow>()
    
    //The showTailIndex controls the content of the tableView and the local database cache
    private var _backingRequestedIndex:Int=0
    private var showTailIndex:Int=0{
        willSet{
            //illegal show index
            guard newValue>=0 else {return}
            
            //Store requeste show index
            _backingRequestedIndex=newValue
            
            //Check if queried index+maxVisibleShows is within the same page
            
            
            //Check if query contains the requested subset with lower & upper 'id'
            //Clear cachedShows
            
//            guard let realmShows=getRealmShows(with: "id == \(newValue) ") else {return}
            
            //The requested show-id range is available
//            if realmShows.count>0{
//                cachedShows.removeAll(keepingCapacity: true)
//                print("\(realmShows.count) amount of shows will be in cachedSows")
//                cachedShows += realmShows
//                //Refrehs table view
//                showTableView.reloadData()
//                //Set top position to the requested showtailIndex
//                showTableView.scrollToRow(at: IndexPath(row: 0, section: 0), at: UITableView.ScrollPosition.top, animated: true)
//                showCountLabel.text="\(searchShows.count) shows localy stored"
            
            //Reload new page from endpoint
//            } else {
////                print("New shows should be reloaded - because not found in local database")
////                reloadRealmShowsFromAPI()
//            }
        }
    }
    
   
    
    
    
    //MARK: - ViewController Methods
    
//    func reloadRealmShowsFromAPI(){
//
//        //Calculate page from requested show
//        let page=Int(showTailIndex/ShowsPerPage)+1
//
//        for searcheIndex in searchIndexes{
//            if searcheIndex.page==page{
//                print("Page already in local database - show couldn't be found")
//                return
//            }
//        }
//
//        //Fetch pages starting with the requested uncached page
//        lastFetchedPage=page
//
//        //incremental cachSize to set top stack page limit
//        incrementalCacheSize=lastFetchedPage+maxCacheSize
//
//        //Load new shows into the database
//        fetch(lastFetchedPage)
//    }
   
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
        
        
        
        guard let dataManger=ShowManager.shared else {fatalError("Realm database error")}
        let pages=dataManger.pageCache
        
        
        
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
        //Update stepper
        showIndexStepper.value=0
    }
    
}



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
