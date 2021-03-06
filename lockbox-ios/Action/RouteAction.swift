/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation

class RouteActionHandler: ActionHandler {
    static let shared = RouteActionHandler()
    fileprivate var dispatcher: Dispatcher

    init(dispatcher: Dispatcher = Dispatcher.shared) {
        self.dispatcher = dispatcher
    }

    func invoke(_ action: RouteAction) {
        self.dispatcher.dispatch(action: action)
    }
}

protocol RouteAction: Action { }

struct ExternalWebsiteRouteAction: RouteAction {
    let urlString: String
    let title: String
    let returnRoute: RouteAction
}

extension ExternalWebsiteRouteAction: Equatable {
    static func ==(lhs: ExternalWebsiteRouteAction, rhs: ExternalWebsiteRouteAction) -> Bool {
        return lhs.urlString == rhs.urlString && lhs.title == rhs.title
    }
}

enum LoginRouteAction: RouteAction {
    case welcome
    case fxa
    case onboardingConfirmation
}

extension LoginRouteAction: TelemetryAction {
    var eventMethod: TelemetryEventMethod {
        return .show
    }

    var eventObject: TelemetryEventObject {
        switch self {
        case .welcome:
            return .loginWelcome
        case .fxa:
            return .loginFxa
        case .onboardingConfirmation:
            return .loginOnboardingConfirmation
        }
    }

    var value: String? {
        return nil
    }

    var extras: [String: Any?]? {
      return nil
    }
}

enum MainRouteAction: RouteAction {
    case list
    case detail(itemId: String)
}

extension MainRouteAction: TelemetryAction {
    var eventMethod: TelemetryEventMethod {
        return .show
    }

    var eventObject: TelemetryEventObject {
        switch self {
        case .list:
            return .entryList
        case .detail:
            return .entryDetail
        }
    }

    var value: String? {
        return nil
    }

    var extras: [String: Any?]? {
        switch self {
        case .list:
            return nil
        case .detail(let itemId):
            return [ExtraKey.itemid.rawValue: itemId]
        }
    }
}

enum SettingRouteAction: RouteAction {
    case list
    case account
    case autoLock
    case preferredBrowser
}

extension SettingRouteAction: TelemetryAction {
    var eventMethod: TelemetryEventMethod {
        return .show
    }

    var eventObject: TelemetryEventObject {
        switch self {
        case .list:
            return .settingsList
        case .account:
            return .settingsAccount
        case .autoLock:
            return .settingsAutolock
        case .preferredBrowser:
            return .settingsPreferredBrowser

        }
    }

    var value: String? {
        return nil
    }

    var extras: [String: Any?]? {
        return nil
    }
}

extension MainRouteAction: Equatable {
    static func ==(lhs: MainRouteAction, rhs: MainRouteAction) -> Bool {
        switch (lhs, rhs) {
        case (.list, .list):
            return true
        case (.detail(let lhId), .detail(let rhId)):
            return lhId == rhId
        default:
            return false
        }
    }
}
