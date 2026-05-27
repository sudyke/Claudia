import Foundation

// A named blueprint for a Service. When the user picks a preset, we generate a fresh
// Service from `makeService()` (with new UUID) and prefill the editor for any fields
// that need user input (e.g. project paths for "supabase start").
struct ServicePreset: Identifiable, Hashable {
    let id: String
    let category: PresetCategory
    let name: String
    let description: String
    let needsPath: Bool
    let makeService: () -> Service

    static func == (lhs: ServicePreset, rhs: ServicePreset) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

enum PresetCategory: String, CaseIterable, Hashable {
    case container = "Containers"
    case database  = "Databases"
    case devServer = "Dev Servers"
    case tool      = "Tools"
}

enum Presets {
    static let all: [ServicePreset] = [
        // MARK: Containers
        .init(
            id: "docker",
            category: .container,
            name: "Docker",
            description: "Docker Desktop",
            needsPath: false,
            makeService: {
                Service(
                    name: "Docker",
                    check: .shell(binary: BinaryResolver.resolveOrFirst("docker"), args: ["info"]),
                    startCommand: .openApp(name: "Docker")
                )
            }
        ),
        .init(
            id: "orbstack",
            category: .container,
            name: "OrbStack",
            description: "Fast Docker alternative for macOS",
            needsPath: false,
            makeService: {
                Service(
                    name: "OrbStack",
                    check: .shell(binary: BinaryResolver.resolveOrFirst("orb"), args: ["info"]),
                    startCommand: .openApp(name: "OrbStack")
                )
            }
        ),
        .init(
            id: "colima",
            category: .container,
            name: "Colima",
            description: "Container runtime via brew services",
            needsPath: false,
            makeService: {
                Service(
                    name: "Colima",
                    check: .shell(binary: BinaryResolver.resolveOrFirst("colima"), args: ["status"]),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("colima"), args: ["start"])
                )
            }
        ),

        // MARK: Databases
        .init(
            id: "supabase",
            category: .database,
            name: "Supabase",
            description: "Local Supabase via the CLI",
            needsPath: true,
            makeService: {
                Service(
                    name: "Supabase",
                    check: .http(url: "http://localhost:54321/health", method: .get),
                    startCommand: .terminal(workdir: "", command: "supabase start")
                )
            }
        ),
        .init(
            id: "postgres",
            category: .database,
            name: "Postgres",
            description: "PostgreSQL on port 5432",
            needsPath: false,
            makeService: {
                Service(
                    name: "Postgres",
                    check: .tcp(host: "localhost", port: 5432),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("brew"), args: ["services", "start", "postgresql"])
                )
            }
        ),
        .init(
            id: "mysql",
            category: .database,
            name: "MySQL",
            description: "MySQL on port 3306",
            needsPath: false,
            makeService: {
                Service(
                    name: "MySQL",
                    check: .tcp(host: "localhost", port: 3306),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("brew"), args: ["services", "start", "mysql"])
                )
            }
        ),
        .init(
            id: "redis",
            category: .database,
            name: "Redis",
            description: "Redis on port 6379",
            needsPath: false,
            makeService: {
                Service(
                    name: "Redis",
                    check: .tcp(host: "localhost", port: 6379),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("brew"), args: ["services", "start", "redis"])
                )
            }
        ),
        .init(
            id: "mongodb",
            category: .database,
            name: "MongoDB",
            description: "MongoDB on port 27017",
            needsPath: false,
            makeService: {
                Service(
                    name: "MongoDB",
                    check: .tcp(host: "localhost", port: 27017),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("brew"), args: ["services", "start", "mongodb-community"])
                )
            }
        ),

        // MARK: Dev Servers
        .init(
            id: "nextjs",
            category: .devServer,
            name: "Next.js (3000)",
            description: "Next.js dev server",
            needsPath: true,
            makeService: {
                Service(
                    name: "Next.js",
                    check: .http(url: "http://localhost:3000", method: .head),
                    startCommand: .terminal(workdir: "", command: "npm run dev")
                )
            }
        ),
        .init(
            id: "vite",
            category: .devServer,
            name: "Vite (5173)",
            description: "Vite dev server",
            needsPath: true,
            makeService: {
                Service(
                    name: "Vite",
                    check: .http(url: "http://localhost:5173", method: .head),
                    startCommand: .terminal(workdir: "", command: "npm run dev")
                )
            }
        ),
        .init(
            id: "astro",
            category: .devServer,
            name: "Astro (4321)",
            description: "Astro dev server",
            needsPath: true,
            makeService: {
                Service(
                    name: "Astro",
                    check: .http(url: "http://localhost:4321", method: .head),
                    startCommand: .terminal(workdir: "", command: "npm run dev")
                )
            }
        ),
        .init(
            id: "storybook",
            category: .devServer,
            name: "Storybook (6006)",
            description: "Storybook dev server",
            needsPath: true,
            makeService: {
                Service(
                    name: "Storybook",
                    check: .http(url: "http://localhost:6006", method: .head),
                    startCommand: .terminal(workdir: "", command: "npm run storybook")
                )
            }
        ),
        .init(
            id: "rails",
            category: .devServer,
            name: "Rails (3000)",
            description: "Ruby on Rails dev server",
            needsPath: true,
            makeService: {
                Service(
                    name: "Rails",
                    check: .http(url: "http://localhost:3000", method: .head),
                    startCommand: .terminal(workdir: "", command: "bin/rails server")
                )
            }
        ),
        .init(
            id: "django",
            category: .devServer,
            name: "Django (8000)",
            description: "Django dev server",
            needsPath: true,
            makeService: {
                Service(
                    name: "Django",
                    check: .http(url: "http://localhost:8000", method: .head),
                    startCommand: .terminal(workdir: "", command: "python manage.py runserver")
                )
            }
        ),

        // MARK: Tools
        .init(
            id: "mailpit",
            category: .tool,
            name: "Mailpit (8025)",
            description: "Local SMTP testing UI",
            needsPath: false,
            makeService: {
                Service(
                    name: "Mailpit",
                    check: .http(url: "http://localhost:8025", method: .head),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("brew"), args: ["services", "start", "mailpit"])
                )
            }
        ),
        .init(
            id: "localstack",
            category: .tool,
            name: "LocalStack (4566)",
            description: "Local AWS service emulator",
            needsPath: false,
            makeService: {
                Service(
                    name: "LocalStack",
                    check: .http(url: "http://localhost:4566/_localstack/health", method: .get),
                    startCommand: .shell(binary: BinaryResolver.resolveOrFirst("localstack"), args: ["start", "-d"])
                )
            }
        ),
        .init(
            id: "ngrok",
            category: .tool,
            name: "ngrok (4040)",
            description: "ngrok local API",
            needsPath: false,
            makeService: {
                Service(
                    name: "ngrok",
                    check: .http(url: "http://localhost:4040/api/tunnels", method: .get),
                    startCommand: nil  // ngrok needs a target; user configures manually
                )
            }
        ),
    ]

    static func grouped() -> [(PresetCategory, [ServicePreset])] {
        PresetCategory.allCases.map { cat in
            (cat, all.filter { $0.category == cat })
        }
    }

    /// The default trio seeded when a user has no services configured.
    static func defaults() -> [Service] {
        [
            preset(id: "docker"),
            preset(id: "supabase"),
            Service(
                name: "Dev Server",
                check: .http(url: "http://localhost:3000", method: .head),
                startCommand: .terminal(workdir: "", command: "npm run dev")
            ),
        ].compactMap { $0 }
    }

    private static func preset(id: String) -> Service? {
        all.first { $0.id == id }?.makeService()
    }
}
