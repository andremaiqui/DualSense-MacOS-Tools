import Testing
@testable import DSUpdater

struct FirmwareCheckParserTests {
    @Test
    func readsAvailableUpdateFromCLIOutput() {
        let result = FirmwareCheckParser.parse(
            lines: ["Latest on Sony's server: 0x0630", "Update available"],
            currentVersion: "0x0620"
        )

        #expect(result.latest == "0x0630")
        #expect(result.availability == .available)
    }

    @Test
    func identifiesCurrentFirmwareFromVersions() {
        let result = FirmwareCheckParser.parse(
            lines: ["Latest on Sony's server: 0x0630"],
            currentVersion: "0x0630"
        )

        #expect(result.availability == .upToDate)
    }

    @Test
    func comparesEquivalentHexVersions() {
        #expect(FirmwareCheckParser.versionsMatch("0x0630", "0X630"))
        #expect(!FirmwareCheckParser.versionsMatch("0x0620", "0x0630"))
    }
}
