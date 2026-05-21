import Foundation

func runTaskRepositoryTests(_ t: TestRunner) {
    t.section("TaskRepository")

    func make() throws -> (TestClock, TaskRepository) {
        let clock = TestClock(start: Date(timeIntervalSince1970: 1_700_000_000))
        let db = try Database()
        let repo = try TaskRepository(database: db, clock: { [clock] in clock.now })
        return (clock, repo)
    }

    t.run("create inserts task with timestamps") {
        let (clock, repo) = try make()
        let item = try repo.create(title: "Pay rent")
        t.assertEqual(item.title, "Pay rent")
        t.assertNil(item.details)
        t.assertNil(item.dueAt)
        t.assertNil(item.completedAt)
        t.assertEqual(item.createdAt, clock.now)
        t.assertEqual(item.updatedAt, clock.now)
        t.assertEqual(try repo.fetch(id: item.id), item)
    }

    t.run("create trims title") {
        let (_, repo) = try make()
        let item = try repo.create(title: "   leading & trailing   ")
        t.assertEqual(item.title, "leading & trailing")
    }

    t.run("create rejects empty title") {
        let (_, repo) = try make()
        t.assertThrows(TaskRepositoryError.titleEmpty) {
            _ = try repo.create(title: "   ")
        }
    }

    t.run("create normalizes empty details to nil") {
        let (_, repo) = try make()
        let item = try repo.create(title: "x", details: "")
        t.assertNil(item.details)
    }

    t.run("create rejects due date beyond window") {
        let (clock, repo) = try make()
        let tooFar = clock.now.addingTimeInterval(retentionWindow + 60)
        t.assertThrows(TaskRepositoryError.dueDateBeyondRetentionWindow) {
            _ = try repo.create(title: "x", dueAt: tooFar)
        }
    }

    t.run("update changes updatedAt") {
        let (clock, repo) = try make()
        var item = try repo.create(title: "before")
        let originalUpdate = item.updatedAt
        clock.advance(by: 60)
        item = try repo.update(id: item.id, title: "after")
        t.assertEqual(item.title, "after")
        t.assertGreaterThan(item.updatedAt, originalUpdate)
        t.assertEqual(item.updatedAt, clock.now)
    }

    t.run("update details explicit nil clears field") {
        let (_, repo) = try make()
        let item = try repo.create(title: "x", details: "y")
        let cleared = try repo.update(id: item.id, details: .some(nil))
        t.assertNil(cleared.details)
    }

    t.run("update rejects empty title") {
        let (_, repo) = try make()
        let item = try repo.create(title: "x")
        t.assertThrows(TaskRepositoryError.titleEmpty) {
            _ = try repo.update(id: item.id, title: "")
        }
    }

    t.run("update not found throws") {
        let (_, repo) = try make()
        let missing = UUID()
        t.assertThrows(TaskRepositoryError.notFound(missing)) {
            _ = try repo.update(id: missing, title: "x")
        }
    }

    t.run("setCompleted sets timestamp and updatedAt") {
        let (clock, repo) = try make()
        let item = try repo.create(title: "x")
        clock.advance(by: 10)
        let done = try repo.setCompleted(id: item.id, completed: true)
        t.assertEqual(done.completedAt, clock.now)
        t.assertEqual(done.updatedAt, clock.now)
    }

    t.run("setCompleted false clears timestamp") {
        let (_, repo) = try make()
        let item = try repo.create(title: "x")
        _ = try repo.setCompleted(id: item.id, completed: true)
        let reopened = try repo.setCompleted(id: item.id, completed: false)
        t.assertNil(reopened.completedAt)
    }

    t.run("delete removes row") {
        let (_, repo) = try make()
        let item = try repo.create(title: "x")
        try repo.delete(id: item.id)
        t.assertNil(try repo.fetch(id: item.id))
    }

    t.run("active and done lists are partitioned") {
        let (_, repo) = try make()
        let a = try repo.create(title: "a")
        let b = try repo.create(title: "b")
        _ = try repo.setCompleted(id: b.id, completed: true)
        t.assertEqual(try repo.fetchActive().map(\.id), [a.id])
        t.assertEqual(try repo.fetchDone().map(\.id), [b.id])
    }

    t.run("active sorted by updatedAt desc") {
        let (clock, repo) = try make()
        let a = try repo.create(title: "a")
        clock.advance(by: 1)
        let b = try repo.create(title: "b")
        clock.advance(by: 1)
        _ = try repo.update(id: a.id, title: "a-edited")
        t.assertEqual(try repo.fetchActive().map(\.id), [a.id, b.id])
    }

    t.run("expired rows hidden by reads") {
        let (clock, repo) = try make()
        let stale = try repo.create(title: "old")
        clock.advance(by: retentionWindow + 1)
        _ = try repo.create(title: "new")
        let activeIds = try repo.fetchActive().map(\.id)
        t.assertTrue(!activeIds.contains(stale.id), "stale row should be hidden")
    }
}
