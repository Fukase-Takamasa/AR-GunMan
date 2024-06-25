//
//  WeaponSelectViewModel.swift
//  AR-GunMan
//
//  Created by ウルトラ深瀬 on 21/1/23.
//

import RxSwift
import RxCocoa

final class WeaponSelectViewModel2: ViewModelType {
    struct Input {
        let viewDidLayoutSubviews: Observable<Void>
        let itemSelected: Observable<Int>
    }
    
    struct Output {
        let viewModelAction: ViewModelAction
        let outputToView: OutputToView
        
        struct ViewModelAction {
            let weaponSelectEventSent: Observable<WeaponType>
            let viewDismissed: Observable<Void>
        }
        
        struct OutputToView {
            let adjustPageViewItemSize: Observable<Void>
        }
    }
    
    struct State {}
    
    private let navigator: WeaponSelectNavigatorInterface
    private weak var weaponSelectEventReceiver: PublishRelay<WeaponType>?
                
    init(
        navigator: WeaponSelectNavigatorInterface,
        weaponSelectEventReceiver: PublishRelay<WeaponType>?
    ) {
        self.navigator = navigator
        self.weaponSelectEventReceiver = weaponSelectEventReceiver
    }
    
    func transform(input: Input) -> Output {
        let weaponSelectEventSent = input.itemSelected
            .map({ WeaponType.allCases[$0] })
            .do(onNext: { [weak self] in
                guard let self = self else { return }
                self.weaponSelectEventReceiver?.accept($0)
            })
        
        let viewDismissed = input.itemSelected
            .do(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.navigator.dismiss()
            })
            .mapToVoid()

        return Output(
            viewModelAction: Output.ViewModelAction(
                weaponSelectEventSent: weaponSelectEventSent,
                viewDismissed: viewDismissed
            ),
            outputToView: Output.OutputToView(
                adjustPageViewItemSize: input.viewDidLayoutSubviews
            )
        )
    }
}
