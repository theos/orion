import Foundation
import Orion
import OrionTestSupport

// This executable allows us to do things like use
// Instruments profilers on Orion's runtime components

@_cdecl("orion_init")
func orion_init() {}
