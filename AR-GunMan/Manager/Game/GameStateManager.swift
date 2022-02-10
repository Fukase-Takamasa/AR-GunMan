////
////  GameStateManager.swift
////  AR-GunMan
////
////  Created by ウルトラ深瀬 on 2022/02/02.
////

import Foundation
import RxSwift
import RxCocoa

enum GameStatus {
    case ready
    case start
    case switchWeapon
    case pause
    case finish
}

enum WeaponFirableReaction {
    case fireAvailable
    case fireUnavailable
    case noBullets
}

class GameStateManager {
    //MARK: - input
    let startGame: AnyObserver<Void>
    let requestFiringWeapon: AnyObserver<Void>
    let requestReloadWeapon: AnyObserver<Void>
    let prepareForSwitchWeapon: AnyObserver<Void>

    //MARK: - output
    let gameStatusChanged: Observable<GameStatus>
    let timeCount: Observable<Double>
    let weaponSelected: Observable<WeaponTypes>
    let weaponFirableReaction: Observable<WeaponFirableReaction>
    let isReloadWeaponEnabled: Observable<Bool>

    //count
//    let explosionCount: Observable<Int>

    //nodeAnimation
//    let toggleActionInterval = 0.2
//    let lastCameraPos: (Float, Float, Float) = (0, 0, 0)
//    let isPlayerRunning = false
//    let lastPlayerStatus = false

    //other
    private let disposeBag = DisposeBag()

    init() {
        //other
        let _pistolBulletsCount = BehaviorRelay<Int>(value: Const.pistolBulletsCapacity)
        let _bazookaBulletsCount = BehaviorRelay<Int>(value: Const.bazookaBulletsCapacity)
        let _pistolPoint = BehaviorRelay<Double>(value: 0.0)
        let _bazookaPoint = BehaviorRelay<Double>(value: 0.0)


        //MARK: - output
        let _gameStatusChanged = BehaviorRelay<GameStatus>(value: .ready)
        self.gameStatusChanged = _gameStatusChanged.asObservable()

        let _timeCount = BehaviorRelay<Double>(value: Const.timeCount)
        self.timeCount = _timeCount.asObservable()

        let _weaponSelected = BehaviorRelay<WeaponTypes>(value: .pistol)
        self.weaponSelected = _weaponSelected.asObservable()

        let _weaponFirableReaction = BehaviorRelay<WeaponFirableReaction>(value: .fireUnavailable)
        self.weaponFirableReaction = _weaponFirableReaction.asObservable()

        let _isReloadWeaponEnabled = BehaviorRelay<Bool>(value: false)
        self.isReloadWeaponEnabled = _isReloadWeaponEnabled.asObservable()
        
        
        //other (output変数を参照するためここに配置)
        // - Rxタイマー（0.01秒ごとに呼び出し）
        let _ = Observable<Int>.interval(RxTimeInterval.nanoseconds(1), scheduler: MainScheduler.instance)
            .filter({ _ in
                _gameStatusChanged.value == .start ||
                    _gameStatusChanged.value == .pause
            })
            //30.00から経過時間を引いた値に変換
            .map({ count in
                let elapsedTime = Double(count / 100)
                return max(Const.timeCount - elapsedTime, 0.00)
            })
            .bind(to: _timeCount)
            .disposed(by: disposeBag)
        
        let _ = _timeCount
            .subscribe(onNext: { element in
                if element <= 0 {
                    _gameStatusChanged.accept(.finish)
                }
            }).disposed(by: disposeBag)


        //MARK: - input
        self.startGame = AnyObserver<Void>() { _ in
            _gameStatusChanged.accept(.start)
        }

        self.requestFiringWeapon = AnyObserver<Void>() { _ in
            //現在の武器が発射可能な条件かどうかチェックし、リアクションを返す
            _weaponFirableReaction.accept(
                WeaponStatusUtil
                    .chackFireAvailable(
                        gameStatus: _gameStatusChanged.value,
                        currentWeapon: _weaponSelected.value,
                        pistolBulletsCount: _pistolBulletsCount.value,
                        bazookaBulletsCount: _bazookaBulletsCount.value
                    )
            )
        }

        self.requestReloadWeapon = AnyObserver<Void>() { _ in
            //現在の武器がリロード可能な条件かどうかチェックし、リアクションを返す
            _isReloadWeaponEnabled.accept(
                WeaponStatusUtil
                    .chackReloadAvailable(
                        gameStatus: _gameStatusChanged.value,
                        currentWeapon: _weaponSelected.value,
                        pistolBulletsCount: _pistolBulletsCount.value
                    )
            )
        }
        
        self.prepareForSwitchWeapon = AnyObserver<Void>() { _ in
            _gameStatusChanged.accept(.switchWeapon)
        }
    }

    //タイマーで指定間隔ごとに呼ばれる関数
    @objc func timerUpdate(timer: Timer) {
        //gameステータスがstartの間だけ実行する


//        let lowwerTime = 0.00
//        timeCount = max(timeCount - 0.01, lowwerTime)
//        let strTimeCount = String(format: "%.2f", timeCount)
//        let twoDigitTimeCount = timeCount > 10 ? "\(strTimeCount)" : "0\(strTimeCount)"
//        timeCountLabel.text = twoDigitTimeCount

        //タイマーが0になったらタイマーを破棄して結果画面へ遷移
//        if timeCount <= 0 {
//
//            timer.invalidate()
//            isShootEnabled = false
//
//            AudioModel.playSound(of: .endWhistle)
//
//            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
//
//                self.viewModel.rankingWillAppear.onNext(Void())
//
//                AudioModel.playSound(of: .rankingAppear)
//
//                let storyboard: UIStoryboard = UIStoryboard(name: "GameResultViewController", bundle: nil)
//                let vc = storyboard.instantiateViewController(withIdentifier: "GameResultViewController") as! GameResultViewController
//
//                let sumPoint: Double = min(self.pistolPoint + self.bazookaPoint, 100.0)
//
//                let totalScore = sumPoint * (Double.random(in: 0.9...1))
//
//                print("pistolP: \(self.pistolPoint), bazookaP: \(self.bazookaPoint), sumP: \(sumPoint) totalScore: \(totalScore)")
//
//                vc.totalScore = totalScore
//                self.present(vc, animated: true)
//            })
//
//        }
    }
}
