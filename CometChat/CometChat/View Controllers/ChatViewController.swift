//
//  ViewController.swift
//  CometChat
//
//  Created by Marin Benčević on 01/08/2019.
//  Copyright © 2019 marinbenc. All rights reserved.
//

import UIKit

final class ChatViewController: UIViewController {
  
  private enum Constants {
    static let incomingMessageCell = "incomingMessageCell"
    static let outgoingMessageCell = "outgoingMessageCell"
    static let contentInset: CGFloat = 24
    static let placeholderMessage = "Type something"
  }
  
  public var receiver: User!
  
  // MARK: - Outlets
  
  @IBOutlet weak var tableView: UITableView!
  @IBOutlet weak var textView: UITextView!
  @IBOutlet weak var textAreaBackground: UIView!
  @IBOutlet weak var textAreaBottom: NSLayoutConstraint!
  @IBOutlet weak var emptyChatView: UIView!
  
  /// The space between the bottom of the typing indicator and the top of the message input area.
  /// Positive values mean that the typing indicator is below the message area, so it's not visible.
  /// By setting it to a negative value, you raise it above the message are and thus make it visible.
  private var typingIndicatorBottomConstraint: NSLayoutConstraint!
  
  private func createTypingIndicator() {
    let typingIndicator = TypingIndicatorView(receiverName: receiver.name)
    view.insertSubview(typingIndicator, belowSubview: textAreaBackground)
    
    typingIndicatorBottomConstraint = typingIndicator.bottomAnchor.constraint(
      equalTo: textAreaBackground.topAnchor,
      // Set the constant to 16 at start. This means that the top of the
      // typing indicator will be below the top of the text area.
      constant: 16)
    typingIndicatorBottomConstraint.isActive = true

    NSLayoutConstraint.activate([
      typingIndicator.heightAnchor.constraint(equalToConstant: 20),
      typingIndicator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 26)
    ])

  }
  
  private func setTypingIndicatorVisible(_ isVisible: Bool) {
    let constant: CGFloat = isVisible ? -16 : 16
    UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseInOut, animations: {
      self.typingIndicatorBottomConstraint.constant = constant
      self.view.layoutIfNeeded()
    })
  }

  
  // MARK: - Actions
  
  @IBAction func onSendButtonTapped(_ sender: Any) {
    sendMessage()
  }
  
  
  // MARK: - Interaction
  
  private func sendMessage() {
    let message: String = textView.text
    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return
    }
    
    textView.endEditing(true)
    addTextViewPlaceholer()
    scrollToLastCell()
    
    ChatService.shared.stopTyping(to: receiver)
    ChatService.shared.send(message: message, to: receiver)
  }
  
  var messages: [Message] = [] {
    didSet {
      // Hide the "no messages" view if there are messages
      emptyChatView.isHidden = !messages.isEmpty
      tableView.reloadData()
    }
  }
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    title = receiver.name
    
    // By default, show the "no messages" view
    emptyChatView.isHidden = false
    
    setUpTableView()
    setUpTextView()
    startObservingKeyboard()
    tableView.dataSource = self
    
    ChatService.shared.onReceivedMessage = { [weak self] message in
      guard let self = self else { return }
      let isFromReceiver = message.user == self.receiver
      // Only add the message if it comes from the current user or
      // the receiver of this screen. Without this check, messages
      // from other users could get added to the list.
      if !message.isIncoming || isFromReceiver {
        self.messages.append(message)
        self.scrollToLastCell()
      }
    }
    
    createTypingIndicator()
    
    ChatService.shared.onTypingStarted = { [weak self] user in
      // Only show the typing indicator if this screen's receiver is typing.
      if user.id == self?.receiver.id {
        self?.setTypingIndicatorVisible(true)
      }
    }

    ChatService.shared.onTypingEnded = { [weak self] user in
      if user.id == self?.receiver.id {
        self?.setTypingIndicatorVisible(false)
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    addTextViewPlaceholer()
    
    // Load past messages between the current user and the receiver.
    ChatService.shared.getMessages(from: receiver) { [weak self] messages in
      self?.messages = messages
      self?.scrollToLastCell()
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    // Add default shadow to navigation bar
    let navigationBar = navigationController?.navigationBar
    navigationBar?.shadowImage = nil
  }
  
  
  // MARK: - Keyboard
  
  private func startObservingKeyboard() {
    let notificationCenter = NotificationCenter.default
    notificationCenter.addObserver(
      forName: UIResponder.keyboardWillShowNotification,
      object: nil,
      queue: nil,
      using: keyboardWillAppear)
    notificationCenter.addObserver(
      forName: UIResponder.keyboardWillHideNotification,
      object: nil,
      queue: nil,
      using: keyboardWillDisappear)
  }
  
  deinit {
    let notificationCenter = NotificationCenter.default
    notificationCenter.removeObserver(
      self,
      name: UIResponder.keyboardWillShowNotification,
      object: nil)
    notificationCenter.removeObserver(
      self,
      name: UIResponder.keyboardWillHideNotification,
      object: nil)
  }
  
  private func keyboardWillAppear(_ notification: Notification) {
    // Get the keyboard height
    let key = UIResponder.keyboardFrameEndUserInfoKey
    guard let keyboardFrame = notification.userInfo?[key] as? CGRect else {
      return
    }
    
    // Remove the safe are offset from the keyboard height
    let safeAreaBottom = view.safeAreaLayoutGuide.layoutFrame.maxY
    let viewHeight = view.bounds.height
    let safeAreaOffset = viewHeight - safeAreaBottom
    
    let lastVisibleCell = tableView.indexPathsForVisibleRows?.last
    
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.curveEaseInOut],
      animations: {
        // Raise the text area to match the keyboard's height
        self.textAreaBottom.constant = -keyboardFrame.height + safeAreaOffset
        self.view.layoutIfNeeded()
        // Scroll to the last message if it's no longer visible
        if let lastVisibleCell = lastVisibleCell {
          self.tableView.scrollToRow(
            at: lastVisibleCell, at: .bottom, animated: false)
        }
    })
  }
  
  private func keyboardWillDisappear(_ notification: Notification) {
    UIView.animate(
      withDuration: 0.3,
      delay: 0,
      options: [.curveEaseInOut],
      animations: {
        self.textAreaBottom.constant = 0
        self.view.layoutIfNeeded()
    })
  }
  
  
  
  
  // MARK: - Set up
  
  private func setUpTextView() {
    textView.isScrollEnabled = false
    textView.textContainer.heightTracksTextView = true
    textView.delegate = self
    
    textAreaBackground.layer.addShadow(
      color: UIColor(red: 189 / 255, green: 204 / 255, blue: 215 / 255, alpha: 54 / 100),
      offset: CGSize(width: 2, height: -2),
      radius: 4)
  }
  
  private func setUpTableView() {
    tableView.rowHeight = UITableView.automaticDimension
    tableView.estimatedRowHeight = 80
    tableView.tableFooterView = UIView()
    tableView.separatorStyle = .none
    tableView.contentInset = UIEdgeInsets(top: Constants.contentInset, left: 0, bottom: 0, right: 0)
    tableView.allowsSelection = false
  }
  
}

// MARK: - UITableViewDataSource
extension ChatViewController: UITableViewDataSource {
  
  func tableView(
    _ tableView: UITableView,
    numberOfRowsInSection section: Int) -> Int {
    messages.count
  }
  
  func tableView(
    _ tableView: UITableView,
    cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    
    let message = messages[indexPath.row]
    // Dequeue either an incoming message cell, or outgoing, depending on
    // if the message is incoming or not.
    let cellIdentifier = message.isIncoming ?
      Constants.incomingMessageCell :
      Constants.outgoingMessageCell
    
    // The cells conform to the `MessageCell` protocol, so we can cast them to
    // `MessageCell & UITableViewCell` protocol composition type.
    guard let cell = tableView.dequeueReusableCell(
      withIdentifier: cellIdentifier, for: indexPath)
      as? MessageCell & UITableViewCell else {
        return UITableViewCell()
    }
    
    cell.message = message
    
    // Only show the avatar if the previous message was from a different user.
    if indexPath.row < messages.count - 1 {
      let nextMessage = messages[indexPath.row + 1]
      cell.showsAvatar = message.isIncoming != nextMessage.isIncoming
    } else {
      cell.showsAvatar = true
    }
    
    return cell
  }
  
  private func scrollToLastCell() {
    let lastRow = tableView.numberOfRows(inSection: 0) - 1
    guard lastRow > 0 else {
      return
    }
    
    let lastIndexPath = IndexPath(row: lastRow, section: 0)
    tableView.scrollToRow(at: lastIndexPath, at: .bottom, animated: true)
  }
}

// MARK: - UITextViewDelegate
extension ChatViewController: UITextViewDelegate {
  
  // By default, a `UITextView` doesn't have placeholders.
  // These functions will add or remove a placeholder to the text view.
  
  private func addTextViewPlaceholer() {
    textView.text = Constants.placeholderMessage
    textView.textColor = .placeholderBody
  }
  
  private func removeTextViewPlaceholder() {
    textView.text = ""
    textView.textColor = .darkBody
  }
  
  // When the user starts typing, remove the placeholder.
  func textViewDidBeginEditing(_ textView: UITextView) {
    removeTextViewPlaceholder()
  }
  
  // When the user stops typing, if the text view is empty, add the placeholder.
  func textViewDidEndEditing(_ textView: UITextView) {
    if textView.text.isEmpty {
      addTextViewPlaceholer()
    }
  }
  
  func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
    let currentText: String = textView.text
    let range = Range(range, in: currentText)!
    // Grab the future value of the text view's text
    let newText = currentText.replacingCharacters(in: range, with: text)
    
    switch (currentText.isEmpty, newText.isEmpty) {
    case (true, false):
      // Text view will stop being empty
      ChatService.shared.startTyping(to: receiver)
    case (false, true):
      // Text view will become empty
      ChatService.shared.stopTyping(to: receiver)
    default:
      break
    }
    
    return true
  }

}

