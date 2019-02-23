//
//  ContinueCourseContinueCourseAssembly.swift
//  stepik-ios
//
//  Created by Stepik on 11/09/2018.
//  Copyright 2018 Stepik. All rights reserved.
//

import UIKit

final class ContinueCourseAssembly: Assembly {
    private weak var moduleOutput: ContinueCourseOutputProtocol?

    init(output: ContinueCourseOutputProtocol? = nil) {
        self.moduleOutput = output
    }

    func makeModule() -> UIViewController {
        let provider = ContinueCourseProvider(
            userCoursesAPI: UserCoursesAPI(),
            coursesAPI: CoursesAPI(),
            progressesNetworkService: ProgressesNetworkService(
                progressesAPI: ProgressesAPI()
            )
        )
        let presenter = ContinueCoursePresenter()

        let dataBackUpdateService = DataBackUpdateService(
            unitsNetworkService: UnitsNetworkService(unitsAPI: UnitsAPI()),
            sectionsNetworkService: SectionsNetworkService(sectionsAPI: SectionsAPI()),
            coursesNetworkService: CoursesNetworkService(coursesAPI: CoursesAPI()),
            progressesNetworkService: ProgressesNetworkService(progressesAPI: ProgressesAPI())
        )

        let interactor = ContinueCourseInteractor(
            presenter: presenter,
            provider: provider,
            adaptiveStorageManager: AdaptiveStorageManager(),
            tooltipStorageManager: TooltipStorageManager(),
            dataBackUpdateService: dataBackUpdateService
        )
        let viewController = ContinueCourseViewController(
            interactor: interactor
        )

        presenter.viewController = viewController
        interactor.moduleOutput = self.moduleOutput
        return viewController
    }
}