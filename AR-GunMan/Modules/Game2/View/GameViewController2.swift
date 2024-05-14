//
//  GameViewController2.swift
//  AR-GunMan
//
//  Created by 深瀬 on 2024/05/13.
//

import UIKit
import RxSwift
import RxCocoa

final class GameViewController2: UIViewController {
    var viewModel: GameViewModel2!
    var gameSceneController: GameSceneController!
    var coreMotionController: CoreMotionController!
    private let disposeBag = DisposeBag()
    
    @IBOutlet private weak var bulletsCountImageView: UIImageView!
    @IBOutlet private weak var sightImageView: UIImageView!
    @IBOutlet private weak var timeCountLabel: UILabel!
    @IBOutlet private weak var switchWeaponButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()

        let input = GameViewModel2.Input(
            inputFromView: GameViewModel2.Input.InputFromView(
                viewDidLoad: Observable.just(Void()),
                viewWillAppear: rx.viewWillAppear,
                viewDidAppear: rx.viewDidAppear,
                viewWillDisappear: rx.viewWillDisappear,
                weaponChangeButtonTapped: switchWeaponButton.rx.tap.asObservable()
            ),
            inputFromGameScene: GameViewModel2.Input.InputFromGameScene(
                rendererUpdated: gameSceneController.rendererUpdated,
                targetHit: gameSceneController.targetHit
            ),
            inputFromCoreMotion: GameViewModel2.Input.InputFromCoreMotion(
                accelerationUpdated: coreMotionController.accelerationUpdated,
                gyroUpdated: coreMotionController.gyroUpdated
            )
        )

        let output = viewModel.transform(input: input)
        
        bindOutputToViewComponents(output.outputToView)
        bindOutputToGameSceneController(output.outputToGameScene)
        bindOutputToCoreMotionController(output.outputToCoreMotion)
        subscribeViewModelAction(output.viewModelAction)
    }
    
    private func setupUI() {
        // - 等幅フォントにして高速で動くタイムカウントの横振れを防止
        timeCountLabel.font = timeCountLabel.font.monospacedDigitFont
    }
    
    private func injectSceneViewIntoVC(_ sceneView: UIView) {
        sceneView.frame = self.view.frame
        self.view.insertSubview(sceneView, at: 0)
    }
    
    private func bindOutputToViewComponents(
        _ output: GameViewModel2.Output.OutputToView
    ) {        
        disposeBag.insert {
            output.sightImage
                .bind(to: sightImageView.rx.image)
            output.sightImageColor
                .subscribe(onNext: { [weak self] element in
                    guard let self = self else {return}
                    self.sightImageView.tintColor = element
                })
            output.timeCountText
                .bind(to: timeCountLabel.rx.text)
            output.bulletsCountImage
                .bind(to: bulletsCountImageView.rx.image)
        }
    }
    
    private func bindOutputToGameSceneController(
        _ output: GameViewModel2.Output.OutputToGameScene
    ) {
        disposeBag.insert {
            output.setupSceneView
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    let sceneView = self.gameSceneController.setupSceneViewAndEject()
                    self.injectSceneViewIntoVC(sceneView)
                })
            output.renderAllTargets
                .subscribe(onNext: { [weak self] count in
                    guard let self = self else { return }
                    self.gameSceneController.showTargets(count: count)
                })
            output.startSceneSession
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.gameSceneController.startSession()
                })
            output.pauseSceneSession
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.gameSceneController.pauseSession()
                })
            output.renderSelectedWeapon
                .subscribe(onNext: { [weak self] type in
                    guard let self = self else { return }
                    self.gameSceneController.showWeapon(type)
                })
            output.renderWeaponFiring
                .subscribe(onNext: { [weak self] type in
                    guard let self = self else { return }
                    self.gameSceneController.fireWeapon(type)
                })
            output.renderTargetsAppearanceChanging
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.gameSceneController.changeTargetsToTaimeisan()
                })
            output.moveWeaponToFPSPosition
                .subscribe(onNext: { [weak self] type in
                    guard let self = self else { return }
                    self.gameSceneController.moveWeaponToFPSPosition(currentWeapon: type)
                })
        }
    }
    
    private func bindOutputToCoreMotionController(
        _ output: GameViewModel2.Output.OutputToCoreMotion
    ) {
        disposeBag.insert {
            output.startMotionDetection
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.coreMotionController.startUpdate()
                })
            output.stopMotionDetection
                .subscribe(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.coreMotionController.stopUpdate()
                })
        }
    }
    
    private func subscribeViewModelAction(
        _ viewModelAction: GameViewModel2.Output.ViewModelAction
    ) {
        disposeBag.insert {
            viewModelAction.startGame.subscribe()
            viewModelAction.showTutorialView.subscribe()
            viewModelAction.startGameAfterTutorial.subscribe()
            viewModelAction.fireWeapon.subscribe()
            viewModelAction.reloadWeapon.subscribe()
            viewModelAction.changeWeapon.subscribe()
            viewModelAction.countScore.subscribe()
            viewModelAction.showWeaponChangeView.subscribe()
            viewModelAction.dismissWeaponChangeView.subscribe()
            viewModelAction.showResultView.subscribe()
        }
    }
}
