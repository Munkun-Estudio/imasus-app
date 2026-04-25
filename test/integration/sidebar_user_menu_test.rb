require "test_helper"

# Exercises the sidebar user-menu trigger + flyout (the bottom-of-sidebar
# auth chrome added in spec 7) and the locale switcher's relocation from
# the sidebar footer into the top-right of the application layout.
class SidebarUserMenuTest < ActionDispatch::IntegrationTest
  def setup
    @password = "correct horse battery staple"
  end

  def make_user(role: :participant, institution: nil)
    User.create!(
      name: "Pablo Munk",
      email: "p-#{SecureRandom.hex(4)}@example.com",
      password: @password,
      role: role,
      institution: institution
    )
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  test "sidebar no longer contains the locale switcher block" do
    get root_url
    assert_select "nav[aria-label] [data-controller='locale-switcher']", count: 0
  end

  test "layout renders the locale switcher in the top-right" do
    get root_url
    assert_select "[data-locale-switcher-position='top-right'] [data-controller='locale-switcher']" do
      assert_select "a", minimum: 4
    end
  end

  test "logged-out sidebar shows a Log in link instead of the user menu" do
    get root_url
    assert_select "[data-user-menu]" do
      assert_select "a[href=?]", new_session_path,
                    text: I18n.t("user_menu.log_in")
      assert_select "[data-user-menu-target='flyout']", count: 0
    end
  end

  test "logged-in sidebar shows the user-menu trigger with name and initials" do
    user = make_user(institution: "Munkun Labs")
    sign_in(user)
    get root_url

    assert_select "[data-user-menu]" do
      assert_select "[data-user-menu-target='trigger']" do
        assert_select "[data-user-menu-target='initials']", text: "PM"
        assert_select "[data-user-menu-target='display-name']", text: user.name
        assert_select "[data-user-menu-target='secondary']", text: "Munkun Labs"
      end
    end
  end

  test "user-menu secondary line falls back to the role label when institution is blank" do
    user = make_user(institution: nil, role: :facilitator)
    sign_in(user)
    get root_url
    assert_select "[data-user-menu-target='secondary']",
                  text: I18n.t("roles.facilitator")
  end

  test "user-menu flyout contains email, Settings link, and Log out button" do
    user = make_user(institution: "Munkun")
    sign_in(user)
    get root_url

    assert_select "[data-user-menu-target='flyout']" do
      assert_select "[data-user-menu-target='email']", text: user.email
      assert_select "a[href=?]", edit_settings_path,
                    text: I18n.t("user_menu.settings")
      assert_select "form[action=?][method=post]", session_path do
        assert_select "input[name='_method'][value='delete']"
        assert_select "button", text: I18n.t("user_menu.log_out")
      end
    end
  end
end
