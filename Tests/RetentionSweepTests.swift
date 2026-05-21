import Foundation

func runRetentionSweepTests(_ t: TestRunner) {
    t.section("RetentionSweep")

    func make() throws -> (TestClock, TaskRepository, RetentionSweep) {
        let clock = TestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
        let db = try Database()
        let repo = try TaskRepository(database: db, clock: { [clock] in clock.now })
        let sweep = RetentionSweep(database: db, repository: repo, clock: { [clock] in clock.now })
        return (clock, repo, sweep)
    }

    t.run("sweep deletes rows older than window") {
        let (clock, repo, sweep) = try make()
        let stale = try repo.create(title: "old")
        clock.advance(by: retentionWindow + 1)
        let fresh = try repo.create(title: "new")
        let deleted = try sweep.run()
        t.assertEqual(deleted, 1)
        t.assertNil(try repo.fetch(id: stale.id))
        t.assertNotNil(try repo.fetch(id: fresh.id))
    }

    t.run("sweep keeps rows exactly at boundary") {
        let (clock, repo, sweep) = try make()
        let item = try repo.create(title: "borderline")
        clock.advance(by: retentionWindow)
        let deleted = try sweep.run()
        t.assertEqual(deleted, 0)
        t.assertNotNil(try repo.fetch(id: item.id))
    }

    t.run("sweep is idempotent") {
        let (clock, repo, sweep) = try make()
        _ = try repo.create(title: "a")
        clock.advance(by: retentionWindow + 1)
        _ = try repo.create(title: "b")
        t.assertEqual(try sweep.run(), 1)
        t.assertEqual(try sweep.run(), 0)
    }

    t.run("edited item survives sweep") {
        let (clock, repo, sweep) = try make()
        let item = try repo.create(title: "a")
        clock.advance(by: retentionWindow - 60)
        _ = try repo.update(id: item.id, title: "a'")
        clock.advance(by: 60)
        t.assertEqual(try sweep.run(), 0)
        t.assertNotNil(try repo.fetch(id: item.id))
    }
}
