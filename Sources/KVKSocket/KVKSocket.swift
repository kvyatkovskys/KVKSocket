//
//  KVKSocket.swift
//  
//
//  Created by Sergei Kviatkovskii on 04.12.2021.
//

import Foundation
import Combine

public class WebSocket: NSObject {
    
    struct Parameters {
        let host: String
        var path: String = ""
        var port: Int?
        var parameters: [String: String] = [:]
        var headers: [String: String] = [:]
        var scheme: String = "wss"
        var timeoutInterval: TimeInterval = 5
        var sendPingPong: Bool = false
        /// Seconds
        var pingPongInterval: Int = 5
    }
    
    var event: AnyPublisher<Event, Never> {
        subject.eraseToAnyPublisher()
    }
    
    private let subject = PassthroughSubject<Event, Never>()
    private var task: URLSessionWebSocketTask?
    private let params: Parameters
    
    init?(parameters: Parameters) {
        self.params = parameters
        super.init()
        
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: nil)
        
        var urlComponents = URLComponents()
        urlComponents.scheme = params.scheme
        urlComponents.host = params.host
        urlComponents.path = params.path
        urlComponents.port = params.port
        
        if !params.parameters.isEmpty {
            urlComponents.queryItems = params.parameters.compactMap { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let url = urlComponents.url else {
            print("Could not create URL from components")
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = params.timeoutInterval
        
        if !params.headers.isEmpty {
            params.headers.forEach {
                request.addValue($0.value, forHTTPHeaderField: $0.key)
            }
        }
        
        task = session.webSocketTask(with: request)
    }
    
    public func connect() {
        task?.resume()
    }
    
    public func disconnect(reason: String? = nil) {
        let reasonData: Data?
        if let txt = reason {
            reasonData = txt.data(using: .utf8)
        } else {
            reasonData = "Close connection".data(using: .utf8)
        }
        
        task?.cancel(with: .goingAway, reason: reasonData)
    }
    
    public func send(_ message: Message) {
        task?.send(message.socketMsg) { [weak self] (error) in
            if let err = error {
                self?.subject.send(.error(err))
            }
        }
    }
    
    //MARK: Private
    
    private func recieve() {
        task?.receive { [weak self] (result) in
            switch result {
            case .success(let msg):
                switch msg {
                case .data(let data):
                    self?.subject.send(.message(.binary(data)))
                case .string(let text):
                    self?.subject.send(.message(.text(text)))
                @unknown default:
                    fatalError()
                }
            case .failure(let error):
                self?.subject.send(.error(error))
            }
            
            self?.recieve()
        }
    }
    
    private func ping() {
        task?.sendPing { [weak self] (error) in
            if let err = error {
                self?.subject.send(.error(err))
            } else if let self = self {
                let interval = DispatchTime.now() + DispatchTimeInterval.seconds(self.params.pingPongInterval)
                DispatchQueue.global().asyncAfter(deadline: interval) { [weak self] in
                    self?.ping()
                }
            }
        }
    }
    
}

extension WebSocket: URLSessionWebSocketDelegate {
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        subject.send(.connected)
        if params.sendPingPong {
            ping()
        }
        recieve()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        subject.send(.disconnected(closeCode, reason))
    }
    
}

extension WebSocket {
    
    public enum Event {
        case connected, disconnected(URLSessionWebSocketTask.CloseCode, Data?), error(Error?), message(Message)
    }
    
    public enum Message {
        case binary(Data), text(String)
        
        var socketMsg: URLSessionWebSocketTask.Message {
            switch self {
            case .binary(let data):
                return URLSessionWebSocketTask.Message.data(data)
            case .text(let text):
                return URLSessionWebSocketTask.Message.string(text)
            }
        }
    }
    
}
