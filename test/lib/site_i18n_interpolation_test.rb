require "test_helper"

class SiteI18nInterpolationTest < ActiveSupport::TestCase
  test "translations can interpolate installation identity without caller plumbing" do
    assert_equal "IMASUS Access", I18n.t("sessions.new.eyebrow", locale: :en)
  end

  test "reserved interpolation values follow the active site configuration" do
    current = Rails.configuration.site
    custom = SiteConfig.new(
      profile: "custom",
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
      public_urls: current.public_urls,
      operations: current.operations,
      brand: current.brand
    )

    Rails.configuration.site = custom
    assert_equal "Commons Access", I18n.t("sessions.new.eyebrow", locale: :en)
  ensure
    Rails.configuration.site = current if current
  end

  test "unreserved missing interpolation arguments still raise" do
    assert_raises(I18n::MissingInterpolationArgument) do
      I18n.interpolate("Hello %{unknown}", {})
    end
  end
end
