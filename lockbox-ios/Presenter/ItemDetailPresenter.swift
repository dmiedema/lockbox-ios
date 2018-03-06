/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import RxSwift
import RxCocoa
import RxDataSources

protocol ItemDetailViewProtocol: class, StatusAlertView {
    var itemId: String { get }
    var passwordRevealed: Bool { get }
    func bind(titleText: Driver<String>)
    func bind(itemDetail: Driver<[ItemDetailSectionModel]>)
}

let copyableFields = [Constant.string.username, Constant.string.password]

class ItemDetailPresenter {
    weak var view: ItemDetailViewProtocol?
    private var dataStore: DataStore
    private var itemDetailStore: ItemDetailStore
    private var copyDisplayStore: CopyDisplayStore
    private var routeActionHandler: RouteActionHandler
    private var copyActionHandler: CopyActionHandler
    private var itemDetailActionHandler: ItemDetailActionHandler
    private var disposeBag = DisposeBag()

    lazy private(set) var onPasswordToggle: AnyObserver<Void> = {
        return Binder(self) { target, _ in
            let updatedPasswordReveal = target.view?.passwordRevealed ?? false
            target.itemDetailActionHandler.invoke(.togglePassword(displayed: updatedPasswordReveal))
        }.asObserver()
    }()

    lazy private(set) var onCancel: AnyObserver<Void> = {
        return Binder(self) { target, _ in
            target.routeActionHandler.invoke(MainRouteAction.list)
        }.asObserver()
    }()

    lazy private(set) var onCellTapped: AnyObserver<String?> = {
        return Binder(self) { target, value in
            guard let value = value,
                  copyableFields.contains(value) else {
                return
            }

            target.dataStore.onItem(self.view?.itemId ?? "")
                    .take(1)
                    .subscribe(onNext: { item in
                        var text = ""
                        if value == Constant.string.username {
                            text = item.entry.username ?? ""
                        } else if value == Constant.string.password {
                            text = item.entry.password ?? ""
                        }

                        target.copyActionHandler.invoke(CopyAction(text: text, fieldName: value))
                    })
                    .disposed(by: target.disposeBag)

        }.asObserver()
    }()

    init(view: ItemDetailViewProtocol,
         dataStore: DataStore = DataStore.shared,
         itemDetailStore: ItemDetailStore = ItemDetailStore.shared,
         copyDisplayStore: CopyDisplayStore = CopyDisplayStore.shared,
         routeActionHandler: RouteActionHandler = RouteActionHandler.shared,
         copyActionHandler: CopyActionHandler = CopyActionHandler.shared,
         itemDetailActionHandler: ItemDetailActionHandler = ItemDetailActionHandler.shared) {
        self.view = view
        self.dataStore = dataStore
        self.itemDetailStore = itemDetailStore
        self.copyDisplayStore = copyDisplayStore
        self.routeActionHandler = routeActionHandler
        self.copyActionHandler = copyActionHandler
        self.itemDetailActionHandler = itemDetailActionHandler

        self.itemDetailActionHandler.invoke(.togglePassword(displayed: false))
    }

    func onViewReady() {
        let itemObservable = self.dataStore.onItem(self.view?.itemId ?? "")

        let itemDriver = itemObservable.asDriver(onErrorJustReturn: Item.Builder().build())
        let viewConfigDriver = Driver.combineLatest(itemDriver, self.itemDetailStore.itemDetailDisplay)
                .map { e -> [ItemDetailSectionModel] in
                    if case let .togglePassword(passwordDisplayed) = e.1 {
                        return self.configurationForItem(e.0, passwordDisplayed: passwordDisplayed)
                    }

                    return self.configurationForItem(e.0, passwordDisplayed: false)
                }

        let titleDriver = itemObservable
                .map { item -> String in
                    return item.title ?? item.origins.first ?? Constant.string.unnamedEntry
                }.asDriver(onErrorJustReturn: Constant.string.unnamedEntry)

        self.view?.bind(itemDetail: viewConfigDriver)
        self.view?.bind(titleText: titleDriver)

        self.copyDisplayStore.copyDisplay
                .drive(onNext: { action in
                    let message = String(format: Constant.string.fieldNameCopied, action.fieldName)
                    self.view?.displayTemporaryAlert(message, timeout: Constant.number.displayStatusAlertLength)
                })
                .disposed(by: self.disposeBag)
    }
}

// helpers
extension ItemDetailPresenter {
    private func configurationForItem(_ item: Item, passwordDisplayed: Bool) -> [ItemDetailSectionModel] {
        var passwordText: String
        let itemPassword: String = item.entry.password ?? ""

        if passwordDisplayed {
            passwordText = itemPassword
        } else {
            passwordText = itemPassword.replacingOccurrences(of: "[^\\s]", with: "•", options: .regularExpression)
        }

        var sectionModels = [
            ItemDetailSectionModel(model: 0, items: [
                ItemDetailCellConfiguration(
                        title: Constant.string.webAddress,
                        value: item.origins.first ?? "",
                        password: false)
            ]),
            ItemDetailSectionModel(model: 1, items: [
                ItemDetailCellConfiguration(
                        title: Constant.string.username,
                        value: item.entry.username ?? "",
                        password: false),
                ItemDetailCellConfiguration(
                        title: Constant.string.password,
                        value: passwordText,
                        password: true)
            ])
        ]

        if let notes = item.entry.notes, !notes.isEmpty {
            let notesSectionModel = ItemDetailSectionModel(model: 2, items: [
                ItemDetailCellConfiguration(
                        title: Constant.string.notes,
                        value: notes,
                        password: false)
            ])

            sectionModels.append(notesSectionModel)
        }

        return sectionModels
    }
}