//
//  ChatService.swift
//  CometChat
//
//  Created by Marin Benčević on 09/08/2019.
//  Copyright © 2019 marinbenc. All rights reserved.
//

import Foundation
import CometChatPro

extension String: Error {}

final class ChatService {
  
  var onTypingStarted: ((User)-> Void)?
  var onTypingEnded: ((User)-> Void)?

  func startTyping(to receiver: User) {
    let typingIndicator = TypingIndicator(receiverID: receiver.id, receiverType: .user)
    CometChat.startTyping(indicator: typingIndicator)
  }
  func stopTyping(to receiver: User) {
    let typingIndicator = TypingIndicator(receiverID: receiver.id, receiverType: .user)
    CometChat.endTyping(indicator: typingIndicator)
  }

  
  private enum Constants {
    #warning("Don't forget to set your API key and app ID here!")
    static let cometChatAPIKey = "b8db5f3457ef8b1ac4f7c239aa565b36387c2273"
    static let cometChatAppID = "138640e094f002e"
  }
  
  static let shared = ChatService()
  private init() {}
  
  static func initialize() {
    let settings = AppSettings.AppSettingsBuilder()
      .subscribePresenceForAllUsers()
      .setRegion(region: "us")
      .build()
    
    _ = CometChat(
      appId: Constants.cometChatAppID,
      appSettings: settings,
      onSuccess: { isSuccess in
        print("CometChat connected successfully: \(isSuccess)")
      },
      onError: { error in
        print(error.debugDescription)
      })
  }
  
  private var user: User?
  var onReceivedMessage: ((Message)-> Void)?
  var onUserStatusChanged: ((User)-> Void)?
  
  func login(email: String, onComplete: @escaping (Result<User, Error>)-> Void) {
    
    CometChat.messagedelegate = self
    CometChat.userdelegate = self
    
    CometChat.login(
      UID: email,
      apiKey: Constants.cometChatAPIKey,
      onSuccess: { [weak self] cometChatUser in
        guard let self = self else { return }
        self.user = User(cometChatUser)
        DispatchQueue.main.async {
          onComplete(.success(self.user!))
        }
      },
      onError: { error in
        print("Error logging in:")
        print(error.errorDescription)
        DispatchQueue.main.async {
          onComplete(.failure("Error logging in"))
        }
      })
  }
  
  func send(message: String, to receiver: User) {
    guard let user = user else {
      return
    }
    
    let textMessage = TextMessage(
      receiverUid: receiver.id,
      text: message,
      receiverType: .user)
    
    CometChat.sendTextMessage(
      message: textMessage,
      onSuccess: { [weak self] _ in
        guard let self = self else { return }
        print("Message sent")
        DispatchQueue.main.async {
          self.onReceivedMessage?(Message(user: user, content: message, isIncoming: false))
        }
      },
      onError: { error in
        print("Error sending message:")
        print(error?.errorDescription ?? "")
    })
  }
  
  private var usersRequest: UsersRequest?
  func getUsers(onComplete: @escaping ([User])-> Void) {
    usersRequest = UsersRequest.UsersRequestBuilder().build()
    usersRequest?.fetchNext(
      onSuccess: { cometChatUsers in
        let users = cometChatUsers.map(User.init)
        DispatchQueue.main.async {
          onComplete(users)
        }
      },
      onError: { error in
        onComplete([])
        print("Fetching users failed with error:")
        print(error?.errorDescription ?? "unknown")
      })
  }
  
  private var messagesRequest: MessagesRequest?
  func getMessages(from sender: User, onComplete: @escaping ([Message])-> Void) {
    guard let user = user else {
      return
    }
    
    let limit = 50
    
    messagesRequest = MessagesRequest.MessageRequestBuilder()
      .set(limit: limit)
      .set(uid: sender.id)
      .build()
    
    messagesRequest!.fetchPrevious(
      onSuccess: { fetchedMessages in
        print("Fetched \(fetchedMessages?.count ?? 0) older messages")
        guard let fetchedMessages = fetchedMessages else {
          onComplete([])
          return
        }
        
        let messages = fetchedMessages
          .compactMap { $0 as? TextMessage }
          .map { Message($0, isIncoming: $0.senderUid.lowercased() != user.id.lowercased()) }
        
        DispatchQueue.main.async {
          onComplete(messages)
        }
      },
      onError: { error in
        print("Fetching messages failed with error:")
        print(error?.errorDescription ?? "unknown")
      })
  }
  
}

extension ChatService: CometChatMessageDelegate {
  func onTextMessageReceived(textMessage: TextMessage) {
    DispatchQueue.main.async {
      self.onReceivedMessage?(Message(textMessage, isIncoming: true))
    }
  }
}

extension ChatService: CometChatUserDelegate {
  
  func onUserOnline(user cometChatUser: CometChatPro.User) {
    DispatchQueue.main.async {
      self.onUserStatusChanged?(User(cometChatUser))
    }
  }
  
  func onUserOffline(user cometChatUser: CometChatPro.User) {
    DispatchQueue.main.async {
      self.onUserStatusChanged?(User(cometChatUser))
    }
  }
  
  func onTypingStarted(_ typingDetails: TypingIndicator) {
    guard let cometChatUser = typingDetails.sender else {
      return
    }
    
    DispatchQueue.main.async {
      self.onTypingStarted?(User(cometChatUser))
    }
  }

  func onTypingEnded(_ typingDetails: TypingIndicator) {
    guard let cometChatUser = typingDetails.sender else {
      return
    }

    DispatchQueue.main.async {
      self.onTypingEnded?(User(cometChatUser))
    }
  }

  
}
