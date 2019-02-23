//
//  ContinueCourseContinueCourseInteractor.swift
//  stepik-ios
//
//  Created by Stepik on 11/09/2018.
//  Copyright 2018 Stepik. All rights reserved.
//

import Foundation
import PromiseKit

protocol ContinueCourseInteractorProtocol {
    func loadLastCourse(request: ContinueCourse.LoadLastCourse.Request)
    func continueLastCourse(request: ContinueCourse.ContinueCourse.Request)
    func checkForTooltip(request: ContinueCourse.CheckTooltipAvailability.Request)
}

final class ContinueCourseInteractor: ContinueCourseInteractorProtocol {
    weak var moduleOutput: ContinueCourseOutputProtocol?

    let presenter: ContinueCoursePresenterProtocol
    let provider: ContinueCourseProviderProtocol
    let adaptiveStorageManager: AdaptiveStorageManagerProtocol
    let tooltipStorageManager: TooltipStorageManagerProtocol
    let dataBackUpdateService: DataBackUpdateServiceProtocol

    private var currentCourse: Course?

    init(
        presenter: ContinueCoursePresenterProtocol,
        provider: ContinueCourseProviderProtocol,
        adaptiveStorageManager: AdaptiveStorageManagerProtocol,
        tooltipStorageManager: TooltipStorageManagerProtocol,
        dataBackUpdateService: DataBackUpdateServiceProtocol
    ) {
        self.presenter = presenter
        self.provider = provider
        self.adaptiveStorageManager = adaptiveStorageManager
        self.tooltipStorageManager = tooltipStorageManager

        self.dataBackUpdateService = dataBackUpdateService
        self.dataBackUpdateService.delegate = self
    }

    func loadLastCourse(request: ContinueCourse.LoadLastCourse.Request) {
        self.provider.fetchLastCourse().done { course in
            if let course = course {
                self.currentCourse = course
                self.presenter.presentLastCourse(response: .init(result: course))
            } else {
                self.moduleOutput?.hideContinueCourse()
            }
        }.catch { _ in
            self.moduleOutput?.hideContinueCourse()
        }
    }

    func continueLastCourse(request: ContinueCourse.ContinueCourse.Request) {
        guard let currentCourse = self.currentCourse else {
            return
        }

        let isAdaptive = self.adaptiveStorageManager.canOpenInAdaptiveMode(
            courseId: currentCourse.id
        )

        // FIXME: analytics dependency
        AmplitudeAnalyticsEvents.Course.continuePressed(
            source: "home_widget",
            courseID: currentCourse.id,
            courseTitle: currentCourse.title
        ).send()

        self.moduleOutput?.presentLastStep(
            course: currentCourse,
            isAdaptive: isAdaptive
        )
    }

    func checkForTooltip(request: ContinueCourse.CheckTooltipAvailability.Request) {
        self.presenter.presentTooltip(
            response: .init(
                shouldShowTooltip: !self.tooltipStorageManager.didShowOnHomeContinueLearning
            )
        )
        self.tooltipStorageManager.didShowOnHomeContinueLearning = true
    }
}

extension ContinueCourseInteractor: DataBackUpdateServiceDelegate {
    func dataBackUpdateService(
        _ dataBackUpdateService: DataBackUpdateService,
        reportUpdate update: DataBackUpdateDescription,
        for target: DataBackUpdateTarget
    ) {
        guard case .course(let course) = target,
              course.id == self.currentCourse?.id else {
            return
        }

        self.currentCourse = course
        self.presenter.presentLastCourse(response: .init(result: course))
    }
}