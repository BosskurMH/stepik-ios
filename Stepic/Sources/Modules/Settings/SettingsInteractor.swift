import Foundation
import PromiseKit

protocol SettingsInteractorProtocol {
    func doSettingsLoad(request: Settings.SettingsLoad.Request)
    // DownloadVideoQuality
    func doDownloadVideoQualitySettingPresentation(request: Settings.DownloadVideoQualitySettingPresentation.Request)
    func doDownloadVideoQualitySettingUpdate(request: Settings.DownloadVideoQualitySettingUpdate.Request)
    // StreamVideoQuality
    func doStreamVideoQualitySettingPresentation(request: Settings.StreamVideoQualitySettingPresentation.Request)
    func doStreamVideoQualitySettingUpdate(request: Settings.StreamVideoQualitySettingUpdate.Request)
    // ContentLanguage
    func doContentLanguageSettingPresentation(request: Settings.ContentLanguageSettingPresentation.Request)
    func doContentLanguageSettingUpdate(request: Settings.ContentLanguageSettingUpdate.Request)
    // StepFontSize
    func doStepFontSizeSettingPresentation(request: Settings.StepFontSizeSettingPresentation.Request)
    func doStepFontSizeUpdate(request: Settings.StepFontSizeSettingUpdate.Request)

    func doAutoplayNextVideoSettingUpdate(request: Settings.AutoplayNextVideoSettingUpdate.Request)
    func doAdaptiveModeSettingUpdate(request: Settings.AdaptiveModeSettingUpdate.Request)
    func doDeleteAllContent(request: Settings.DeleteAllContent.Request)
    func doAccountLogOut(request: Settings.AccountLogOut.Request)
}

final class SettingsInteractor: SettingsInteractorProtocol {
    weak var moduleOutput: SettingsOutputProtocol?

    private let presenter: SettingsPresenterProtocol
    private let provider: SettingsProviderProtocol

    private let userAccountService: UserAccountServiceProtocol

    private var settingsData: Settings.SettingsData {
        .init(
            downloadVideoQuality: self.provider.globalDownloadVideoQuality,
            streamVideoQuality: self.provider.globalStreamVideoQuality,
            contentLanguage: self.provider.globalContentLanguage,
            stepFontSize: self.provider.globalStepFontSize,
            isAutoplayEnabled: self.provider.isAutoplayEnabled,
            isAdaptiveModeEnabled: self.provider.isAdaptiveModeEnabled
        )
    }

    init(
        presenter: SettingsPresenterProtocol,
        provider: SettingsProviderProtocol,
        userAccountService: UserAccountServiceProtocol
    ) {
        self.presenter = presenter
        self.provider = provider
        self.userAccountService = userAccountService
    }

    func doSettingsLoad(request: Settings.SettingsLoad.Request) {
        self.presenter.presentSettings(response: .init(data: self.settingsData))
    }

    func doDownloadVideoQualitySettingPresentation(request: Settings.DownloadVideoQualitySettingPresentation.Request) {
        self.presenter.presentDownloadVideoQualitySetting(
            response: .init(
                availableDownloadVideoQualities: self.provider.availableDownloadVideoQualities,
                globalDownloadVideoQuality: self.provider.globalDownloadVideoQuality
            )
        )
    }

    func doDownloadVideoQualitySettingUpdate(request: Settings.DownloadVideoQualitySettingUpdate.Request) {
        if let newDownloadVideoQuality = DownloadVideoQuality(uniqueIdentifier: request.setting.uniqueIdentifier) {
            self.provider.globalDownloadVideoQuality = newDownloadVideoQuality
        }
    }

    func doStreamVideoQualitySettingPresentation(request: Settings.StreamVideoQualitySettingPresentation.Request) {
        self.presenter.presentStreamVideoQualitySetting(
            response: .init(
                availableStreamVideoQualities: self.provider.availableStreamVideoQualities,
                globalStreamVideoQuality: self.provider.globalStreamVideoQuality
            )
        )
    }

    func doStreamVideoQualitySettingUpdate(request: Settings.StreamVideoQualitySettingUpdate.Request) {
        if let newStreamVideoQuality = StreamVideoQuality(uniqueIdentifier: request.setting.uniqueIdentifier) {
            self.provider.globalStreamVideoQuality = newStreamVideoQuality
        }
    }

    func doContentLanguageSettingPresentation(request: Settings.ContentLanguageSettingPresentation.Request) {
        self.presenter.presentContentLanguageSetting(
            response: .init(
                availableContentLanguages: self.provider.availableContentLanguages,
                globalContentLanguage: self.provider.globalContentLanguage
            )
        )
    }

    func doContentLanguageSettingUpdate(request: Settings.ContentLanguageSettingUpdate.Request) {
        self.provider.globalContentLanguage = ContentLanguage(languageString: request.setting.uniqueIdentifier)
    }

    func doStepFontSizeSettingPresentation(request: Settings.StepFontSizeSettingPresentation.Request) {
        self.presenter.presentStepFontSizeSetting(
            response: .init(
                availableStepFontSizes: self.provider.availableStepFontSizes,
                globalStepFontSize: self.provider.globalStepFontSize
            )
        )
    }

    func doStepFontSizeUpdate(request: Settings.StepFontSizeSettingUpdate.Request) {
        if let newStepFontSize = StepFontSize(uniqueIdentifier: request.setting.uniqueIdentifier) {
            AnalyticsEvent.stepFontSizeSelected(newStepFontSize).report()
            self.provider.globalStepFontSize = newStepFontSize
        }
    }

    func doAutoplayNextVideoSettingUpdate(request: Settings.AutoplayNextVideoSettingUpdate.Request) {
        self.provider.isAutoplayEnabled = request.isOn
    }

    func doAdaptiveModeSettingUpdate(request: Settings.AdaptiveModeSettingUpdate.Request) {
        self.provider.isAdaptiveModeEnabled = request.isOn
    }

    func doDeleteAllContent(request: Settings.DeleteAllContent.Request) {
        self.presenter.presentWaitingState(response: .init(shouldDismiss: false))

        firstly {
            // For better waiting animation.
            after(.seconds(1))
        }.then {
            self.provider.deleteAllDownloadedContent()
        }.done {
            self.presenter.presentDeleteAllContentResult(response: .init(isSuccessful: true))
        }.catch { _ in
            self.presenter.presentDeleteAllContentResult(response: .init(isSuccessful: false))
        }
    }

    func doAccountLogOut(request: Settings.AccountLogOut.Request) {
        DispatchQueue.main.async {
            self.userAccountService.logOut()
            self.moduleOutput?.handleUserLoggedOut()
        }
    }

    // MARK: Inner Types

    // FIXME: analytics dependency
    private enum AnalyticsEvent {
        case stepFontSizeSelected(StepFontSize)

        func report() {
            switch self {
            case .stepFontSizeSelected(let selectedStepFontSize):
                let analyticsStringValue: String = {
                    switch selectedStepFontSize {
                    case .small:
                        return "small"
                    case .medium:
                        return "medium"
                    case .large:
                        return "large"
                    }
                }()
                AmplitudeAnalyticsEvents.Settings.stepFontSizeSelected(size: analyticsStringValue).send()
                AnalyticsReporter.reportEvent(
                    AnalyticsEvents.Settings.stepFontSizeSelected,
                    parameters: ["size": analyticsStringValue]
                )
            }
        }
    }
}