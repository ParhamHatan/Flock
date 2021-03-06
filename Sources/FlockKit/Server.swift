//
//  Server.swift
//  Flock
//
//  Created by Jake Heiser on 12/28/15.
//  Copyright © 2015 jakeheis. All rights reserved.
//

import Foundation
import Rainbow
import Shout

public struct ServerLogin {
    
    public let ip: String
    public let port: Int
    public let user: String
    public let auth: SSHAuthMethod?
    public let roles: [Server.Role]
    
    public init(ip: String, user: String, auth: SSHAuthMethod? = nil, roles: [Server.Role] = []) {
        self.init(ip: ip, port: 22, user: user, auth: auth)
    }
    
    public init(ip: String, port: Int, user: String, auth: SSHAuthMethod? = nil, roles: [Server.Role] = []) {
        self.ip = ip
        self.port = port
        self.user = user
        self.auth = auth
        self.roles = roles
    }
    
}

public class Server {

    public enum Role {
        case app
        case db
        case web
    }
    
    public let ip: String
    public let port: Int
    public let user: String
    public let roles: [Role]
    
    private let ssh: SSH
    private var commandStack: [String] = []
    
    public init(ip: String, port: Int, user: String, roles: [Role], authMethod: SSHAuthMethod?) {
        guard let auth = authMethod else {
            TaskError(message: "You must either pass in a SSH auth method in your `Server()` initialization or specify `environment.SSHAuthMethod`").output()
            exit(1)
        }
        
        let ssh: SSH
        do {
            print("Connecting to \(user)@\(ip):\(port)...")
            fflush(stdout)
            ssh = try SSH(host: ip, port: Int32(port))
            ssh.ptyType = .vanilla
            try ssh.authenticate(username: user, authMethod: auth)
        } catch let error {
            TaskError(message: "Couldn't connect to \(user)@\(ip):\(port) (\(error))").output()
            exit(1)
        }
        
        self.ip = ip
        self.port = port
        self.user = user
        self.roles = roles
        self.ssh = ssh
    }
    
    // MARK: - Command helpers
    
    public func within(_ directory: String, block: () throws -> ()) rethrows {
        commandStack.append("cd \(directory)")
        try block()
        commandStack.removeLast()
    }
    
    public func withPty(_ newType: SSH.PtyType?, block: () throws -> ()) rethrows {
        let oldType = ssh.ptyType
        
        ssh.ptyType = newType
        try block()
        ssh.ptyType = oldType
    }
    
    public func onRoles(_ roles: [Role], block: () throws -> ()) rethrows {
        if !Set(roles).intersection(Set(self.roles)).isEmpty {
            try block()
        }
    }
    
    public func commandSucceeds(_ command: String) -> Bool {
        do {
            try execute(command)
        } catch {
            return false
        }
        return true
    }
    
    public func fileExists(_ file: String) -> Bool {
        return commandSucceeds("test -f \(file)")
    }
    
    public func directoryExists(_ directory: String) -> Bool {
        return commandSucceeds("test -d \(directory)")
    }
    
    public func commandExists(_ command: String) -> Bool {
        return commandSucceeds("command -v \(command) >/dev/null 2>&1")
    }
    
    // MARK: - Comamnd execution
    
    public func execute(_ command: String) throws {
        let status = try ssh.execute(prepCommand(command))
        guard status == 0 else {
            throw TaskError(status: status)
        }
    }
    
    public func capture(_ command: String) throws -> String {
        let (status, output) = try ssh.capture(prepCommand(command))
        guard status == 0 else {
            if !output.isEmpty {
                print(output)
            }
            throw TaskError(status: status)
        }
        return output
    }
    
    private func prepCommand(_ command: String) -> String {
        let finalCommands = commandStack + [command]
        let call = finalCommands.joined(separator: "; ")
        print("On \(description): \(call)".green)
        return call
    }
    
}

extension Server: CustomStringConvertible {
    
    public var description: String {
        return "\(user)@\(ip):\(port)"
    }
    
}
