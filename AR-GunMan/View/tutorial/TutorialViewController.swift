//
//  TutorialViewController.swift
//  AR-GunMan
//
//  Created by 深瀬 貴将 on 2020/11/23.
//

import UIKit

class TutorialViewController: UIViewController {

    
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var firstImageView: UIImageView!
    @IBOutlet weak var secondImageView: UIImageView!
    @IBOutlet weak var thirdImageView: UIImageView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var bottomButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
        
        pageControl.isUserInteractionEnabled = false
        
        animateFirstImageView()
        animateSecondImageView()
    }
    
    @IBAction func buttonTapped(_ sender: Any) {
        
        if getCurrentScrollViewIndex() == 2 {
            print("OK tapped")
            self.dismiss(animated: true, completion: nil)
        }else {
            scrollPage()
        }
                
    }
    
    func getCurrentScrollViewIndex() -> Int {
        let contentsOffSetX: CGFloat = scrollView.contentOffset.x
        let pageIndex = Int(round(contentsOffSetX / scrollView.frame.width))
        print("currentIndex: \(pageIndex)")
        return pageIndex
    }
    
    func scrollPage() {
        guard !scrollView.isDecelerating else {
            print("scrollview is still decelerating")
            return
        }
        let frameWidth = scrollView.frame.width
        
        let targetContentOffsetX = frameWidth * CGFloat(min(getCurrentScrollViewIndex() + 1, 2))
        let targetCGPoint = CGPoint(x: targetContentOffsetX, y: 0)
        scrollView.setContentOffset(targetCGPoint, animated: true)
    }
    
    func animateFirstImageView() {
        let images = [UIImage(named: "howToShoot0")!, UIImage(named: "howToShoot1")!]
        firstImageView.animationImages = images
        firstImageView.animationDuration = 0.8
        firstImageView.animationRepeatCount = 0
        firstImageView.startAnimating()
    }
    
    func animateSecondImageView() {
        let images = [UIImage(named: "howToReload0")!, UIImage(named: "howToReload1")!]
        secondImageView.animationImages = images
        secondImageView.animationDuration = 0.8
        secondImageView.animationRepeatCount = 0
        secondImageView.startAnimating()
    }
    
}

extension TutorialViewController: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        pageControl.currentPage = getCurrentScrollViewIndex()
        
        if pageControl.currentPage == 2 {
            bottomButton.setTitle("OK", for: .normal)
        }else {
            bottomButton.setTitle("NEXT", for: .normal)
        }
        
    }
    
}
