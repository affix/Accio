import Foundation

enum ManifestError: Error {
    case libraryNotFound
}

class Manifest: Decodable {
    // MARK: - Sub Types
    struct Target: Decodable {
        struct Dependency: Decodable {
            let name: String
        }

        let name: String
        let dependencies: [Dependency]
    }

    struct Product: Decodable {
        let name: String
        let productType: String
        let targets: [String]
    }

    // MARK: - Properties
    let name: String
    let products: [Product]
    let targets: [Target]
}

extension Manifest {
    var appTargets: [AppTarget] {
        return targets.map { AppTarget(projectName: name, targetName: $0.name, dependentLibraryNames: $0.dependencies.map { $0.name }) }
    }

    func frameworkDependencies(ofLibrary libraryName: String, dependencyGraph: DependencyGraph) throws -> [Framework] {
        let libraryProducts: [Product] = products.filter { $0.productType == "library" }

        guard let product: Product = libraryProducts.first(where: { $0.name == libraryName }) else {
            print("Manifest: Could not find library product with name '\(libraryName)' in package manifest for project '\(name)'.", level: .error)
            throw ManifestError.libraryNotFound
        }

        let productsTargets: [Target] = targets.filter { product.targets.contains($0.name) }
        let dependencyTargetNames: [String] = Array(Set(productsTargets.flatMap { $0.dependencies.map { $0.name } }))

        let projectTargetNames: [String] = targets.map { $0.name }
        let dependencyExternalLibraryNames: [String] = dependencyTargetNames.filter { !projectTargetNames.contains($0) }

        return try dependencyExternalLibraryNames.map { try dependencyGraph.framework(libraryName: $0) }
    }
}
