//
//  GamePresenter.swift
//  AR-GunMan
//
//  Created by ウルトラ深瀬 on 3/7/24.
//

import RxSwift
import RxCocoa

final class GamePresenter: PresenterType {
    struct ControllerEvents {
        let inputFromView: InputFromView
        let inputFromARContent: InputFromARContent
        let inputFromDeviceMotion: InputFromDeviceMotion

        struct InputFromView {
            let viewDidLoad: Observable<Void>
            let viewWillAppear: Observable<Void>
            let viewDidAppear: Observable<Void>
            let viewWillDisappear: Observable<Void>
            let weaponChangeButtonTapped: Observable<Void>
            let fire: Observable<Void>
            let reload: Observable<Void>
        }
        struct InputFromARContent {
            let targetHit: Observable<WeaponType>
        }
        struct InputFromDeviceMotion {
            let accelerationUpdated: Observable<Vector>
            let gyroUpdated: Observable<Vector>
        }
    }
    struct ViewModel {
        let outputToView: OutputToView
        let outputToARContent: OutputToARContent
        let outputToDeviceMotion: OutputToDeviceMotion
        
        struct OutputToView {
            let sightImageName: Driver<String>
            let sightImageColorHexCode: Driver<String>
            let timeCountText: Driver<String>
            let bulletsCountImageName: Driver<String>
            let isWeaponChangeButtonEnabled: Driver<Bool>
        }
        struct OutputToARContent {
            let setupSceneView: Driver<Void>
            let renderAllTargets: Driver<Int>
            let startSceneSession: Driver<Void>
            let pauseSceneSession: Driver<Void>
            let renderSelectedWeapon: Driver<WeaponType>
            let renderWeaponFiring: Driver<WeaponType>
            let renderTargetsAppearanceChanging: Driver<Void>
        }
        struct OutputToDeviceMotion {
            let startMotionDetection: Driver<Void>
            let stopMotionDetection: Driver<Void>
        }
    }
    class State {
        let timeCountRelay = BehaviorRelay<Double>(value: GameConst.timeCount)
        let weaponTypeRelay = BehaviorRelay<WeaponType>(value: .pistol)
        let isWeaponReloadingRelay = BehaviorRelay<Bool>(value: false)
        let bulletsCountRelay = BehaviorRelay<Int>(value: WeaponType.pistol.bulletsCapacity)
        let scoreRelay = BehaviorRelay<Double>(value: 0)
        let reloadingMotionDetectedCountRelay = BehaviorRelay<Int>(value: 0)
    }
    
    private let gameScenarioHandlingUseCase: GameScenarioHandlingUseCaseInterface
    private let weaponFireUseCase: WeaponFireUseCaseInterface
    private let weaponReloadUseCase: WeaponReloadUseCaseInterface
    private let weaponChangeUseCase: WeaponChangeUseCaseInterface
    private let targetHitHandlingUseCase: TargetHitHandlingUseCaseInterface
    private let reloadMotionDetectionCountUseCase: ReloadMotionDetectionCountUseCaseInterface
    private let navigator: GameNavigatorInterface
    private let state: State
    private let tutorialEndEventReceiver: PublishRelay<Void>
    private let weaponSelectEventReceiver: PublishRelay<WeaponType>
    private let disposeBag = DisposeBag()
    
    init(
        gameScenarioHandlingUseCase: GameScenarioHandlingUseCaseInterface,
        weaponFireUseCase: WeaponFireUseCaseInterface,
        weaponReloadUseCase: WeaponReloadUseCaseInterface,
        weaponChangeUseCase: WeaponChangeUseCaseInterface,
        targetHitHandlingUseCase: TargetHitHandlingUseCaseInterface,
        reloadMotionDetectionCountUseCase: ReloadMotionDetectionCountUseCaseInterface,
        navigator: GameNavigatorInterface,
        state: State = State(),
        tutorialEndEventReceiver: PublishRelay<Void> = PublishRelay<Void>(),
        weaponSelectEventReceiver: PublishRelay<WeaponType> = PublishRelay<WeaponType>()
    ) {
        self.gameScenarioHandlingUseCase = gameScenarioHandlingUseCase
        self.weaponFireUseCase = weaponFireUseCase
        self.weaponReloadUseCase = weaponReloadUseCase
        self.weaponChangeUseCase = weaponChangeUseCase
        self.targetHitHandlingUseCase = targetHitHandlingUseCase
        self.reloadMotionDetectionCountUseCase = reloadMotionDetectionCountUseCase
        self.navigator = navigator
        self.state = state
        self.tutorialEndEventReceiver = tutorialEndEventReceiver
        self.weaponSelectEventReceiver = weaponSelectEventReceiver
    }
    
    func generateViewModel(from input: ControllerEvents) -> ViewModel {
        // ゲーム開始前〜終了後までのシナリオをハンドリングし、結果のアクションを生成
        let gameScenarioOutput = gameScenarioHandlingUseCase
            .generateOutput(from: .init(
                tutorialSeenCheckTrigger: input.inputFromView.viewDidAppear.take(1),
                tutorialEnded: tutorialEndEventReceiver.asObservable()
            ))
        let showTutorial = gameScenarioOutput.showTutorial
        let startDeviceMotionDetection = gameScenarioOutput.startDeviceMotionDetection
        let updateTimeCount = gameScenarioOutput.updateTimeCount
        let stopDeviceMotionDetection = gameScenarioOutput.stopDeviceMotionDetection
        let dismissWeaponChangeView = gameScenarioOutput.dismissWeaponChangeView
        let showResultView = gameScenarioOutput.showResultView
        
        
        // 武器の発射関連の処理をハンドリングし、結果のアクションを生成
//        let weaponFireTrigger = DeviceMotionFilter.filterFireMotion(
//            accelerationUpdated: input.inputFromDeviceMotion.accelerationUpdated
//                .withLatestFrom(input.inputFromDeviceMotion.gyroUpdated) { ($0, $1) }
//        )
        let weaponFireTrigger = input.inputFromView.fire
        let weaponFireOutput = weaponFireUseCase
            .generateOutput(from: .init(
                weaponFiringTrigger: weaponFireTrigger.withLatestFrom(
                    Observable.combineLatest(
                        state.weaponTypeRelay.asObservable(),
                        state.bulletsCountRelay.asObservable()
                    )
                ) { ($1.0, $1.1) }
            ))
        let decreaseBulletsCount = weaponFireOutput.updateBulletsCount
        let weaponFired = weaponFireOutput.weaponFired
        
        
        // 武器のリロード関連の処理をハンドリングし、結果のアクションを生成
        let autoReloadTrigger = WeaponAutoReloadFilter.filter(
            weaponFired: weaponFired.withLatestFrom(
                state.bulletsCountRelay.asObservable()
            ) { ($0, $1) }
        )
//        let weaponReloadTrigger = DeviceMotionFilter.filterReloadMotion(
//            gyroUpdated: input.inputFromDeviceMotion.gyroUpdated
//        )
        let weaponReloadTrigger = input.inputFromView.reload
        let combinedWeaponReloadTrigger = Observable
            .merge(
                autoReloadTrigger,
                weaponReloadTrigger.withLatestFrom(
                    state.weaponTypeRelay.asObservable()
                )
            )
        let weaponReloadOutput = weaponReloadUseCase
            .generateOutput(from: .init(
                weaponReloadingTrigger: combinedWeaponReloadTrigger
                    .withLatestFrom(
                        state.bulletsCountRelay.asObservable()
                    ) { ($0, $1) },
                isWeaponReloading: state.isWeaponReloadingRelay.asObservable()
            ))
        let changeWeaponReloadingFlag = weaponReloadOutput.updateWeaponReloadingFlag
        let refillBulletsCount = weaponReloadOutput.updateBulletsCount
                
        
        // 武器変更関連の処理をハンドリングし、結果のアクションを生成
        let weaponChangeOutput = weaponChangeUseCase
            .generateOutput(from: .init(
                weaponSelected: weaponSelectEventReceiver.asObservable()
            ))
        let refillBulletsCountForNewWeapon = weaponChangeOutput.refillBulletsCountForNewWeapon
        let resetWeaponReloadingFlag = weaponChangeOutput.resetWeaponReloadingFlag
        let updateWeaponType = weaponChangeOutput.updateWeaponType
        let weaponChanged = weaponChangeOutput.weaponChanged
        
        
        // ターゲットヒット関連の処理をハンドリングし、結果のアクションを生成
        let targetHitHandlingOutput = targetHitHandlingUseCase
            .generateOutput(from: .init(
                targetHit: input.inputFromARContent.targetHit
                    .withLatestFrom(state.scoreRelay.asObservable()) { ($0, $1) }
            ))
        let updateScore = targetHitHandlingOutput.updateScore
        
        
        // リロードモーション検知回数関連の処理をハンドリングし、結果のアクションを生成
        let reloadMotionDetectionCountOutput = reloadMotionDetectionCountUseCase
            .generateOutput(from: .init(
                currentCountWhenReloadMotionDetected: weaponReloadTrigger
                    .withLatestFrom(state.reloadingMotionDetectedCountRelay.asObservable())
            ))
        let changeTargetsAppearance = reloadMotionDetectionCountOutput.changeTargetsAppearance
        let updateDetectionCount = reloadMotionDetectionCountOutput.updateCount
        
        
        // 同じStateにbindするストリームを結合
        let updateWeaponReloadingFlag = Observable
            .merge(
                changeWeaponReloadingFlag,
                resetWeaponReloadingFlag
            )
        let updateBulletsCount = Observable
            .merge(
                decreaseBulletsCount,
                refillBulletsCount,
                refillBulletsCountForNewWeapon
            )
        
        disposeBag.insert {
            // MARK: Stateの更新
            updateTimeCount
                .bind(to: state.timeCountRelay)
            updateWeaponType
                .bind(to: state.weaponTypeRelay)
            updateWeaponReloadingFlag
                .bind(to: state.isWeaponReloadingRelay)
            updateBulletsCount
                .bind(to: state.bulletsCountRelay)
            updateScore
                .bind(to: state.scoreRelay)
            updateDetectionCount
                .bind(to: state.reloadingMotionDetectedCountRelay)
            
            // MARK: 画面遷移
            showTutorial
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.navigator.showTutorialView(
                        tutorialEndEventReceiver: self.tutorialEndEventReceiver
                    )
                })
            input.inputFromView.weaponChangeButtonTapped
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.navigator.showWeaponSelectView(
                        weaponSelectEventReceiver: self.weaponSelectEventReceiver
                    )
                })
            dismissWeaponChangeView
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.navigator.dismissWeaponSelectView()
                })
            showResultView
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.navigator.showResultView(score: self.state.scoreRelay.value)
                })
        }

        return ViewModel(
            outputToView: .init(
                sightImageName: state.weaponTypeRelay
                    .map({ $0.sightImageName })
                    .asDriverOnErrorJustComplete(),
                sightImageColorHexCode: state.weaponTypeRelay
                    .map({ $0.sightImageColorHexCode })
                    .asDriverOnErrorJustComplete(),
                timeCountText: state.timeCountRelay
                    .map({ TimeCountUtil.twoDigitTimeCount($0) })
                    .asDriverOnErrorJustComplete(),
                bulletsCountImageName: state.bulletsCountRelay
                    .withLatestFrom(state.weaponTypeRelay) { ($0, $1) }
                    .map({ $1.bulletsCountImageName(at: $0) })
                    .asDriverOnErrorJustComplete(),
                isWeaponChangeButtonEnabled: state.timeCountRelay
                    .map({ $0 < GameConst.timeCount && $0 > 0 })
                    .asDriverOnErrorJustComplete()
            ),
            outputToARContent: .init(
                setupSceneView: input.inputFromView.viewDidLoad
                    .asDriverOnErrorJustComplete(),
                renderAllTargets: input.inputFromView.viewDidLoad
                    .map({ _ in GameConst.targetCount })
                    .asDriverOnErrorJustComplete(),
                startSceneSession: input.inputFromView.viewWillAppear
                    .asDriverOnErrorJustComplete(),
                pauseSceneSession: input.inputFromView.viewWillDisappear
                    .asDriverOnErrorJustComplete(),
                renderSelectedWeapon: weaponChanged
                    .startWith(state.weaponTypeRelay.value)
                    .asDriverOnErrorJustComplete(),
                renderWeaponFiring: weaponFired
                    .asDriverOnErrorJustComplete(),
                renderTargetsAppearanceChanging: changeTargetsAppearance
                    .asDriverOnErrorJustComplete()
            ),
            outputToDeviceMotion: .init(
                startMotionDetection: startDeviceMotionDetection
                    .asDriverOnErrorJustComplete(),
                stopMotionDetection: stopDeviceMotionDetection
                    .asDriverOnErrorJustComplete()
            )
        )
    }
}
