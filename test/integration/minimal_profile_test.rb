require "test_helper"
require "open3"

class MinimalProfileTest < ActiveSupport::TestCase
  RUNNER_SCRIPT = <<~'RUBY'
    session = ActionDispatch::Integration::Session.new(Rails.application)

    session.get("/")
    abort "root failed: #{session.response.status}" unless session.response.status == 200
    abort "enabled Guides card missing" unless session.response.body.include?('data-resource="training"')
    abort "IMASUS resource loom rendered" if session.response.body.include?('data-home-section="imagineering-loom"')
    abort "configured module summary missing" unless session.response.body.include?("enabled resources: Guides")
    %w[materials challenges glossary].each do |key|
      abort "disabled #{key} card rendered" if session.response.body.include?(%[data-resource="#{key}"])
    end

    {
      "/training" => 200,
      "/materials" => 404,
      "/challenges" => 404,
      "/glossary" => 404,
      "/workshops" => 200
    }.each do |path, expected|
      session.get(path)
      abort "#{path}: expected #{expected}, got #{session.response.status}" unless session.response.status == expected
    end

    begin
      email = "minimal-profile-smoke@example.test"
      User.where(email:).delete_all
      User.create!(
        name: "Minimal profile",
        email:,
        password: "minimal-profile-password",
        role: :participant
      )
      session.post("/session", params: { email:, password: "minimal-profile-password" })
      abort "minimal login failed" unless session.response.redirect?

      session.post(
        "/bookmarks",
        params: {
          bookmark: {
            bookmarkable_type: "TrainingModule",
            resource_key: "guide/section/en/p-1",
            label: "Guide",
            url: "/training/guide/section"
          }
        },
        as: :json
      )
      abort "enabled bookmark failed: #{session.response.status}" unless session.response.status == 200

      session.post(
        "/bookmarks",
        params: {
          bookmark: {
            bookmarkable_type: "Material",
            resource_key: "1",
            label: "Hidden material",
            url: "/materials/hidden"
          }
        },
        as: :json
      )
      abort "disabled bookmark was accepted" unless session.response.status == 404
    ensure
      User.find_by(email: "minimal-profile-smoke@example.test")&.destroy!
    end
  RUBY

  test "minimal profile boots with one enabled module and safe disabled endpoints" do
    stdout, stderr, status = Open3.capture3(
      { "APP_PROFILE" => "minimal", "RAILS_ENV" => "test" },
      RbConfig.ruby,
      Rails.root.join("bin/rails").to_s,
      "runner",
      RUNNER_SCRIPT,
      chdir: Rails.root.to_s
    )

    assert status.success?, [ stdout, stderr ].reject(&:blank?).join("\n")
  end
end
