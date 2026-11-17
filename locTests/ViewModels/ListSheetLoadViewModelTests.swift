//
//  ListSheetLoadViewModelTests.swift
//  locTests
//
//  Tests that the list sheet loader always leaves the loading state: success, missing, error, timeout.
//

import XCTest
@testable import loc

@MainActor
final class ListSheetLoadViewModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeList(id: String = "list-1") -> LightweightPlaceList {
        LightweightPlaceList(
            list_id: id, name: "Tacos", is_public: true, image: nil, created_at: nil,
            updated_at: nil, distance_meters: nil, place_count: 1, city: nil, description: nil
        )
    }

    private func makeVM(
        timeout: TimeInterval = 5,
        fetch: @escaping (String) async throws -> LightweightPlaceList?,
        onLoaded: @escaping (LightweightPlaceList) -> Void = { _ in }
    ) -> ListSheetLoadViewModel {
        ListSheetLoadViewModel(listId: "list-1", timeout: timeout, fetchList: fetch, onLoaded: onLoaded)
    }

    // MARK: - Tests

    func testLoadSuccess_DeliversListToCaller() async {
        var loaded: LightweightPlaceList?
        let vm = makeVM(fetch: { _ in self.makeList() }, onLoaded: { loaded = $0 })
        await vm.load()
        XCTAssertEqual(loaded?.list_id, "list-1")
    }

    func testLoadMissingList_Fails() async {
        let vm = makeVM(fetch: { _ in nil })
        await vm.load()
        guard case .failed = vm.state else { return XCTFail("Expected failed state") }
    }

    func testLoadError_FailsInsteadOfSpinning() async {
        let vm = makeVM(fetch: { _ in throw URLError(.notConnectedToInternet) })
        await vm.load()
        guard case .failed = vm.state else { return XCTFail("Expected failed state") }
    }

    func testLoadHangs_TimesOut() async {
        let vm = makeVM(timeout: 0.1, fetch: { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return nil
        })
        await vm.load()
        guard case .failed = vm.state else { return XCTFail("Expected failed state") }
    }

    func testRetryAfterFailure_Succeeds() async {
        var calls = 0
        var loaded: LightweightPlaceList?
        let vm = makeVM(fetch: { _ in
            calls += 1
            if calls == 1 { throw URLError(.timedOut) }
            return self.makeList()
        }, onLoaded: { loaded = $0 })
        await vm.load()
        await vm.load()
        XCTAssertNotNil(loaded)
    }
}
