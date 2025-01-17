//
//  ARContentController.swift
//  AR-GunMan
//
//  Created by 深瀬 on 2024/05/13.
//

import ARKit
import SceneKit
import RxSwift
import RxCocoa

final class ARContentController: NSObject {
    private var sceneView: ARSCNView!
    private let targetHitRelay = PublishRelay<WeaponType>()
    
    var targetHit: Observable<WeaponType> {
        return targetHitRelay.asObservable()
    }
    
    private var originalBazookaHitExplosionParticle = SCNParticleSystem()
    private var pistolParentNode = SCNNode()
    private var bazookaParentNode = SCNNode()
    private var originalBulletNode = SceneNodeUtil.originalBulletNode()

    func setupSceneView(with frame: CGRect) -> UIView {
        sceneView = ARSCNView(frame: frame)

        //SceneViewをセットアップ
        SceneViewSettingUtil.setupSceneView(sceneView, sceneViewDelegate: self, physicContactDelegate: self)
        //各武器をセットアップ
        pistolParentNode = setupWeaponNode(type: .pistol)
        bazookaParentNode = setupWeaponNode(type: .bazooka)
        originalBazookaHitExplosionParticle = createOriginalParticleSystem(type: .bazookaExplosion)
        
        return sceneView
    }

    // 的ノードをランダムな座標に設置
    func showTargets(count: Int) {
        let originalTargetNode = SceneNodeUtil.originalTargetNode()
        
        DispatchQueue.main.async {
            Array(0..<count).forEach { _ in
                //メモリ節約のため、オリジナルをクローンして使う
                let clonedTargetNode = originalTargetNode.clone()
                clonedTargetNode.position = SceneNodeUtil.getRandomTargetPosition()
                SceneNodeUtil.addBillboardConstraint(clonedTargetNode)
                self.sceneView.scene.rootNode.addChildNode(clonedTargetNode)
            }
        }
    }

    func startSession() {
        SceneViewSettingUtil.startSession(sceneView)
    }
    
    func pauseSession() {
        SceneViewSettingUtil.pauseSession(sceneView)
    }

    func showWeapon(_ type: WeaponType) {
        switchWeapon(to: type)
    }
    
    func fireWeapon(_ type: WeaponType) {
        shootBullet(of: type)
        // TODO: 共通処理に変える（今は反動アニメーションはピストルだけだが）
        pistolNode().runAction(SceneAnimationUtil.shootingMotion())
    }

    func changeTargetsToTaimeisan() {
        sceneView.scene.rootNode.childNodes.forEach({ node in
            if node.name == ARContentConst.targetNodeName {
                while node.childNode(withName: "torus", recursively: false) != nil {
                    node.childNode(withName: "torus", recursively: false)?.removeFromParentNode()
                    //ドーナツ型の白い線のパーツを削除
                    print("torusを削除")
                }
                node.childNode(withName: "sphere", recursively: false)?.geometry?.firstMaterial?.diffuse.contents = UIImage(named: ARContentConst.taimeiSanImageName)
            }
        })
    }

    private func setupWeaponNode(type: WeaponType) -> SCNNode {
        let weaponParentNode = SceneNodeUtil.loadScnFile(of: type.scnAssetsPath, nodeName: type.parentNodeName)
        SceneNodeUtil.addBillboardConstraint(weaponParentNode)
        weaponParentNode.position = SceneNodeUtil.getCameraPosition(sceneView)
        return weaponParentNode
    }
    
    private func pistolNode() -> SCNNode {
        return pistolParentNode.childNode(withName: WeaponType.pistol.name, recursively: false) ?? SCNNode()
    }
    
    private func switchWeapon(to nextWeapon: WeaponType) {
        SceneNodeUtil.removeOtherWeapon(except: nextWeapon, scnView: sceneView)
        switch nextWeapon {
        case .pistol:
            sceneView.scene.rootNode.addChildNode(pistolParentNode)
            pistolNode().runAction(SceneAnimationUtil.gunnerShakeAnimationNormal())
        case .bazooka:
            sceneView.scene.rootNode.addChildNode(bazookaParentNode)
        }
    }
    
    //ロケラン名中時の爆発をセットアップ
    private func createOriginalParticleSystem(type: ParticleSystemType) -> SCNParticleSystem {
        let originalExplosionNode = SceneNodeUtil.loadScnFile(of: type.scnAssetsPath, nodeName: type.name)
        return originalExplosionNode.particleSystems?.first ?? SCNParticleSystem()
    }
    
    private func createTargetHitParticleNode(type: ParticleSystemType) -> SCNNode {
        originalBazookaHitExplosionParticle.birthRate = 0
        originalBazookaHitExplosionParticle.loops = true
        let targetHitParticleNode = SCNNode()
        switch type {
        case .bazookaExplosion:
            targetHitParticleNode.addParticleSystem(originalBazookaHitExplosionParticle)
            return targetHitParticleNode
        }
    }

    //弾ノードを発射
    private func shootBullet(of weaponType: WeaponType) {
        let clonedBulletNode = CustomSCNNode(
            //メモリ節約のため、オリジナルをクローンして使う
            from: originalBulletNode.clone(),
            gameObjectInfo: .init(type: weaponType.gameObjectType)
        )
        clonedBulletNode.position = SceneNodeUtil.getCameraPosition(sceneView)
        sceneView.scene.rootNode.addChildNode(clonedBulletNode)
        clonedBulletNode.runAction(
            SceneAnimationUtil.shootBulletToCenterOfCamera(sceneView.pointOfView), completionHandler: {
                clonedBulletNode.removeFromParentNode()
            }
        )
    }
    
    //現在表示中の武器をラップしている空のオブジェクトを常にカメラと同じPositionに移動させ続ける（それにより武器が常にFPS位置に保たれる）
    private func moveWeaponToFPSPosition() {
        pistolParentNode.position = SceneNodeUtil.getCameraPosition(sceneView)
        bazookaParentNode.position = SceneNodeUtil.getCameraPosition(sceneView)
    }
    
    private func showTargetHitParticleToContactPoint(weaponType: WeaponType, contactPoint: SCNVector3) {
        guard let targetHitParticleType = weaponType.targetHitParticleType else { return}
        let targetHitParticleNode = createTargetHitParticleNode(type: targetHitParticleType)
        targetHitParticleNode.position = contactPoint
        sceneView.scene.rootNode.addChildNode(targetHitParticleNode)
        targetHitParticleNode.particleSystems?.first?.birthRate = targetHitParticleType.birthRate
        targetHitParticleNode.particleSystems?.first?.loops = false
    }
}

extension ARContentController: ARSCNViewDelegate {
    //常に更新され続けるdelegateメソッド
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        moveWeaponToFPSPosition()
    }
}

extension ARContentController: SCNPhysicsContactDelegate {
    //衝突検知時に呼ばれる
    //MEMO: - このメソッド内でUIの更新を行いたい場合はmainThreadで行う
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        guard let firstObject = contact.nodeA as? CustomSCNNode,
              let secondObject = contact.nodeB as? CustomSCNNode else {
            return
        }
        let (isTargetHit, weaponType) = TargetHitChecker.isTargetHit(
            firstObjectInfo: firstObject.gameObjectInfo,
            secondObjectInfo: secondObject.gameObjectInfo
        )
        guard isTargetHit,
              let weaponType = weaponType else {
            return
        }
        // 衝突した2つのオブジェクトを削除
        firstObject.removeFromParentNode()
        secondObject.removeFromParentNode()
        // 衝突検知座標に武器に応じた特殊効果を表示
        showTargetHitParticleToContactPoint(
            weaponType: weaponType,
            contactPoint: contact.contactPoint
        )
        // 弾がターゲットにヒットしたことと、どの武器だったかを通知
        targetHitRelay.accept(weaponType)
    }
}
