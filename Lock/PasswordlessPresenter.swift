// PasswordlessPresenter.swift
//
// Copyright (c) 2017 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

class PasswordlessPresenter: Presentable, Loggable {

    var interactor: PasswordlessAuthenticatable
    let connection: PasswordlessConnection
    let navigator: Navigable
    let options: Options
    let screen: PasswordlessScreen
    var authPresenter: AuthPresenter?

    init(interactor: PasswordlessAuthenticatable, connection: PasswordlessConnection, navigator: Navigable, options: Options, screen: PasswordlessScreen = .request) {
        self.interactor = interactor
        self.connection = connection
        self.navigator = navigator
        self.options = options
        self.screen = screen
    }

    var messagePresenter: MessagePresenter?

    var view: View {
        switch self.screen {
        case .request:
            return self.showRequestForm()
        case .code:
            return self.showCodeForm()
        case .linkSent:
            return self.showLinkSent()
        }
    }

    private func showCodeForm() -> View {
        let view = PasswordlessView()
        view.showCodeForm(sentTo: self.interactor.identifier)

        let form = view.form

        form?.onValueChange = { input in
            self.messagePresenter?.hideCurrent()
            do {
                try self.interactor.update(input.type, value: input.text)
                input.showValid()
            } catch {
                input.showError()
            }
        }

        let action = { [weak form] (button: PrimaryButton) in
            self.messagePresenter?.hideCurrent()
            let interactor = self.interactor
            let connection = self.connection
            button.inProgress = true
            self.logger.info("Login passwordless \(self.interactor.identifier)")
            interactor.login(connection.name) { error in
                Queue.main.async {
                    button.inProgress = false
                    form?.needsToUpdateState()
                    if let error = error {
                        self.messagePresenter?.showError(error)
                        self.logger.error("Failed with error \(error)")
                    }
                }
            }
        }

        form?.onReturn = { [unowned view] _ in
            guard let button = view.primaryButton else { return }
            action(button)
        }

        view.secondaryButton?.onPress = { button in
            self.navigator.onBack()
        }

        return view
    }

    private func showRequestForm() -> View {
        let authCollectionView = self.authPresenter?.newViewToEmbed(withInsets: UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18), isLogin: true)
        let view = PasswordlessView()

        if self.options.passwordlessMethod.mode == "email" {
            view.showForm(withEmail: self.interactor.identifier, authCollectionView: authCollectionView)
        } else {
            view.showForm(withPhone: self.interactor.identifier, countryCode: self.interactor.countryCode, authCollectionView: authCollectionView)
        }
        let form = view.form
        //form?.onCountryChange = { self.interactor.countryCode = $0 }

        form?.onValueChange = { input in
            self.messagePresenter?.hideCurrent()
            do {
                try self.interactor.update(input.type, value: input.text)
                input.showValid()
            } catch {
                input.showError()
            }
        }

        let action = { [weak form] (button: PrimaryButton) in
            self.messagePresenter?.hideCurrent()
            let interactor = self.interactor
            let connection = self.connection
            button.inProgress = true
            self.logger.info("Request passwordless \(self.interactor.identifier)")
            interactor.request(connection.name) { error in
                Queue.main.async {
                    button.inProgress = false
                    form?.needsToUpdateState()
                    if let error = error {
                        self.messagePresenter?.showError(error)
                        self.logger.error("Failed with error \(error)")
                    } else {
                        if self.options.passwordlessMethod == .emailCode || self.options.passwordlessMethod == .smsCode {
                            self.navigator.navigate(Route.passwordless(screen: .code, connection: connection))
                        } else {
                            self.navigator.navigate(Route.passwordless(screen: .linkSent, connection: connection))
                        }
                    }
                }
            }

        }

        view.primaryButton?.onPress = action
        form?.onReturn = { [unowned view] _ in
            guard let button = view.primaryButton else { return }
            action(button)
        }
        return view
    }

    private func showLinkSent() -> View {
        let view = PasswordlessView()
        view.showLinkSent(identifier: self.interactor.identifier)
        view.secondaryButton?.onPress = { button in
            self.navigator.onBack()
        }
        return view
    }
}
