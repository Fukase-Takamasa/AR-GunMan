//
//  WeaponChangeViewController.swift
//  AR-GunMan
//
//  Created by 深瀬 貴将 on 2020/11/03.
//  Copyright © 2020 fukase. All rights reserved.
//

import UIKit
import FSPagerView
import RxSwift
import RxCocoa

class WeaponChangeViewController: UIViewController {
       
    //MARK: - Properties
    var viewModel: WeaponChangeViewModel!
    var vmDependency: WeaponChangeViewModel.Dependency!
    let disposeBag = DisposeBag()
    let itemSelectedRelay = PublishRelay<Int>()
    
    @IBOutlet weak var pagerView: FSPagerView! {
        didSet{
            let nib = UINib(nibName: "WeaponChangeCell", bundle: nil)
            self.pagerView.register(nib, forCellWithReuseIdentifier: "WeaponChangeCell")
        }
    }
    
    //MARK: - Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupFSPagerView()
                
        viewModel = WeaponChangeViewModel(dependency: vmDependency)
        
        // MARK: - input
        let input = WeaponChangeViewModel.Input(
            itemSelected: itemSelectedRelay.asObservable()
        )
                
        // MARK: - output
        let output = viewModel.transform(input: input)
        
        output.dismiss
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.dismiss(animated: true)
            }).disposed(by: disposeBag)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.pagerView.itemSize = CGSize(width: self.view.frame.width * 0.5, height: self.view.frame.height * 0.8)
    }
    
    private func setupFSPagerView() {
        pagerView.delegate = self
        pagerView.dataSource = self
        pagerView.automaticSlidingInterval = 0
        pagerView.isInfinite = true
        pagerView.decelerationDistance = 1
        pagerView.interitemSpacing = 8
        pagerView.transformer = FSPagerViewTransformer(type: .ferrisWheel)
    }
}

extension WeaponChangeViewController: FSPagerViewDelegate {
    func pagerView(_ pagerView: FSPagerView, didSelectItemAt index: Int) {
        itemSelectedRelay.accept(index)
    }
}

extension WeaponChangeViewController: FSPagerViewDataSource {
    func numberOfItems(in pagerView: FSPagerView) -> Int {
        return WeaponType.allCases.count
    }
    
    func pagerView(_ pagerView: FSPagerView, cellForItemAt index: Int) -> FSPagerViewCell {
        guard let cell = pagerView.dequeueReusableCell(withReuseIdentifier: "WeaponChangeCell", at: index) as? WeaponChangeCell else {
            return FSPagerViewCell()
        }
        cell.weaponImageView.image = UIImage(named: WeaponType.allCases[index].name)
        cell.commingSoonLabel.isHidden = true
        return cell
    }
}
