//
//  TypingIndicatorView.swift
//  CometChat
//
//  Created by Marin Benčević on 09/03/2020.
//  Copyright © 2020 marinbenc. All rights reserved.
//

import UIKit

class TypingIndicatorView: UIView {
  
  private enum Constants {
    static let width: CGFloat = 5
    static let scaleDuration: Double = 0.6
    static let scaleAmount: Double = 1.6
    static let delayBetweenRepeats: Double = 0.9
  }
  
  private let recieverName: String
  private var stack: UIStackView!

  init(recieverName: String) {
    self.recieverName = recieverName
    super.init(frame: .zero)
    createView()
  }
  
  required init?(coder: NSCoder) {
    fatalError()
  }
    
  override var intrinsicContentSize: CGSize {
    return stack.intrinsicContentSize
  }
    
  private func createView() {
    translatesAutoresizingMaskIntoConstraints = false
    
    stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .horizontal
    stack.alignment = .center
    stack.spacing = 5
    
    let dots = makeDots()
    stack.addArrangedSubview(dots)
    
    let typingIndicatorLabel = UILabel()
    typingIndicatorLabel.translatesAutoresizingMaskIntoConstraints = false
    stack.addArrangedSubview(typingIndicatorLabel)

    let attributedString = NSMutableAttributedString(
      string: recieverName,
      attributes: [.font: UIFont.boldSystemFont(ofSize: UIFont.systemFontSize)])
    
    let isTypingString = NSAttributedString(
      string: " is typing",
      attributes: [.font: UIFont.systemFont(ofSize: UIFont.systemFontSize)])
    attributedString.append(isTypingString)
    
    typingIndicatorLabel.attributedText = attributedString
        
    addSubview(stack)
    
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: trailingAnchor),
      stack.topAnchor.constraint(equalTo: topAnchor),
      stack.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])
  }
  
  func makeDot(animationDelay: Double) -> UIView {
    let view = UIView(frame: CGRect(
      origin: .zero,
      size: CGSize(width: Constants.width, height: Constants.width)))
    
    view.translatesAutoresizingMaskIntoConstraints = false
    view.widthAnchor.constraint(equalToConstant: Constants.width).isActive = true
    
    let circle = CAShapeLayer()
    let path = UIBezierPath(
      arcCenter: .zero,
      radius: Constants.width / 2,
      startAngle: 0,
      endAngle: 2 * .pi,
      clockwise: true)
    circle.path = path.cgPath

    circle.frame = view.bounds
    circle.fillColor = UIColor.gray.cgColor
    
    view.layer.addSublayer(circle)
    
    let animation = CABasicAnimation(keyPath: "transform.scale")
    animation.duration = Constants.scaleDuration / 2
    animation.toValue = Constants.scaleAmount
    animation.isRemovedOnCompletion = false
    animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    animation.autoreverses = true
    
    let animationGroup = CAAnimationGroup()
    animationGroup.animations = [animation]
    animationGroup.duration = Constants.scaleDuration + Constants.delayBetweenRepeats
    animationGroup.repeatCount = .infinity
    animationGroup.beginTime = CACurrentMediaTime() + animationDelay
    
    circle.add(animationGroup, forKey: "pulse")
    
    return view
  }
  
  private func makeDots() -> UIView {
    let stack = UIStackView()
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .horizontal
    stack.alignment = .bottom
    stack.spacing = 5
    
    stack.heightAnchor.constraint(equalToConstant: Constants.width).isActive = true
    
    let dots: [UIView] = (0..<3).map { i in
      makeDot(animationDelay: Double(i) * 0.3)
    }
    
    dots.forEach(stack.addArrangedSubview)
    
    return stack
  }

}
