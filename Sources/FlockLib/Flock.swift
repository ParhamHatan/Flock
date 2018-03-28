//
//  Flock.swift
//  Flock
//
//  Created by Jake Heiser on 12/28/15.
//  Copyright © 2015 jakeheis. All rights reserved.
//

#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

import Rainbow
import Shout

public struct ServerAddress {
    let ip: String
    let user: String
    let auth: SSHAuthMethod?
}

public protocol FlockConfig {
    var servers: [ServerAddress] { get }
}

public class Flock {
    
    public static func go(_ config: FlockConfig, _ each: (server: Server) -> ()) {
        let servers = config.servers.map { Server(ip: $0.ip, user: $0.user, roles: [], authMethod: $0.auth)}
        servers.forEach(each)
    }
    
    private(set) static var tasks: [Task] = []
    private(set) static var servers: [Server] = []
    
    // MARK: - Public
    
    public static func configure(base: Environment, environments: [Environment]) {
        guard Config.environment.isEmpty else {
            print("`Flock.configure` should only be called once")
            exit(1)
        }
        
        if CommandLine.arguments.count == 3 {
            Config.environment = CommandLine.arguments[2]
        } else {
            Config.environment = "production"
        }
        
        base.configure()
        
        for env in environments {
            let key = String(describing: type(of: env)).lowercased()
            if key == Config.environment {
                env.configure()
                break
            }
        }
    }
    
    public static func serve(ip: String, user: String, roles: [Server.Role], authMethod: SSHAuthMethod? = nil) {
        servers.append(Server(ip: ip, user: user, roles: roles, authMethod: authMethod))
    }

    public static func serve(address: Server.Address, user: String, roles: [Server.Role], authMethod: SSHAuthMethod? = nil) {
        servers.append(Server(address: address, user: user, roles: roles, authMethod: authMethod))
    }
    
    public static func use(_ taskSource: TaskSource) {
        tasks += taskSource.tasks
        taskSource.beingUsed = true
    }
    
    public static func run() -> Never {
        guard !Config.environment.isEmpty else {
            print("Make sure to call `Flock.configure` before `Flock.run`")
            exit(1)
        }
        
        let task = CommandLine.arguments[1]
        if task == "--print-tasks" {
            printTasks()
            exit(0)
        }
        
        TaskExecutor.setup(with: tasks)
        
        do {
            try TaskExecutor.run(taskNamed: task)
            exit(0)
        } catch let error as TaskError {
            error.output()
        } catch let error {
            print(String(describing: error).red)
        }
        
        exit(1)
    }
    
    private static func printTasks() {
        print("Available tasks:")
        for task in tasks {
            print("flock \(task.fullName)")
        }
        print()
        
        print("To print help information: flock --help")
    }
    
}
