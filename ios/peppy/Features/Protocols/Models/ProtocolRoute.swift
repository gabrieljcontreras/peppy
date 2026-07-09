import Foundation

enum ProtocolRoute: Hashable {
    case detail(UUID)
    case create
    case edit(UUID)
    case addCompound(UUID)
    case editCompound(protocolID: UUID, compoundID: UUID)
    case logDose(protocolID: UUID, compoundID: UUID?)
    case starterSetup(protocolID: UUID, compounds: [String])
}
