//
//  RegisterNameViewModel.swift
//  AR-GunMan
//
//  Created by ウルトラ深瀬 on 2022/01/25.
//

import RxSwift
import RxCocoa

class NameRegisterEventObserver {
    let onRegister = PublishRelay<Ranking>()
    let onClose = PublishRelay<Void>()
}

class NameRegisterViewModel {
    let rankText: Observable<String?>
    let totalScore: Observable<String>
    let isRegisterButtonEnabled: Observable<Bool>
    let dismiss: Observable<Void>
    let isRegistering: Observable<Bool>
    let error: Observable<Error>
    
    private let disposeBag = DisposeBag()
    
    struct Input {
        let viewWillDisappear: Observable<Void>
        let nameTextFieldChanged: Observable<String>
        let registerButtonTapped: Observable<Void>
        let noButtonTapped: Observable<Void>
    }
    
    struct Dependency {
        let rankingRepository: RankingRepository
        let totalScore: Double
        let rankingListObservable: Observable<[Ranking]>
        weak var eventObserver: NameRegisterEventObserver?
    }
    
    init(input: Input, dependency: Dependency) {
        let rankTextRelay = BehaviorRelay<String?>(value: nil)
        self.rankText = rankTextRelay.asObservable()
        
        self.totalScore = Observable.just(
            "Score: \(String(format: "%.3f", dependency.totalScore))"
        )
        
        self.isRegisterButtonEnabled = input.nameTextFieldChanged
            .map({ element in
                return !element.isEmpty
            })
        
        let dismissRelay = PublishRelay<Void>()
        self.dismiss = dismissRelay.asObservable()
        
        let isRegisteringRelay = BehaviorRelay<Bool>(value: false)
        self.isRegistering = isRegisteringRelay.asObservable()
        
        let errorRelay = PublishRelay<Error>()
        self.error = errorRelay.asObservable()
        
        input.viewWillDisappear
            .subscribe(onNext: { _ in
                dependency.eventObserver?.onClose.accept(Void())
            }).disposed(by: disposeBag)
        
        input.registerButtonTapped
            .withLatestFrom(input.nameTextFieldChanged)
            .subscribe(onNext: { element in
                Task { @MainActor in
                    isRegisteringRelay.accept(true)
                    do {
                        let ranking = Ranking(score: dependency.totalScore, userName: element)
                        try await dependency.rankingRepository.registerRanking(ranking)
                        dependency.eventObserver?.onRegister.accept(ranking)
                        dismissRelay.accept(Void())
                    } catch {
                        errorRelay.accept(error)
                    }
                    isRegisteringRelay.accept(false)
                }
            }).disposed(by: disposeBag)
        
        input.noButtonTapped
            .subscribe(onNext: { _ in
                dismissRelay.accept(Void())
            }).disposed(by: disposeBag)
        
        dependency.rankingListObservable
            .filter({ !$0.isEmpty })
            .map({ rankingList in
                return RankingUtil.createTemporaryRankText(
                    rankingList: rankingList,
                    score: dependency.totalScore
                )
            })
            .bind(to: rankTextRelay)
            .disposed(by: disposeBag)
    }
}
