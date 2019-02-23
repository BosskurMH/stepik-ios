//
//  HomeHomeProvider.swift
//  stepik-ios
//
//  Created by Vladislav Kiryukhin on 17/09/2018.
//  Copyright 2018 Stepik. All rights reserved.
//

import Foundation
import PromiseKit

protocol HomeProviderProtocol {
    func fetchUserActivity(user: User) -> Promise<UserActivity>
}

final class HomeProvider: HomeProviderProtocol {
    private let userActivitiesAPI: UserActivitiesAPI

    init(userActivitiesAPI: UserActivitiesAPI) {
        self.userActivitiesAPI = userActivitiesAPI
    }

    func fetchUserActivity(user: User) -> Promise<UserActivity> {
        return Promise { seal in
            self.userActivitiesAPI.retrieve(user: user.id).done { activity in
                seal.fulfill(activity)
            }.catch { _ in
                seal.reject(Error.userActivityFetchFailed)
            }
        }
    }

    enum Error: Swift.Error {
        case userActivityFetchFailed
    }
}