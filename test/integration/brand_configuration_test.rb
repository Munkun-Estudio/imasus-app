require "test_helper"

class BrandConfigurationTest < ActionDispatch::IntegrationTest
  test "default profile drives shared identity assets links and theme" do
    get root_url

    assert_response :success
    assert_select "meta[name='application-name'][content=?]", "IMASUS App"
    assert_select "meta[property='og:site_name'][content=?]", "IMASUS App"
    assert_select "img[alt=?][src*=?]", "IMASUS", "logo"
    assert_select "link[rel='icon'][href=?]", "/favicon.svg"
    assert_select "link[rel='manifest'][href=?]", "/site.webmanifest"
    assert_select "footer a[href=?]", "https://imasus.eu", text: "IMASUS"
    assert_select "footer a[href=?]", "mailto:webmasterINMA@unizar.es"
    assert_includes response.body, "--brand-primary: #1F3D3F"
    assert_includes response.body, "--brand-soft: #FFC2D7"
  end

  test "missing optional assets links and analytics render safe fallbacks" do
    with_site(minimal_site) do
      with_rails_environment("production") { get root_url }
    end

    assert_response :success
    assert_select "meta[name='application-name'][content=?]", "Workshop Commons"
    assert_select "meta[property='og:site_name'][content=?]", "Workshop Commons"
    assert_select "img[alt=?]", "Commons", count: 0
    assert_select "aside span", text: "Commons"
    assert_select "link[rel='icon']", count: 0
    assert_select "link[rel='manifest']", count: 0
    assert_select "meta[property='og:image']", count: 0
    assert_select "meta[name='twitter:image']", count: 0
    assert_select "meta[name='twitter:card'][content='summary']"
    assert_select "footer a[href=?]", "https://commons.example", text: "Commons"
    assert_select "footer a[href^='mailto:']", count: 0
    assert_select "script[src*='stats.munkun.com']", count: 0
    assert_includes response.body, "--brand-primary: #102030"
    assert_includes response.body, "Workshop Commons is the workshop platform"
  end

  test "configured sender identity and localized product name reach mail" do
    user = User.create!(
      name: "Member",
      email: "member-brand@example.com",
      password: "correct horse battery staple",
      role: :participant
    )
    user.generate_password_reset_token!

    with_site(minimal_site) do
      email = PasswordResetMailer.reset(user, user.password_reset_token)

      assert_equal [ "hello@commons.example" ], email.from
      assert_equal [ "member-brand@example.com" ], email.to
      assert_includes email.subject, "Commons"
      assert_includes email.body.encoded, "Commons"
    end
  end

  test "authentication and legal surfaces interpolate configured identity" do
    with_site(minimal_site) do
      get new_session_url
      assert_response :success
      assert_select "p", text: "Commons Access"
      assert_select "p", text: /Use your Commons account/

      get privacy_url
      assert_response :success
      assert_select "p", text: /Workshop Commons collects/
      assert_select "*", text: /%{(?:app_name|short_name|organization)}/, count: 0
      assert_not_includes response.body, "IMASUS"
    end
  end

  private

  def with_site(site)
    current = Rails.configuration.site
    Rails.configuration.site = site
    yield
  ensure
    Rails.configuration.site = current
  end

  def with_rails_environment(name)
    original = Rails.instance_variable_get(:@_env)
    Rails.instance_variable_set(:@_env, ActiveSupport::EnvironmentInquirer.new(name))
    yield
  ensure
    Rails.instance_variable_set(:@_env, original)
  end

  def minimal_site
    current = Rails.configuration.site
    SiteConfig.new(
      profile: "commons",
      profile_path: current.profile_path,
      version: current.version,
      identity: SiteConfig::Identity.new(
        name: "Workshop Commons",
        short_name: "Commons",
        organization: "Commons Foundation",
        description: "Shared workshop resources."
      ),
      locales: current.locales,
      modules: current.modules,
      content: current.content,
      public_urls: SiteConfig::PublicUrls.new(
        application: "https://app.commons.example",
        fallback: "https://fallback.commons.example",
        project: "https://commons.example",
        source: "https://github.com/example/commons",
        support: nil
      ),
      operations: SiteConfig::Operations.new(
        analytics: SiteConfig::Analytics.new(enabled: false, script_url: nil).freeze
      ).freeze,
      brand: SiteConfig::Brand.new(
        assets: SiteConfig::BrandAssets.new(
          logo: nil,
          compact_mark: nil,
          email_logo: nil,
          og_image: nil,
          favicon_ico: nil,
          favicon_svg: nil,
          favicon_png: nil,
          apple_touch_icon: nil,
          web_manifest: nil
        ).freeze,
        theme: SiteConfig::BrandTheme.new(
          primary: "#102030",
          secondary: "#203040",
          accent: "#304050",
          success: "#405060",
          info: "#506070",
          soft: "#607080"
        ).freeze,
        email: SiteConfig::BrandEmail.new(
          from_name: "Commons",
          from_address: "hello@commons.example"
        ).freeze
      ).freeze
    )
  end
end
