//
//  KVKSocket.swift
//  
//
//  Created by Sergei Kviatkovskii on 04.12.2021.
//

import Foundation
import Combine

public class WebSocket: NSObject {
    
    public struct Parameters {
        let url: URL?
        let host: String
        let path: String
        let port: Int?
        let parameters: [String: String]
        let headers: [String: String]
        let scheme: String
        let timeoutInterval: TimeInterval
        let sendPingPong: Bool
        /// Seconds
        let pingPongInterval: Int
        let availableReconnect: Bool
        /// Seconds
        let reconnectingInterval: Int
        let delegateQueue: OperationQueue?
        
        public init(url: URL? = nil,
                    host: String = "",
                    path: String = "",
                    port: Int? = nil,
                    parameters: [String: String] = [:],
                    headers: [String: String] = [:],
                    scheme: String = "wss",
                    timeoutInterval: TimeInterval = 60,
                    sendPingPong: Bool = false,
                    pingPongInterval: Int = 5,
                    availableReconnect: Bool = false,
                    reconnectingInterval: Int = 5,
                    delegateQueue: OperationQueue? = nil)
        {
            self.url = url
            self.host = host
            self.path = path
            self.port = port
            self.parameters = parameters
            self.headers = headers
            self.scheme = scheme
            self.timeoutInterval = timeoutInterval
            self.sendPingPong = sendPingPong
            self.pingPongInterval = pingPongInterval
            self.availableReconnect = availableReconnect
            self.reconnectingInterval = reconnectingInterval
            self.delegateQueue = delegateQueue
        }
    }
    
    public var event: AnyPublisher<Event, Never> {
        subject.eraseToAnyPublisher()
    }
    
    private var session: URLSession?
    private var request: URLRequest?
    private var lastModifiedDate: Date?
    private let subject = PassthroughSubject<Event, Never>()
    private var cancellableSubject: Cancellable?
    private var task: URLSessionWebSocketTask?
    private let params: Parameters
    private let webSocketQueue = DispatchQueue(label: "kvksocket.websocket", qos: .background, attributes: .concurrent)
    private lazy var delegateQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "kvksocket.websocket"
        queue.underlyingQueue = webSocketQueue
        return queue
    }()
    
    public init?(parameters: Parameters) {
        self.params = parameters
        super.init()
        
        session = URLSession(configuration: .default,
                             delegate: self,
                             delegateQueue: params.delegateQueue ?? delegateQueue)
        
        let url: URL
        if let item = parameters.url {
            url = item
        } else {
            var urlComponents = URLComponents()
            urlComponents.scheme = params.scheme
            urlComponents.host = params.host
            urlComponents.path = params.path
            urlComponents.port = params.port
            
            if !params.parameters.isEmpty {
                urlComponents.queryItems = params.parameters.compactMap { URLQueryItem(name: $0.key, value: $0.value) }
            }
            
            guard let item = urlComponents.url else {
                print("Could not create URL from components")
                return nil
            }
            
            url = item
        }
        
        request = URLRequest(url: url)
        request?.timeoutInterval = params.timeoutInterval
        
        if !params.headers.isEmpty {
            params.headers.forEach {
                request?.addValue($0.value, forHTTPHeaderField: $0.key)
            }
        }
        
        cancellableSubject = subject.sink(receiveCompletion: { (error) in
            print(error)
        }) { [weak self] (event) in
            if case .error = event,
                self?.params.availableReconnect == true,
                let interval = self?.params.reconnectingInterval
            {
                self?.runWithAfter(interval: interval) { [weak self] in
                    self?.task?.resume()
                }
            }
        }
    }
    
    deinit {
        if task != nil {
            disconnect()
        }
        cancellableSubject?.cancel()
    }
    
    public func connect() {
        if let item = request {
            task = session?.webSocketTask(with: item)
        }
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
        task = nil
        lastModifiedDate = nil
    }
    
    public func send(_ message: Message) {
        task?.send(message.socketMsg) { [weak self] (error) in
            if let err = error {
                self?.subject.send(.error(err))
            }
        }
    }
    
    //MARK: Private
    
    @available(iOS 15.0.0, *)
    func sendAsync(_ message: Message) async throws {
        do {
            try await task?.send(message.socketMsg)
        } catch {
            subject.send(.error(error))
        }
    }
    
    @available(iOS 15.0.0, *)
    private func recieveAsync() async throws {
        do {
            let message = try await task?.receive()
            
            switch message {
            case .data(let data):
                subject.send(.message(.binary(data)))
            case .string(let text):
                subject.send(.message(.text(text)))
            case .none:
                fatalError()
            @unknown default:
                fatalError()
            }
            
            try await recieveAsync()
        } catch {
            subject.send(.error(error))
        }
    }
    
    private func runWithAfter(interval: Int, action: @escaping () -> Void) {
        let deadline = DispatchTime.now() + DispatchTimeInterval.seconds(interval)
        webSocketQueue.asyncAfter(deadline: deadline) {
            action()
        }
    }
    
    private func recieve() {
        task?.receive { [weak self] (result) in
            switch result {
            case .success(let msg):
                self?.lastModifiedDate = Date()
                
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
        func runPing() {
            runWithAfter(interval: params.pingPongInterval) { [weak self] in
                self?.ping()
            }
        }
        
        if let lastDate = lastModifiedDate {
            let newDate = lastDate.addingTimeInterval(TimeInterval(params.pingPongInterval))
            guard Date() > newDate else {
                runPing()
                return
            }
        } else {
            return
        }
        
        subject.send(.ping)
        task?.sendPing { [weak self] (error) in
            if let err = error {
                self?.subject.send(.error(err))
            } else if let self = self {
                self.subject.send(.pong(Date()))
                runPing()
            }
        }
    }
    
}

extension WebSocket: URLSessionWebSocketDelegate {
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        lastModifiedDate = Date()
        
        if params.sendPingPong {
            ping()
        }
        
        subject.send(.connected)
        recieve()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        subject.send(.disconnected(closeCode, reason))
    }
    
}

extension WebSocket {
    
    public enum Event {
        case connected,
             disconnected(URLSessionWebSocketTask.CloseCode, Data?),
             error(Error?),
             reconnecting,
             message(Message),
             ping,
             pong(Date)
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
