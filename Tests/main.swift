import Foundation

let t = TestRunner()
runTaskRepositoryTests(t)
runRetentionSweepTests(t)
exit(t.summarize())
