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
    
    
    @IBAction func startSearch() {
        
        browser.delegate = self
        
        browser.browse { [unowned self] (services: [NetService]?) in
            
            print("Services: \(String(describing: services))")
            
            if let foundServices = services {
                
                self.resolveServices(services: foundServices)
            }
        }
    }
    
    func resolveServices(services: [NetService]) {
        
        for service: NetService in services {
            
            self.browser.resolveService(service: service, completion: { [unowned self] (result) in
                
                switch (result) {
                    
                case .Success((let host, let port)):
                    print("\(host): \(port)")
                    
                    let resolved = ResolvedService(name: service.name, host: service.hostName!, port: service.port)
                    self.resolvedServices.append( resolved )
                    
                    self.tableView.beginUpdates()
                    let index = IndexPath(row: self.resolvedServices.count-1, section: 0)
                    self.tableView.insertRows(at: [index], with: .automatic)
                    self.tableView.endUpdates()
                    
                case .Failure(let error):
                    print("\(error)")
                }
            })
        }
        
        //browser.stop()
    }

}

extension ViewController: BonjourBrowserDelegate {
    
    func didStartSearching(browser: BonjourBrowser) {
        
        print("did start searching")
    }
    
    func didStopSearching(browser: BonjourBrowser) {
        
        print("did stop searching")
    }
    
    func browser(browser: BonjourBrowser, didRemoveServices services: [NetService]) {
        
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
                resolvedServices.remove(at: 0)
            }
            
            tableView.beginUpdates()
            let indexPaths: [IndexPath] = indizeToRemove.map { return IndexPath(row: $0, section: 0) }
            tableView.deleteRows(at: indexPaths, with: .automatic)
            tableView.endUpdates()
        }
    }
    
}


extension ViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        
        startSearch()
        
        return true
    }

}


extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return resolvedServices.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCell.CellStyle.default, reuseIdentifier: "Cell")
            cell!.selectionStyle = .none
        }
        
        let value = resolvedServices[indexPath.row]
        cell!.textLabel!.text = "\(value.name) - \(value.host):\(value.port)"
        
        return cell!
    }

}
