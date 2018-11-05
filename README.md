# RealmSwiftStarterApp
Only for review purposes

Preconditions:
Install/Update Alamofire & RealmSwift within the project before compile

* After starting the app it should automatically request a paginated show list from specified endpoint "Maze-API"
* Storing shows in the default.realm database
* A cache of 20 fixed shows will be displayed in the table view
* After pressing the stepper control +/- it should load every 20 shows up/down from the local Realm database
* If the requested show(s) are not in the database a new endpoint request will start and reload the shows and add it to the local storage
