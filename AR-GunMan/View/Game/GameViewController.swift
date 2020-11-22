//
//  GameViewController.swift
//  AR-GunMan
//
//  Created by 深瀬 貴将 on 2020/08/15.
//  Copyright © 2020 fukase. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import CoreMotion
import AVFoundation
import AudioToolbox
import FSPagerView
import PanModal

class GameViewController: UIViewController, ARSCNViewDelegate, SCNPhysicsContactDelegate {
    
    let motionManager = CMMotionManager()
    
    var pistolSet = AVAudioPlayer()
    var pistolShoot = AVAudioPlayer()
    var pistolOutBullets = AVAudioPlayer()
    var pistolReload = AVAudioPlayer()
    var headShot = AVAudioPlayer()
    var bazookaSet = AVAudioPlayer()
    var bazookaReload = AVAudioPlayer()
    var bazookaShoot = AVAudioPlayer()
    var bazookaHit = AVAudioPlayer()
    var startWhistle = AVAudioPlayer()
    var endWhistle = AVAudioPlayer()
    var rankingAppear = AVAudioPlayer()
    
    var targetCount = 50
    
    var toggleActionInterval = 0.2
    var lastCameraPos = SCNVector3()
    var isPlayerRunning = false
    var lastPlayerStatus = false
    
    var currentWeaponIndex = 0
    
    var timer:Timer!
    var timeCount:Double = 30.00
    
    var explosionCount = 0
    
    var exploPar: SCNParticleSystem?
    
    var bulletNode: SCNNode?
    var bazookaHitExplosion: SCNNode?
    var jetFire: SCNNode?
    var targetNode: SCNNode?
    
    private var presenter: GamePresenter?
    var viewModel = GameViewModel()
    
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var pistolBulletsCountImageView: UIImageView!
    @IBOutlet weak var sightImageView: UIImageView!
    @IBOutlet weak var targetCountLabel: UILabel!
    
    @IBOutlet weak var switchWeaponButton: UIButton!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupScnView()
        getAccelerometer()
        getGyro()
        
        let scene = SCNScene(named: "art.scnassets/target.scn")
        targetNode = (scene?.rootNode.childNode(withName: "target", recursively: false))!
        targetNode?.scale = SCNVector3(0.25, 0.25, 0.25)
        
        let targetNodeGeometry = (targetNode?.childNode(withName: "sphere", recursively: false)?.geometry)!
        
        let shape = SCNPhysicsShape(geometry: targetNodeGeometry, options: nil)
        
        //当たり判定用のphysicBodyを追加
        targetNode?.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        targetNode?.physicsBody?.isAffectedByGravity = false
        
        
        //ロケラン名中時の爆発
        let explosionScene = SCNScene(named: "art.scnassets/ParticleSystem/Explosion1.scn")
        //注意:scnのファイル名ではなく、Identity欄のnameを指定する
        bazookaHitExplosion = (explosionScene?.rootNode.childNode(withName: "Explosion1", recursively: false))
        
        exploPar = bazookaHitExplosion?.particleSystems?.first!
        
        
        self.presenter = GamePresenter(listener: self)
        presenter?.viewDidLoad()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            
            self.startWhistle.play()
            
            self.presenter?.isShootEnabled = true
            
            self.timer = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(self.timerUpdate(timer:)), userInfo: nil, repeats: true)
        }
        
        targetCountLabel.font = targetCountLabel.font.monospacedDigitFont

        
    }
    
    //タイマーで指定間隔ごとに呼ばれる関数
    @objc func timerUpdate(timer: Timer) {
        let lowwerTime = 0.00
        timeCount = max(timeCount - 0.01, lowwerTime)
        let strTimeCount = String(format: "%.2f", timeCount)
        let twoDigitTimeCount = timeCount > 10 ? "\(strTimeCount)" : "0\(strTimeCount)"
        targetCountLabel.text = twoDigitTimeCount
        
        //タイマーが0になったらタイマーを破棄して結果画面へ遷移
        if timeCount <= 0 {
            
            timer.invalidate()
            presenter?.isShootEnabled = false

            endWhistle.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: {
                
                self.viewModel.rankingWillAppear.onNext(Void())
                
                self.rankingAppear.play()
                
                let storyboard: UIStoryboard = UIStoryboard(name: "WorldRankingViewController", bundle: nil)
                let vc = storyboard.instantiateViewController(withIdentifier: "WorldRankingViewController") as! WorldRankingViewController
                self.present(vc, animated: true)
            })
            
        }
    }
    
    @IBAction func switchWeaponButtonTapped(_ sender: Any) {
        
        sightImageView.image = nil
        pistolBulletsCountImageView.image = nil
        presenter?.isShootEnabled = false
        
        let storyboard: UIStoryboard = UIStoryboard(name: "SwitchWeaponViewController", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "SwitchWeaponViewController") as! SwitchWeaponViewController
        vc.modalPresentationStyle = .overCurrentContext
        
        vc.switchWeaponDelegate = self
        vc.viewModel = self.viewModel
//        vc.modalPresentationStyle = .overFullScreen
        
        self.present(vc, animated: true)
        
//        let navi = UINavigationController(rootViewController: vc)
//        navi.setNavigationBarHidden(true, animated: false)
//
//        self.presentPanModal(navi)
    }
    
    func setupScnView() {
        //シーンの作成
        sceneView.scene = SCNScene()
        //光源の有効化
        sceneView.autoenablesDefaultLighting = true;
        //ARSCNViewデリゲートの指定
        sceneView.delegate = self
        //衝突検知のためのDelegate設定
        sceneView.scene.physicsWorld.contactDelegate = self
    }
    
    //ビュー表示時に呼ばれる
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        //コンフィギュレーションの生成
        let configuration = ARWorldTrackingConfiguration()
        //平面検出の有効化
        configuration.planeDetection = .horizontal
        //セッションの開始
        sceneView.session.run(configuration)
    }
    
    //ビュー非表示時に呼ばれる
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        //セッションの一時停止
        sceneView.session.pause()
    }
    
    //常に更新され続けるdelegateメソッド
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        //現在表示中の武器をラップしている空のオブジェクトを常にカメラと同じPositionに移動させ続ける（それにより武器が常にFPS位置に保たれる）
        if let pistol = sceneView.scene.rootNode.childNode(withName: "parent", recursively: false) {
            pistol.position = sceneView.pointOfView?.position ?? SCNVector3()
        }
        if let bazooka = sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false) {
            bazooka.position = sceneView.pointOfView?.position ?? SCNVector3()
        }
        
        if toggleActionInterval <= 0 {
            guard let currentPos = sceneView.pointOfView?.position else {return}
            let diff = SCNVector3Make(lastCameraPos.x - currentPos.x, lastCameraPos.y - currentPos.y, lastCameraPos.z - currentPos.z)
            let distance = sqrt((diff.x * diff.x) + (diff.y * diff.y) + (diff.z * diff.z))
//            print("0.2秒前からの移動距離: \(String(format: "%.1f", distance))m")
            
            isPlayerRunning = (distance >= 0.15)
            
            if isPlayerRunning != lastPlayerStatus {
                
                switch currentWeaponIndex {
                case 0:
                    sceneView.scene.rootNode.childNode(withName: "parent", recursively: false)?.childNode(withName: "M1911_a", recursively: false)?.removeAllActions()
                    sceneView.scene.rootNode.childNode(withName: "parent", recursively: false)?.childNode(withName: "M1911_a", recursively: false)?.position = SCNVector3(0.17, -0.197, -0.584)
                    sceneView.scene.rootNode.childNode(withName: "parent", recursively: false)?.childNode(withName: "M1911_a", recursively: false)?.eulerAngles = SCNVector3(-1.4382625, 1.3017014, -2.9517007)
                case 5:
                    sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false)?.childNode(withName: "bazooka", recursively: false)?.removeAllActions()
                    sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false)?.childNode(withName: "bazooka", recursively: false)?.position = SCNVector3(0, 0, 0)
                    sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false)?.childNode(withName: "bazooka", recursively: false)?.eulerAngles = SCNVector3(0, 0, 0)
                default: break
                }

                isPlayerRunning ? gunnerShakeAnimationRunning(currentWeaponIndex) : gunnerShakeAnimationNormal(currentWeaponIndex)
            }
            self.toggleActionInterval = 0.2
            lastCameraPos = sceneView.pointOfView?.position ?? SCNVector3()
            lastPlayerStatus = isPlayerRunning
        }
        toggleActionInterval -= 0.02
    }
    
    func gunnerShakeAnimationNormal(_ weaponIndex: Int) {
        //銃の先端が上に跳ね上がる回転のアニメーション
        let rotateAction = SCNAction.rotateBy(x: -0.1779697224, y: 0.0159312604, z: -0.1784194, duration: 1.2)
        //↑の逆（下に戻る回転）
        let reverse = rotateAction.reversed()
        //上下のアニメーションを直列に実行するアニメーション
        let rotate = SCNAction.sequence([rotateAction, reverse])
        
        //銃が垂直に持ち上がるアニメーション
        let moveUp = SCNAction.moveBy(x: 0, y: 0.01, z: 0, duration: 0.8)
        //↑の逆（垂直に下に下がる）
        let moveDown = moveUp.reversed()
        //上下のアニメーションを直列に実行するアニメーション
        let move = SCNAction.sequence([moveUp, moveDown])
        
        //回転と上下移動のアニメーションを並列に同時実行するアニメーション(それぞれのdurationをずらすことによって不規則な動き感を出している)
        let conbineAction = SCNAction.group([rotate, move])
        
        //↑を永遠繰り返すアニメーション
        let repeatAction = SCNAction.repeatForever(conbineAction)
        
        //実行
        switch weaponIndex {
        case 0:
            sceneView.scene.rootNode.childNode(withName: "parent", recursively: false)?.childNode(withName: "M1911_a", recursively: false)?.runAction(repeatAction)
//        case 5:
//            sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false)?.childNode(withName: "bazooka", recursively: false)?.runAction(repeatAction)
        default: break
        }
    }
    
    func gunnerShakeAnimationRunning(_ weaponIndex: Int) {
        //銃が右に移動するアニメーション
        let moveRight = SCNAction.moveBy(x: 0.03, y: 0, z: 0, duration: 0.3)
        //↑の逆（左に移動）
        let moveLeft = moveRight.reversed()
        
        //銃が垂直に持ち上がるアニメーション
        let moveUp = SCNAction.moveBy(x: 0, y: 0.02, z: 0, duration: 0.15)
        //↑の逆（垂直に下に下がる）
        let moveDown = moveUp.reversed()
        //上下交互
        let upAndDown = SCNAction.sequence([moveUp, moveDown])
        
        let rightAndUpDown = SCNAction.group([moveRight, upAndDown])
        let LeftAndUpDown = SCNAction.group([moveLeft, upAndDown])
        
        //回転と上下移動のアニメーションを並列に同時実行するアニメーション(それぞれのdurationをずらすことによって不規則な動き感を出している)
        let conbineAction = SCNAction.sequence([rightAndUpDown, LeftAndUpDown])
        
        //↑を永遠繰り返すアニメーション
        let repeatAction = SCNAction.repeatForever(conbineAction)
        
        //実行
        switch weaponIndex {
        case 0:
            sceneView.scene.rootNode.childNode(withName: "parent", recursively: false)?.childNode(withName: "M1911_a", recursively: false)?.runAction(repeatAction)
//        case 5:
//            sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false)?.childNode(withName: "bazooka", recursively: false)?.runAction(repeatAction)
        default: break
        }
    }
    
    func shootingAnimation() {
        //発砲時に銃の先端が上に跳ね上がる回転のアニメーション
        let rotateAction = SCNAction.rotateBy(x: -0.9711356901, y: -0.08854044763, z: -1.013580166, duration: 0.1)
        //↑の逆（下に戻る回転）
        let reverse = rotateAction.reversed()
        //上下のアニメーションを直列に実行するアニメーション
        let shoot = SCNAction.sequence([rotateAction, reverse])
        
        //実行
        sceneView.scene.rootNode.childNode(withName: "parent", recursively: false)?.childNode(withName: "M1911_a", recursively: false)?.runAction(shoot)
    }
    
    func addExplosion() {
        let scene = SCNScene(named: "art.scnassets/Explosion1.scn")
        //注意:scnのファイル名ではなく、Identity欄のnameを指定する
        let node = (scene?.rootNode.childNode(withName: "Explosion1", recursively: false))!
        
        let pos = sceneView.pointOfView?.position ?? SCNVector3()
        node.position = SCNVector3(pos.x, pos.y - 10, pos.z - 10)
//        node.scale = SCNVector3(1, 1, 1)
        self.sceneView.scene.rootNode.addChildNode(node)
    }
    
    //衝突検知時に呼ばれる
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        let nodeA = contact.nodeA
        let nodeB = contact.nodeB
        
        if (nodeA.name == "bullet" && nodeB.name == "target") || (nodeB.name == "bullet" && nodeA.name == "target") {
            print("当たった")
            headShot.play()
            nodeA.removeFromParentNode()
            nodeB.removeFromParentNode()
            
//            if let jetFire = self.sceneView.scene.rootNode.childNode(withName: "jetFire", recursively: false) {
//                print("jetFireを削除しました")
//                jetFire.removeFromParentNode()
//            }
            
            if currentWeaponIndex == 5 {
                bazookaHit.play()
                
                print("衝突時origin loops :\(self.exploPar?.loops)")
                
                if let sub = sceneView.scene.rootNode.childNode(withName: "bazookaHitExplosion\(explosionCount)", recursively: false) {
                    
                    print("衝突時subあります count:\(explosionCount)")
                    
                    if let first = sub.particleSystems?.first {
                        print("衝突時 firstあります: \(first)")
                        first.birthRate = 300
                        first.loops = false
                        
                        print("衝突時falseにしたあと :\(first)")
                    }else {
                        print("衝突時 firstありません")
                    }
                    
                }else {
                    print("衝突時subありません count:\(explosionCount)")
                }
                
            }
            
//            targetCount -= 1
//            DispatchQueue.main.async {
//            }
        }
    }
    
    //加速度設定
    func getAccelerometer() {
        motionManager.accelerometerUpdateInterval = 0.2
        motionManager.startAccelerometerUpdates(to: OperationQueue()) {
            (data, error) in
            
            print("acce")
            if let error = error {
                print("acce error: \(error)")
            }
            
            DispatchQueue.main.async {
                guard let acceleration = data?.acceleration else { return }
                self.presenter?.accele = acceleration
                self.presenter?.didUpdateAccelerationData(data: acceleration)
            }
        }
    }
    //ジャイロ設定
    func getGyro() {
        motionManager.gyroUpdateInterval = 0.2
        motionManager.startGyroUpdates(to: OperationQueue()) {
            (data, error) in
            
            print("gyro")
            if let error = error {
                print("gyro error: \(error)")
            }
            
            DispatchQueue.main.async {
                guard let rotationRate = data?.rotationRate else { return }
                self.presenter?.gyro = rotationRate
                self.presenter?.didUpdateGyroData(data: rotationRate)
            }
        }
    }
}

//SwitchWeaponVCでのセルタップをトリガーに発火させる武器切り替えメソッド
extension GameViewController: SwitchWeaponDelegate {
    
    func selectedAt(index: Int) {
        
        print("current: \(currentWeaponIndex), selectedAt: \(index)")
        
        switch index {
        case 0:
            if index != currentWeaponIndex {
                addPistol()
            }
            setBulletsImageView(with: UIImage(named: "bullets\(presenter?.pistolBulletsCount ?? 0)"))
            pistolBulletsCountImageView.contentMode = .scaleAspectFit
            sightImageView.image = UIImage(named: "pistolSight")
            sightImageView.tintColor = .systemRed
            
        case 5:
            if index != currentWeaponIndex {
                addBazooka()
            }
            setBulletsImageView(with: UIImage(named: "bazookaRocket\(presenter?.bazookaRocketCount ?? 0)"))
            pistolBulletsCountImageView.contentMode = .scaleAspectFill
            sightImageView.image = UIImage(named: "bazookaSight")
            sightImageView.tintColor = .systemGreen
            
        default:
            print("まだ開発中の武器が選択されたので何も処理せずに終了")
            return
        }
        
        currentWeaponIndex = index
        presenter?.currentWeaponIndex = index
        presenter?.isShootEnabled = true
        
    }
    
}

extension GameViewController: GameInterface {
    func addPistol() {
        //バズーカを削除
        if let detonator = self.sceneView.scene.rootNode.childNode(withName: "bazookaParent", recursively: false) {
            print("bazookaを削除しました")
            detonator.removeFromParentNode()
        }
        let scene = SCNScene(named: "art.scnassets/Weapon/Pistol/M1911_a.scn")
        //注意:scnのファイル名ではなく、Identity欄のnameを指定する
        let parentNode = (scene?.rootNode.childNode(withName: "parent", recursively: false))!
        
        let billBoardConstraint = SCNBillboardConstraint()
        parentNode.constraints = [billBoardConstraint]
        
        parentNode.position = sceneView.pointOfView?.position ?? SCNVector3()
        self.sceneView.scene.rootNode.addChildNode(parentNode)
        
        //チャキッ　の再生
        self.pistolSet.play()
        
        gunnerShakeAnimationNormal(0)
    }
    
    func addBazooka() {
        //ピストルを削除
        if let detonator = self.sceneView.scene.rootNode.childNode(withName: "parent", recursively: false) {
            print("pistolを削除しました")
            detonator.removeFromParentNode()
        }
        let scene = SCNScene(named: "art.scnassets/Weapon/RocketLauncher/bazooka2.scn")
        //注意:scnのファイル名ではなく、Identity欄のnameを指定する
        let bazooka = (scene?.rootNode.childNode(withName: "bazookaParent", recursively: false))!
        
        let billBoardConstraint = SCNBillboardConstraint()
        bazooka.constraints = [billBoardConstraint]
        
        bazooka.position = sceneView.pointOfView?.position ?? SCNVector3()
        self.sceneView.scene.rootNode.addChildNode(bazooka)

        //チャキッ　の再生
        self.bazookaSet.play()
        
        gunnerShakeAnimationNormal(5)
    }
    
    //弾ノードを設置
    func addBullet() {
        guard let cameraPos = sceneView.pointOfView?.position else {return}
        //        guard bulletNode == nil else {return}
//        let position = SCNVector3(x: cameraPos.x, y: cameraPos.y, z: cameraPos.z)
        let sphere: SCNGeometry = SCNSphere(radius: 0.05)
        let customYellow = UIColor(red: 253/255, green: 202/255, blue: 119/255, alpha: 1)
        
        sphere.firstMaterial?.diffuse.contents = customYellow
        bulletNode = SCNNode(geometry: sphere)
        guard let bulletNode = bulletNode else {return}
        bulletNode.name = "bullet"
        bulletNode.scale = SCNVector3(x: 1, y: 1, z: 1)
        bulletNode.position = cameraPos
        
        //当たり判定用のphysicBodyを追加
        let shape = SCNPhysicsShape(geometry: sphere, options: nil)
        bulletNode.physicsBody = SCNPhysicsBody(type: .dynamic, shape: shape)
        bulletNode.physicsBody?.contactTestBitMask = 1
        bulletNode.physicsBody?.isAffectedByGravity = false

        if currentWeaponIndex == 5 {
            explosionCount += 1

            var parti: SCNParticleSystem? = SCNParticleSystem()
            parti?.loops = true
            
            parti = exploPar
            
            parti?.loops = true
            
            if let par = parti {

                par.birthRate = 0
                print("loops: \(par.loops)")
                
                print("origin loops :\(self.exploPar?.loops)")
                print("parti loops: \(par.loops)")
                
                let node = SCNNode()
                node.addParticleSystem(par)
                node.name = "bazookaHitExplosion\(explosionCount)"
                node.position = cameraPos
                sceneView.scene.rootNode.addChildNode(node)
            }
            
        }
        
        sceneView.scene.rootNode.addChildNode(bulletNode)
        
        print("弾を設置")
    }
    
    //弾ノードを発射
    func shootBullet() {
        guard let camera = sceneView.pointOfView else {return}
        let targetPosCamera = SCNVector3(x: camera.position.x, y: camera.position.y, z: camera.position.z - 10)
        //カメラ座標をワールド座標に変換
        let target = camera.convertPosition(targetPosCamera, to: nil)
        let action = SCNAction.move(to: target, duration: TimeInterval(1))
        bulletNode?.runAction(action, completionHandler: {
            self.bulletNode?.removeFromParentNode()
        })
        
        if currentWeaponIndex == 5 {

            sceneView.scene.rootNode.childNode(withName: "bazookaHitExplosion\(explosionCount)", recursively: false)?.runAction(action)
            
        }
        
        shootingAnimation()
        
        print("弾を発射")
    }
    
    //的ノードを設置
    func addTarget() {
        
        //ランダムな座標に10回設置
        DispatchQueue.main.async {
            for _ in 0..<self.targetCount {

                let randomX = Float.random(in: -3...3)
                let randomY = Float.random(in: -1.5...2)
                let randomZfirst = Float.random(in: -3...(-0.5))
                let randomZsecond = Float.random(in: 0.5...3)
                let randomZthird = Float.random(in: -3...3)
                var randomZ: Float?
                
                if randomX < -0.5 || randomX > 0.5 || randomY < -0.5 || randomY > 0.5 {
                    randomZ = randomZthird
                }else {
                    randomZ = [randomZfirst, randomZsecond].randomElement()
                }
                let randomPosition = SCNVector3(x: randomX, y: randomY, z: randomZ ?? 0)
                
                let cloneTargetNode = self.targetNode?.clone()
                
                cloneTargetNode?.position = randomPosition
                
                //常にカメラを向く制約
                let billBoardConstraint = SCNBillboardConstraint()
                cloneTargetNode?.constraints = [billBoardConstraint]
                
                self.sceneView.scene.rootNode.addChildNode(cloneTargetNode ?? SCNNode())
                print("的を設置")
            }
        }
    }
    
    func setSounds(for soundType: SoundType?) {
        setAudioPlayer(forIndex: 1, resourceFileName: "pistol-slide")
        setAudioPlayer(forIndex: 2, resourceFileName: "pistol-fire")
        setAudioPlayer(forIndex: 3, resourceFileName: "pistol-out-bullets")
        setAudioPlayer(forIndex: 4, resourceFileName: "pistol-reload")
        setAudioPlayer(forIndex: 5, resourceFileName: "headShot")
        setAudioPlayer(forIndex: 6, resourceFileName: "bazookaSet")
        setAudioPlayer(forIndex: 7, resourceFileName: "bazookaReload")
        setAudioPlayer(forIndex: 8, resourceFileName: "bazookaShoot")
        setAudioPlayer(forIndex: 9, resourceFileName: "bazookaHit")
        setAudioPlayer(forIndex: 10, resourceFileName: "startWhistle")
        setAudioPlayer(forIndex: 11, resourceFileName: "endWhistle")
        setAudioPlayer(forIndex: 12, resourceFileName: "rankingAppear")
    }
    
    func playSound(of index: Int) {
        switch index {
        case 1:
            pistolSet.currentTime = 0
            pistolSet.play()
        case 2:
            pistolShoot.currentTime = 0
            pistolShoot.play()
        case 3:
            pistolOutBullets.currentTime = 0
            pistolOutBullets.play()
        case 4:
            pistolReload.currentTime = 0
            pistolReload.play()
        case 5:
            headShot.currentTime = 0
            headShot.play()
        case 6:
            bazookaSet.currentTime = 0
            bazookaSet.play()
        case 7:
            bazookaReload.currentTime = 0
            bazookaReload.play()
        case 8:
            bazookaShoot.currentTime = 0
            bazookaShoot.play()
        case 9:
            bazookaHit.currentTime = 0
            bazookaHit.play()
        case 10:
            startWhistle.currentTime = 0
            startWhistle.play()
        case 11:
            endWhistle.currentTime = 0
            endWhistle.play()
        case 12:
            rankingAppear.currentTime = 0
            rankingAppear.play()
        default: break
        }
    }
    
    func vibration() {
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
    }
    
    func setBulletsImageView(with image: UIImage?) {
        pistolBulletsCountImageView.image = image
    }
}

extension GameViewController: AVAudioPlayerDelegate {

    private func setAudioPlayer(forIndex index: Int, resourceFileName: String) {
        guard let path = Bundle.main.path(forResource: resourceFileName, ofType: "mp3") else {
            print("音源\(index)が見つかりません")
            return
        }
        do {
            switch index {
            case 1:
                pistolSet = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                pistolSet.prepareToPlay()
            case 2:
                pistolShoot = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                pistolShoot.prepareToPlay()
            case 3:
                pistolOutBullets = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                pistolOutBullets.prepareToPlay()
            case 4:
                pistolReload = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                pistolReload.prepareToPlay()
            case 5:
                headShot = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                headShot.prepareToPlay()
            case 6:
                bazookaSet = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                bazookaSet.prepareToPlay()
            case 7:
                bazookaReload = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                bazookaReload.prepareToPlay()
            case 8:
                bazookaShoot = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                bazookaShoot.prepareToPlay()
            case 9:
                bazookaHit = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                bazookaHit.prepareToPlay()
            case 10:
                startWhistle = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                startWhistle.prepareToPlay()
            case 11:
                endWhistle = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                endWhistle.prepareToPlay()
            case 12:
                rankingAppear = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
                rankingAppear.prepareToPlay()
                
            default:
                break
            }
        } catch {
            print("音声セットエラー")
        }
    }
}





//タイムカウント（0.01秒刻みで動く）を等幅フォントにして左右のブレをなくす設定
extension UIFont {
    var monospacedDigitFont: UIFont {
        let oldFontDescriptor = fontDescriptor
        let newFontDescriptor = oldFontDescriptor.monospacedDigitFontDescriptor
        return UIFont(descriptor: newFontDescriptor, size: 0)
    }
}

private extension UIFontDescriptor {
    var monospacedDigitFontDescriptor: UIFontDescriptor {
        let fontDescriptorFeatureSettings = [[UIFontDescriptor.FeatureKey.featureIdentifier: kNumberSpacingType, UIFontDescriptor.FeatureKey.typeIdentifier: kMonospacedNumbersSelector]]
        let fontDescriptorAttributes = [UIFontDescriptor.AttributeName.featureSettings: fontDescriptorFeatureSettings]
        let fontDescriptor = self.addingAttributes(fontDescriptorAttributes)
        return fontDescriptor
    }
}
