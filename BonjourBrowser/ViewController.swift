//
//  ViewController.swift
//  BonjourBrowser
//
//  Created by Sebastian Kruschwitz on 31.05.16.
//  Copyright © 2016 seb. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet var textField: UITextField!
    @IBOutlet var tableView: UITableView!
    
    var resolvedServices = [ResolvedService]()
    
    lazy var browser: BonjourBrowser = {
        return BonjourBrowser(identifier: self.textField.text!)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

    }
    
    @IBAction func startSearch() {
        
        browser.delegate = self
        
        browser.browse { [unowned self] (services: [NSNetService]?) in
            
            print("Services: \(services)")
            
            if let foundServices = services {
                
                self.resolveServices(foundServices)
            }
        }
    }
    
    func resolveServices(services: [NSNetService]) {
        
        for service: NSNetService in services {
            
            self.browser.resolveService(service, completion: { [unowned self] (result) in
                
                switch (result) {
                
                case .Success(let host, let port):
                    print("\(host): \(port)")
                    
                    let resolved = ResolvedService(name: service.name, host: service.hostName!, port: service.port)
                    self.resolvedServices.append( resolved )
                    
                    self.tableView.beginUpdates()
                    let index = NSIndexPath(forRow: self.resolvedServices.count-1, inSection: 0)
                    self.tableView.insertRowsAtIndexPaths([index], withRowAnimation: .Automatic)
                    self.tableView.endUpdates()
                    
                case .Failure(let error):
                    print("\(error)")
                }
            })
        }
        
        //browser.stop()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

extension ViewController: BonjourBrowserDelegate {
    
    func didStartSearching(browser browser: BonjourBrowser) {
        
        print("did start searching")
    }
    
    func didStopSearching(browser browser: BonjourBrowser) {
        
        print("did stop searching")
    }
    
    func browser(browser: BonjourBrowser, didRemoveServices services: [NSNetService]) {
        
        print("did remove service")
        
        // Loop the removed services and remove them from the table and the dataSource (resolvedServices). This can be written better...
        for service in services {
            let name = service.name
            
            var indizeToRemove = [Int]()
            for index in 0 ..< resolvedServices.count {
                let resolved = resolvedServices[index]
                if resolved.name == name {
                    indizeToRemove.append(index)
                }
            }
            
            for _ in indizeToRemove {
                resolvedServices.removeAtIndex(0)
            }
            
            tableView.beginUpdates()
            let indexPaths: [NSIndexPath] = indizeToRemove.map { return NSIndexPath(forRow: $0, inSection: 0) }
            tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Automatic)
            tableView.endUpdates()
            
            
        }
    }
    
}

extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(textField: UITextField) -> Bool {
        
        textField.resignFirstResponder()
        
        startSearch()
        
        return true
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return resolvedServices.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cell = tableView.dequeueReusableCellWithIdentifier("Cell")
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.Default, reuseIdentifier: "Cell")
            cell!.selectionStyle = .None
        }
        
        let value = resolvedServices[indexPath.row]
        cell!.textLabel!.text = "\(value.name) - \(value.host):\(value.port)"
        
        return cell!
    }
}
