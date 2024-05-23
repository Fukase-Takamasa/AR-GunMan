//
//  TopUseCase.swift
//  AR-GunMan
//
//  Created by 深瀬 on 2024/04/15.
//

import RxSwift

protocol TopUseCaseInterface {
    func getIsPermittedCameraAccess() -> Observable<Bool>
    func getNeedsReplay() -> Observable<Bool>
    func setNeedsReplay(_ newValue: Bool)
}

final class TopUseCase: TopUseCaseInterface {
    private let avPermissionRepository: AVPermissionRepositoryInterface
    private let replayRepository: ReplayRepositoryInterface
    
    init(
        avPermissionRepository: AVPermissionRepositoryInterface,
        replayRepository: ReplayRepositoryInterface
    ) {
        self.avPermissionRepository = avPermissionRepository
        self.replayRepository = replayRepository
    }
    
    func getIsPermittedCameraAccess() -> Observable<Bool> {
        return avPermissionRepository.getIsPermittedCameraAccess()
    }
    
    func getNeedsReplay() -> Observable<Bool> {
        return replayRepository.getNeedsReplay()
    }
    
    func setNeedsReplay(_ newValue: Bool) {
        replayRepository.setNeedsReplay(newValue)
    }
}