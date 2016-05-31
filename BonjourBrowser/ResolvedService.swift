//
//  ResolvedService.swift
//  BonjourBrowser
//
//  Created by Sebastian Kruschwitz on 31.05.16.
//  Copyright © 2016 seb. All rights reserved.
//

import Foundation

struct ResolvedService {
    
    let name: String
    let host: String
    let port: Int
}

func ==(lhs: ResolvedService, rhs: ResolvedService) -> Bool {
    return lhs.name == rhs.name
}