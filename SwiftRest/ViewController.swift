//
//  ViewController.swift
//  AlamofireDemo
//
//  Created by Christina Moulton on 2015-02-11.
//  Copyright (c) 2015 Teak Mobile Inc. All rights reserved.
//

import UIKit
import Alamofire

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, UISearchDisplayDelegate {

  var species:Array<StarWarsSpecies>?
  var speciesWrapper:SpeciesWrapper? // holds the last wrapper that we've loaded
  var isLoadingSpecies = false
  var imageCache: Dictionary<String, ImageSearchResult?>?
  
  var speciesSearchResults:Array<StarWarsSpecies>?
  
  @IBOutlet weak var tableview: UITableView?
  
  // MARK: Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    imageCache = Dictionary<String, ImageSearchResult>()
    
    self.loadFirstSpecies()
  }
  
  // MARK: Loading Species from API
  
  func loadFirstSpecies()
  {
    isLoadingSpecies = true
    StarWarsSpecies.getSpecies({ (speciesWrapper, error) in
      if error != nil
      {
        // TODO: improved error handling
        self.isLoadingSpecies = false
        var alert = UIAlertController(title: "Error", message: "Could not load first species :( \(error?.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
        alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
        self.presentViewController(alert, animated: true, completion: nil)
      }
      self.addSpeciesFromWrapper(speciesWrapper)
      self.isLoadingSpecies = false
      self.tableview?.reloadData()
    })
  }
  
  func loadMoreSpecies()
  {
    self.isLoadingSpecies = true
    if self.species != nil && self.speciesWrapper != nil && self.species!.count < self.speciesWrapper!.count
    {
      // there are more species out there!
      StarWarsSpecies.getMoreSpecies(self.speciesWrapper, completionHandler: { (moreWrapper, error) in
        if error != nil
        {
          // TODO: improved error handling
          self.isLoadingSpecies = false
          var alert = UIAlertController(title: "Error", message: "Could not load more species :( \(error?.localizedDescription)", preferredStyle: UIAlertControllerStyle.Alert)
          alert.addAction(UIAlertAction(title: "Click", style: UIAlertActionStyle.Default, handler: nil))
          self.presentViewController(alert, animated: true, completion: nil)
        }
        self.addSpeciesFromWrapper(moreWrapper)
        self.isLoadingSpecies = false
        self.tableview?.reloadData()
      })
    }
  }
  
  func addSpeciesFromWrapper(wrapper: SpeciesWrapper?)
  {
    self.speciesWrapper = wrapper
    if self.species == nil
    {
      self.species = self.speciesWrapper?.species
    }
    else if self.speciesWrapper != nil && self.speciesWrapper!.species != nil
    {
      self.species = self.species! + self.speciesWrapper!.species!
    }
  }
  
  // MARK: TableViewDataSource
  
  func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    if tableView == self.searchDisplayController!.searchResultsTableView {
      return self.speciesSearchResults?.count ?? 0
    } else {
      return self.species?.count ?? 0
    }
  }
  
  func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
    var cell = self.tableview!.dequeueReusableCellWithIdentifier("Cell") as UITableViewCell
    
    var arrayOfSpecies:Array<StarWarsSpecies>?
    if tableView == self.searchDisplayController!.searchResultsTableView {
      arrayOfSpecies = self.speciesSearchResults
    } else {
      arrayOfSpecies = self.species
    }
    
    if arrayOfSpecies != nil && arrayOfSpecies!.count >= indexPath.row
    {
      let species = arrayOfSpecies![indexPath.row]
      cell.textLabel?.text = species.name
      cell.detailTextLabel?.text = " " // if it's empty or nil it won't update correctly in iOS 8, see http://stackoverflow.com/questions/25793074/subtitles-of-uitableviewcell-wont-update
      cell.detailTextLabel?.adjustsFontSizeToFitWidth = true
      cell.imageView?.image = nil
      if let name = species.name {
        // check the cache first
        if let cachedImageResult = imageCache![name]
        {
          // TODO: custom cell with class assigned for custom view?
          cell.imageView?.image = cachedImageResult!.image // will work fine even if image is nil
          if let attribution = cachedImageResult?.fullAttribution()
          {
            if attribution.isEmpty == false
            {
              cell.detailTextLabel?.text = attribution
            }
          }
        }
        else
        {
          // didn't find it, so pull it down from the web
          // this isn't ideal since it will keep running even if the cell scrolls off of the screen
          // if we had lots of cells we'd want to stop this process when the cell gets reused
          duckDuckGoSearchController.imageFromSearchString(name, completionHandler: {
            (imageSearchResult, error) in
            if error != nil {
              println(error)
            }
            // TODO: persist cache between runs
            self.imageCache![name] = imageSearchResult
            if let cellToUpdate = self.tableview?.cellForRowAtIndexPath(indexPath)
            {
              if cellToUpdate.imageView?.image == nil
              {
                cellToUpdate.imageView?.image = imageSearchResult?.image // will work fine even if image is nil
                cellToUpdate.detailTextLabel?.text = imageSearchResult?.fullAttribution()
                cellToUpdate.setNeedsLayout() // need to reload the view, which won't happen otherwise since this is in an async call
              }
            }
          })
        }
      }

      if tableView != self.searchDisplayController!.searchResultsTableView {
        // See if we need to load more species
        let rowsToLoadFromBottom = 5;
        let rowsLoaded = self.species!.count
        if (!self.isLoadingSpecies && (indexPath.row >= (rowsLoaded - rowsToLoadFromBottom)))
        {
          let totalRows = self.speciesWrapper!.count!
          let remainingSpeciesToLoad = totalRows - rowsLoaded;
          if (remainingSpeciesToLoad > 0)
          {
            self.loadMoreSpecies()
          }
        }
      }
    }
    
    return cell
  }
    
  // MARK: Segue
  override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
    super.prepareForSegue(segue, sender: sender)
    if let speciesDetailVC = segue.destinationViewController as? SpeciesDetailViewController
    {
        // gotta check if we're currently searching
        if self.searchDisplayController!.active {
          let indexPath = self.searchDisplayController?.searchResultsTableView.indexPathForSelectedRow()
          if indexPath != nil {
            speciesDetailVC.species = self.speciesSearchResults?[indexPath!.row]
          }
        } else {
          let indexPath = self.tableview?.indexPathForSelectedRow()
          if indexPath != nil {
            speciesDetailVC.species = self.species?[indexPath!.row]
          }
        }
    }
  }
  
  // MARK: Search
  func filterContentForSearchText(searchText: String, scope: Int) {
    // Filter the array using the filter method
    if self.species == nil {
      self.speciesSearchResults = nil
      return
    }
    self.speciesSearchResults = self.species!.filter({( aSpecies: StarWarsSpecies) -> Bool in
      // pick the field to search
      var fieldToSearch: String?
      switch (scope) {
        case (0):
          fieldToSearch = aSpecies.name
        case (1):
          fieldToSearch = aSpecies.language
        case (2):
          fieldToSearch = aSpecies.classification
        default:
          fieldToSearch = nil
      }
      if fieldToSearch == nil {
        self.speciesSearchResults = nil
        return false
      }
      return fieldToSearch!.lowercaseString.rangeOfString(searchText.lowercaseString) != nil
    })
  }
  
  func searchDisplayController(controller: UISearchDisplayController!, shouldReloadTableForSearchString searchString: String!) -> Bool {
    let selectedIndex = controller.searchBar.selectedScopeButtonIndex
    self.filterContentForSearchText(searchString, scope: selectedIndex)
    return true
  }
  
  func searchDisplayController(controller: UISearchDisplayController, shouldReloadTableForSearchScope searchOption: Int) -> Bool {
    let searchString = controller.searchBar.text
    self.filterContentForSearchText(searchString, scope:searchOption)
    return true
  }

}
