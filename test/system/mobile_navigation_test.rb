require "application_system_test_case"

class MobileNavigationTest < ApplicationSystemTestCase
  setup do
    Capybara.current_session.current_window.resize_to(375, 812)
  end

  test "hamburger menu toggles sidebar overlay on mobile" do
    visit root_url

    # Sidebar should be hidden on mobile
    assert_no_selector "nav[aria-label]", visible: :visible

    # Click hamburger to open
    find("[data-mobile-menu-target='toggle']").click
    assert_selector "nav[aria-label]", visible: :visible

    # Click hamburger again to close
    find("[data-mobile-menu-target='toggle']").click
    assert_no_selector "nav[aria-label]", visible: :visible
  end

  test "sidebar closes when pressing Escape" do
    visit root_url

    find("[data-mobile-menu-target='toggle']").click
    assert_selector "nav[aria-label]", visible: :visible

    find("body").send_keys(:escape)
    assert_no_selector "nav[aria-label]", visible: :visible
  end
end
