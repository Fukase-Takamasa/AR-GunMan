//
//  GameViewController.swift
//  AR-GunMan
//
//  Created by ウルトラ深瀬 on 23/6/24.
//

import UIKit
import RxSwift
import RxCocoa

class GameViewController: UIViewController {
    var presenter: GamePresenter!
    var arContentController: ARContentController!
    var deviceMotionController: DeviceMotionController!
    private var contentView: GameContentView!
    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        setView()
        bind()
    }
    
    private func setView() {
        contentView = .init(frame: view.frame)
        view.addSubview(contentView)
        view.addConstraints(for: contentView)
        view.backgroundColor = .systemBackground
    }
    
    private func bind() {
        let controllerEvents = GamePresenter.ControllerEvents(
            inputFromView: .init(
                viewDidLoad: .just(()),
                viewWillAppear: rx.viewWillAppear,
                viewDidAppear: rx.viewDidAppear,
                viewWillDisappear: rx.viewWillDisappear,
                weaponChangeButtonTapped: contentView.weaponChangeButton.rx.tap.asObservable(),
                fire: contentView.fireButton.rx.tap.asObservable(),
                reload: contentView.reloadButton.rx.tap.asObservable()
            ),
            inputFromARContent: .init(
                targetHit: arContentController.targetHit
            ),
            inputFromDeviceMotion: .init(
                accelerationUpdated: deviceMotionController.accelerationUpdated,
                gyroUpdated: deviceMotionController.gyroUpdated
            )
        )
        let viewModel = presenter.generateViewModel(from: controllerEvents)
        bindOutputToViewComponents(viewModel.outputToView)
        bindOutputToARContentController(viewModel.outputToARContent)
        bindOutputToDeviceMotionController(viewModel.outputToDeviceMotion)
    }
    
    private func bindOutputToViewComponents(
        _ outputToView: GamePresenter.ViewModel.OutputToView
    ) {
        disposeBag.insert {
            outputToView.sightImageName
                .map({ UIImage(named: $0) })
                .drive(contentView.sightImageView.rx.image)
            outputToView.sightImageColorHexCode
                .map({ UIColor(hexString: $0) })
                .drive(contentView.sightImageView.rx.tintColor)
            outputToView.timeCountText
                .drive(contentView.timeCountLabel.rx.text)
            outputToView.bulletsCountImageName
                .map({ UIImage(named: $0) })
                .drive(contentView.bulletsCountImageView.rx.image)
            outputToView.isWeaponChangeButtonEnabled
                .drive(contentView.weaponChangeButton.rx.isEnabled)
        }
    }
    
    private func bindOutputToARContentController(
        _ outputToARContent: GamePresenter.ViewModel.OutputToARContent
    ) {
        disposeBag.insert {
            outputToARContent.setupSceneView
                .drive(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    let sceneView = self.arContentController.setupSceneView(with: self.view.frame)
                    self.view.insertSubview(sceneView, at: 0)
                })
            outputToARContent.renderAllTargets
                .drive(onNext: { [weak self] count in
                    guard let self = self else { return }
                    self.arContentController.showTargets(count: count)
                })
            outputToARContent.startSceneSession
                .drive(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.arContentController.startSession()
                })
            outputToARContent.pauseSceneSession
                .drive(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.arContentController.pauseSession()
                })
            outputToARContent.renderSelectedWeapon
                .drive(onNext: { [weak self] type in
                    guard let self = self else { return }
                    self.arContentController.showWeapon(type)
                })
            outputToARContent.renderWeaponFiring
                .drive(onNext: { [weak self] type in
                    guard let self = self else { return }
                    self.arContentController.fireWeapon(type)
                })
            outputToARContent.renderTargetsAppearanceChanging
                .drive(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.arContentController.changeTargetsToTaimeisan()
                })
        }
    }
    
    private func bindOutputToDeviceMotionController(
        _ outputToDeviceMotion: GamePresenter.ViewModel.OutputToDeviceMotion
    ) {
        disposeBag.insert {
            outputToDeviceMotion.startMotionDetection
                .drive(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.deviceMotionController.startUpdate()
                })
            outputToDeviceMotion.stopMotionDetection
                .drive(onNext: { [weak self] _ in
                    guard let self = self else { return }
                    self.deviceMotionController.stopUpdate()
                })
        }
    }
}
