import Foundation

// Finds what your projects already use, on this Mac with no AI: dependency names in manifests and
// a few telltale files: a fingerprint table, like the ones that recognise a web page's stack,
// pointed at project folders instead.

/// One thing a project uses, as an answer to a stack question.
struct StackFingerprint: Sendable {
    let question: String
    let option: String
    /// Dependency names that mean it's used. A trailing `*` matches a prefix, such as `@radix-ui/*`.
    var packages: [String] = []
    /// Files whose presence in the project folder means it's used.
    var files: [String] = []
}

/// A library worth a place in the playbook, recognised by its package name.
struct KnownLibrary: Sendable {
    let package: String
    let name: String
    let url: String
    let task: String
}

struct StackScanResult: Equatable, Sendable {
    /// question id → option name → the projects that use it.
    var stack: [String: [String: Set<String>]] = [:]
    /// Known libraries found, by display name, with the projects that use them.
    var libraries: [String: Set<String>] = [:]
    var projectsScanned = 0

    func projects(using option: String, for question: String) -> Int { stack[question]?[option]?.count ?? 0 }
}

enum StackScan {
    static let fingerprints: [StackFingerprint] = [
        // What you build
        .init(question: "platforms", option: "Web apps", packages: ["next", "vite", "react-dom", "astro", "@sveltejs/kit", "nuxt", "vue"]),
        .init(question: "platforms", option: "Browser extensions", files: ["manifest.json:manifest_version"]),
        .init(question: "platforms", option: "APIs and services", packages: ["@nestjs/core", "express", "fastify", "hono", "fastapi", "django", "flask"]),
        .init(question: "platforms", option: "Mac apps", files: ["project.yml:macOS", "Package.swift:.macOS("]),
        .init(question: "platforms", option: "iOS apps", files: ["project.yml:iOS", "Package.swift:.iOS("]),
        .init(question: "platforms", option: "Android apps", files: ["AndroidManifest.xml", "app/src/main/AndroidManifest.xml"]),
        .init(question: "platforms", option: "Desktop apps", packages: ["electron", "@tauri-apps/api"]),
        .init(question: "platforms", option: "Games", files: ["project.godot"]),
        // Languages
        .init(question: "languages", option: "TypeScript", packages: ["typescript"], files: ["tsconfig.json"]),
        .init(question: "languages", option: "Swift", files: ["Package.swift", "project.yml"]),
        .init(question: "languages", option: "Python", files: ["pyproject.toml", "requirements.txt"]),
        .init(question: "languages", option: "Go", files: ["go.mod"]),
        .init(question: "languages", option: "Rust", files: ["Cargo.toml"]),
        .init(question: "languages", option: "Kotlin", files: ["build.gradle.kts"]),
        .init(question: "languages", option: "C++", files: ["CMakeLists.txt"]),
        // Web framework
        .init(question: "web", option: "Next.js", packages: ["next"]),
        .init(question: "web", option: "Vite + React", packages: ["vite+react"]),
        .init(question: "web", option: "React Router", packages: ["react-router", "@remix-run/*"]),
        .init(question: "web", option: "Astro", packages: ["astro"]),
        .init(question: "web", option: "SvelteKit", packages: ["@sveltejs/kit"]),
        .init(question: "web", option: "Nuxt", packages: ["nuxt"]),
        // UI
        .init(question: "ui", option: "shadcn/ui", files: ["components.json"]),
        .init(question: "ui", option: "Radix UI", packages: ["@radix-ui/*", "radix-ui"]),
        .init(question: "ui", option: "Base UI", packages: ["@base-ui-components/react", "@base-ui/react"]),
        .init(question: "ui", option: "MUI", packages: ["@mui/material"]),
        .init(question: "ui", option: "Mantine", packages: ["@mantine/core"]),
        .init(question: "ui", option: "SwiftUI", files: ["project.yml", "Package.swift"]),
        // Styling
        .init(question: "styling", option: "Tailwind CSS", packages: ["tailwindcss", "@tailwindcss/*"]),
        .init(question: "styling", option: "styled-components", packages: ["styled-components"]),
        .init(question: "styling", option: "Sass", packages: ["sass"]),
        // Back end
        .init(question: "backend", option: "NestJS", packages: ["@nestjs/core"]),
        .init(question: "backend", option: "Express", packages: ["express"]),
        .init(question: "backend", option: "Fastify", packages: ["fastify"]),
        .init(question: "backend", option: "Hono", packages: ["hono"]),
        .init(question: "backend", option: "FastAPI", packages: ["fastapi"]),
        .init(question: "backend", option: "Django", packages: ["django"]),
        .init(question: "backend", option: "Supabase", packages: ["@supabase/supabase-js", "supabase"]),
        .init(question: "backend", option: "Firebase", packages: ["firebase", "firebase-admin"]),
        // Data
        .init(question: "data", option: "PostgreSQL", packages: ["pg", "postgres", "@neondatabase/serverless", "psycopg", "psycopg2", "psycopg2-binary", "asyncpg"]),
        .init(question: "data", option: "SQLite", packages: ["better-sqlite3", "sqlite3", "@libsql/client"], files: ["Package.swift:GRDB"]),
        .init(question: "data", option: "MySQL", packages: ["mysql2", "mysql"]),
        .init(question: "data", option: "MongoDB", packages: ["mongodb", "mongoose", "pymongo"]),
        .init(question: "data", option: "Redis", packages: ["redis", "ioredis"]),
        .init(question: "data", option: "Prisma", packages: ["prisma", "@prisma/client"]),
        .init(question: "data", option: "Drizzle", packages: ["drizzle-orm"]),
        // Sign-in
        .init(question: "auth", option: "Clerk", packages: ["@clerk/*"]),
        .init(question: "auth", option: "Auth.js", packages: ["next-auth", "@auth/core"]),
        .init(question: "auth", option: "Better Auth", packages: ["better-auth"]),
        .init(question: "auth", option: "Firebase Auth", packages: ["firebase"]),
        // Hosting
        .init(question: "hosting", option: "Vercel", files: ["vercel.json"]),
        .init(question: "hosting", option: "Netlify", files: ["netlify.toml"]),
        .init(question: "hosting", option: "Cloudflare", files: ["wrangler.toml", "wrangler.jsonc"]),
        .init(question: "hosting", option: "Fly.io", files: ["fly.toml"]),
        .init(question: "hosting", option: "Railway", files: ["railway.json", "railway.toml"]),
        // Testing
        .init(question: "testing", option: "Vitest", packages: ["vitest"]),
        .init(question: "testing", option: "Jest", packages: ["jest"]),
        .init(question: "testing", option: "Playwright", packages: ["@playwright/test", "playwright"]),
        .init(question: "testing", option: "Testing Library", packages: ["@testing-library/*"]),
        .init(question: "testing", option: "pytest", packages: ["pytest"]),
        // AI
        .init(question: "ai", option: "Claude API", packages: ["@anthropic-ai/sdk", "anthropic"]),
        .init(question: "ai", option: "OpenAI API", packages: ["openai"]),
        .init(question: "ai", option: "Vercel AI SDK", packages: ["ai", "@ai-sdk/*"]),
        .init(question: "ai", option: "LangChain", packages: ["langchain", "@langchain/*"]),
        .init(question: "ai", option: "Ollama", packages: ["ollama"]),
    ]

    static let knownLibraries: [KnownLibrary] = [
        .init(package: "sonner", name: "Sonner", url: "https://sonner.emilkowal.ski", task: "Toasts"),
        .init(package: "vaul", name: "Vaul", url: "https://vaul.emilkowal.ski", task: "Drawers"),
        .init(package: "cmdk", name: "cmdk", url: "https://cmdk.paco.me", task: "Command menu"),
        .init(package: "@number-flow/react", name: "NumberFlow", url: "https://number-flow.barvian.me", task: "Animated numbers"),
        .init(package: "motion", name: "Motion", url: "https://motion.dev", task: "Animation"),
        .init(package: "framer-motion", name: "Motion", url: "https://motion.dev", task: "Animation"),
        .init(package: "@radix-ui/*", name: "Radix UI", url: "https://www.radix-ui.com", task: "UI primitives"),
        .init(package: "radix-ui", name: "Radix UI", url: "https://www.radix-ui.com", task: "UI primitives"),
        .init(package: "@base-ui-components/react", name: "Base UI", url: "https://base-ui.com", task: "UI primitives"),
        .init(package: "lucide-react", name: "Lucide", url: "https://lucide.dev", task: "Icons"),
        .init(package: "recharts", name: "Recharts", url: "https://recharts.org", task: "Charts"),
        .init(package: "zustand", name: "Zustand", url: "https://zustand.docs.pmnd.rs", task: "State"),
        .init(package: "@tanstack/react-query", name: "TanStack Query", url: "https://tanstack.com/query", task: "Data fetching"),
        .init(package: "@tanstack/react-table", name: "TanStack Table", url: "https://tanstack.com/table", task: "Tables"),
        .init(package: "react-hook-form", name: "React Hook Form", url: "https://react-hook-form.com", task: "Forms"),
        .init(package: "zod", name: "Zod", url: "https://zod.dev", task: "Validation"),
        .init(package: "date-fns", name: "date-fns", url: "https://date-fns.org", task: "Dates"),
        .init(package: "@dnd-kit/core", name: "dnd kit", url: "https://dndkit.com", task: "Drag and drop"),
        .init(package: "react-virtuoso", name: "Virtuoso", url: "https://virtuoso.dev", task: "Long lists"),
        .init(package: "class-variance-authority", name: "cva", url: "https://cva.style", task: "Styling variants"),
        .init(package: "clsx", name: "clsx", url: "https://github.com/lukeed/clsx", task: "Class names"),
        .init(package: "next-themes", name: "next-themes", url: "https://github.com/pacocoursey/next-themes", task: "Dark mode"),
        .init(package: "shiki", name: "Shiki", url: "https://shiki.style", task: "Code highlighting"),
        .init(package: "input-otp", name: "input-otp", url: "https://input-otp.rodz.dev", task: "One-time codes"),
        .init(package: "embla-carousel-react", name: "Embla Carousel", url: "https://www.embla-carousel.com", task: "Carousels"),
        .init(package: "react-day-picker", name: "React DayPicker", url: "https://daypicker.dev", task: "Date pickers"),
    ]

    private static let skippedFolders: Set<String> = [
        "node_modules", ".git", "graphify-out", "dist", "build", ".next", ".nuxt", ".venv", "venv",
        "Pods", "DerivedData", "build.noindex", ".build", "target", "vendor", "coverage", ".turbo", ".cache",
    ]
    private static let manifestNames: Set<String> = ["package.json", "pyproject.toml", "requirements.txt", "Package.swift", "project.yml", "go.mod", "Cargo.toml", "manifest.json", "CMakeLists.txt", "project.godot", "build.gradle.kts"]

    /// Walks the root for project folders (those with a manifest), up to `depth` levels down.
    /// Each folder is credited to the graph project that contains it, so a monorepo counts once.
    static func scan(root: String, projects: [String], depth: Int = 5) -> StackScanResult {
        let fileManager = FileManager.default
        // Resolve links first, so /var and /private/var paths line up.
        let rootURL = URL(fileURLWithPath: root).resolvingSymlinksInPath()
        let root = rootURL.path
        var folders: Set<String> = []
        if let walker = fileManager.enumerator(at: rootURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsPackageDescendants]) {
            for case let url as URL in walker {
                let name = url.lastPathComponent
                if skippedFolders.contains(name) || (name.hasPrefix(".") && name != ".github") {
                    walker.skipDescendants()
                    continue
                }
                if walker.level > depth { walker.skipDescendants(); continue }
                if manifestNames.contains(name) || name.hasSuffix(".xcodeproj") {
                    folders.insert(url.deletingLastPathComponent().resolvingSymlinksInPath().path)
                }
            }
        }

        let sortedProjects = projects.sorted { $0.count > $1.count }
        var result = StackScanResult()
        var credited: Set<String> = []
        for folder in folders.sorted() {
            let relative = folder == root ? "" : folder.hasPrefix(root + "/") ? String(folder.dropFirst(root.count + 1)) : folder
            let project = sortedProjects.first { relative == $0 || relative.hasPrefix($0 + "/") } ?? relative
            credited.insert(project)
            let found = fingerprint(folder: folder)
            for (question, options) in found.stack {
                for option in options { result.stack[question, default: [:]][option, default: []].insert(project) }
            }
            for library in found.libraries { result.libraries[library, default: []].insert(project) }
        }
        result.projectsScanned = credited.count
        return result
    }

    /// What one folder uses.
    static func fingerprint(folder: String) -> (stack: [String: Set<String>], libraries: Set<String>) {
        let packages = packageNames(in: folder)
        var stack: [String: Set<String>] = [:]
        for print in fingerprints {
            let byPackage = print.packages.contains { matches($0, packages) }
            let byFile = print.files.contains { fileMatches($0, in: folder) }
            if byPackage || byFile { stack[print.question, default: []].insert(print.option) }
        }
        var libraries: Set<String> = []
        for library in knownLibraries where matches(library.package, packages) { libraries.insert(library.name) }
        return (stack, libraries)
    }

    private static func matches(_ pattern: String, _ packages: Set<String>) -> Bool {
        if pattern == "vite+react" { return packages.contains("vite") && packages.contains("react") && !packages.contains("next") }
        if pattern.hasSuffix("*") {
            let prefix = String(pattern.dropLast())
            return packages.contains { $0.hasPrefix(prefix) }
        }
        return packages.contains(pattern)
    }

    /// `name` means the file exists; `name:text` means it exists and contains the text.
    private static func fileMatches(_ spec: String, in folder: String) -> Bool {
        let parts = spec.split(separator: ":", maxSplits: 1).map(String.init)
        let path = (folder as NSString).appendingPathComponent(parts[0])
        guard FileManager.default.fileExists(atPath: path) else { return false }
        guard parts.count == 2 else { return true }
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        return text.contains(parts[1])
    }

    /// Dependency names from package.json, pyproject.toml and requirements.txt, lowercased.
    static func packageNames(in folder: String) -> Set<String> {
        var names: Set<String> = []
        let packageJSON = (folder as NSString).appendingPathComponent("package.json")
        if let data = FileManager.default.contents(atPath: packageJSON),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            for key in ["dependencies", "devDependencies", "peerDependencies"] {
                if let deps = object[key] as? [String: Any] { names.formUnion(deps.keys.map { $0.lowercased() }) }
            }
        }
        for file in ["requirements.txt", "pyproject.toml"] {
            let path = (folder as NSString).appendingPathComponent(file)
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { continue }
            for line in text.components(separatedBy: .newlines) {
                let trimmed = line.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"',"))
                guard let first = trimmed.first, first.isLetter else { continue }
                let name = trimmed.prefix { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." }
                if !name.isEmpty, !trimmed.contains(" = ") || file == "requirements.txt" {
                    names.insert(String(name).lowercased())
                }
            }
        }
        return names
    }
}
