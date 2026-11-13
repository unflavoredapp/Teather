import Foundation

struct DeviceManager {
    func listDevices() throws -> [DeviceInfo] {
        guard ProcessRunner.find("idevice_id") != nil else { return [] }
        let output = try ProcessRunner.requireSuccess("idevice_id", ["-l"])
        let ids = output.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty }
        return ids.map { udid in
            let values = readInfo(udid: udid)
            let paired = (try? ProcessRunner.run("idevicepair", ["-u", udid, "validate"]).status) == 0
            return DeviceInfo(udid: udid,
                              name: values["DeviceName"],
                              productType: values["ProductType"],
                              productVersion: values["ProductVersion"],
                              buildVersion: values["BuildVersion"],
                              modelNumber: values["ModelNumber"],
                              connection: "usbmuxd",
                              paired: paired)
        }
    }
    func pair(udid: String) throws -> String {
        guard ProcessRunner.find("idevicepair") != nil else { throw ProcessRunnerError.executableMissing("idevicepair (install libimobiledevice-utils)") }
        return try ProcessRunner.requireSuccess("idevicepair", ["-u", udid, "pair"], timeout: 120)
    }
    private func readInfo(udid: String) -> [String: String] {
        guard ProcessRunner.find("ideviceinfo") != nil,
              let output = try? ProcessRunner.requireSuccess("ideviceinfo", ["-u", udid]) else { return [:] }
        var result: [String: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2 { result[String(parts[0]).trimmingCharacters(in: .whitespaces)] = String(parts[1]).trimmingCharacters(in: .whitespaces) }
        }
        return result
    }
}
