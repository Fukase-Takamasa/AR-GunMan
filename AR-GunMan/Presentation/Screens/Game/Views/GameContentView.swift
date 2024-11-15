//
//  GameContentView.swift
//  AR-GunMan
//
//  Created by ウルトラ深瀬 on 23/6/24.
//

import UIKit

final class GameContentView: UIView {
    @IBOutlet weak var bulletsCountImageView: UIImageView!
    @IBOutlet weak var sightImageView: UIImageView!
    @IBOutlet weak var timeCountLabel: UILabel!
    @IBOutlet weak var weaponChangeButton: UIButton!
    @IBOutlet weak var fireButton: UIButton!
    @IBOutlet weak var reloadButton: UIButton!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }
    
    private func configure() {
        loadNib()
        setupUI()
    }
    
    private func setupUI() {
        // MEMO: to prevent time count text looks shaking horizontally rapidly.
        timeCountLabel.font = timeCountLabel.font.monospacedDigitFont
    }
}
