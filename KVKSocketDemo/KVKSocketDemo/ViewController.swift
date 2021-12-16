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
    
    private var subscriptions = Set<AnyCancellable>()
    
    private let socket = WebSocket(parameters: WebSocket.Parameters(host: "localhost",
                                                                    path: "/cards",
                                                                    port: 8080,
                                                                    scheme: "ws",
                                                                    sendPingPong: true))
    
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

        socket?.event.sink { (event) in
            switch event {
            case .connected:
                print("Socket did connect")
            case .disconnected(_, _):
                print("Socket did disconnect")
            case .error(let error):
                if let err = error {
                    print(err)
                }
            case .ping:
                print("ping")
            case .pong(let date):
                print("pong", date)
            case .message(let msg):
                switch msg {
                case .text(let txt):
                    print(txt)
                case .binary(let data):
                    print(String(data: data, encoding: .utf8) ?? "")
                }
            case .reconnecting:
                print("reconnecting")
            }
        }.store(in: &subscriptions)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        subscriptions.removeAll()
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
    
}
