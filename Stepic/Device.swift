//
//  Device.swift
//  Stepic
//
//  Created by Alexander Karpov on 22.04.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import UIKit
import SwiftyJSON

class Device: NSObject {
    var id : Int?
    var registrationId: String
    var user: String?
    var deviceDescription: String
    var clentType: String = "ios"
    
    init(json: JSON) {
        self.id = json["id"].intValue
        self.registrationId = json["registration_id"].stringValue
        self.user = json["user"].stringValue
        self.deviceDescription = json["description"].stringValue
        super.init()
    }
    
    init(id: Int? = nil, registrationId: String, user: String? = nil, deviceDescription: String) {
        self.id = id
        self.registrationId = registrationId
        self.user = user
        self.deviceDescription = deviceDescription
        super.init()
    }
    
    func getJSON() -> [String:AnyObject] {
        var res = [String:AnyObject]()
        
        if let id = self.id {
            res["id"] = id as AnyObject?
        }
        
        res["registration_id"] = registrationId as AnyObject?
        
        if let user = self.user { 
            res["user"] = user as AnyObject?
        }
        
        res["description"] = self.deviceDescription as AnyObject?
        
        return res
    }
}
