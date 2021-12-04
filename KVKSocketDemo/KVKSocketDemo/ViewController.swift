//
//  ViewController.swift
//  KVKSocketDemo
//
//  Created by Sergei Kviatkovskii on 04.12.2021.
//

import UIKit
import KVKSocket
import Combine

final class ViewController: UIViewController {
    
    private var cancellableSocket: AnyCancellable?
    
    private let socket = WebSocket(parameters: WebSocket.Parameters(host: "192.168.1.113",
                                                                    path: "/cards",
                                                                    port: 8080,
                                                                    scheme: "ws"))
    
    private lazy var connectButton: UIButton = {
        let button = UIButton(type: .system)
        button.frame = CGRect(origin: .zero, size: CGSize(width: 200, height: 100))
        button.setTitle("Connect", for: .normal)
        button.addTarget(self, action: #selector(connectSocket), for: .touchUpInside)
        button.isSelected = false
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(connectButton)

        cancellableSocket = socket?.event.sink { [weak self] (event) in
            switch event {
            case .connected:
                print("Socket did connect")
                if let data = self?.createStartMessage() {
                    self?.socket?.send(.text(data))
                }
            case .disconnected(_, _):
                print("Socket did disconnect")
            case .error(let error):
                if let err = error {
                    print(err)
                }
            case .message(let msg):
                switch msg {
                case .text(let txt):
                    print(txt)
                case .binary(let data):
                    print(data)
                }
            }
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        cancellableSocket?.cancel()
    }
    
    @objc private func connectSocket(_ sender: UIButton) {
        if sender.isSelected {
            socket?.disconnect()
        } else {
            socket?.connect()
        }
        
        sender.isSelected.toggle()
        
        if sender.isSelected {
            sender.setTitle("Disconnect", for: .normal)
        } else {
            sender.setTitle("Connect", for: .normal)
        }
    }
    
    private func createStartMessage() -> String? {
        let initMsg = InitMessage(locationid: 1,
                                  token: "")

        let encoder = JSONEncoder()
        guard let jsonInitData = try? encoder.encode(initMsg) else { return nil }
        
        let baseMsg = BaseMessage(type: 1, result: jsonInitData)
        guard let json = try? encoder.encode(baseMsg) else { return nil }
        
        return String(data: json, encoding: .utf8)
    }
    
}

struct BaseMessage: Codable {
    let type: Int
    let result: Data
}

struct InitMessage: Codable {
    let locationid: Int
    let token: String
}
