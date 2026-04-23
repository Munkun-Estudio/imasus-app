require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # System tests run Puma in a separate thread that can't see the test thread's
  # open transaction, so transactional rollback doesn't work for system tests.
  # We disable it and clean up committed data in teardown instead.
  self.use_transactional_tests = false

  def teardown
    ProjectMembership.delete_all
    Project.delete_all
    WorkshopParticipation.delete_all
    User.delete_all
    Workshop.delete_all
    super
  end
end
