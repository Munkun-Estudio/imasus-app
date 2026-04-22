require "test_helper"

class ChallengesControllerTest < ActionDispatch::IntegrationTest
  setup do
    Challenge.seed_from_yaml!
    @password = "correct horse battery staple"
    @admin       = User.create!(name: "Admin",       email: "c-admin@example.com",       password: @password, role: :admin)
    @facilitator = User.create!(name: "Facilitator", email: "c-facilitator@example.com", password: @password, role: :facilitator)
    @participant = User.create!(name: "Participant", email: "c-participant@example.com", password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  # --- Index ---------------------------------------------------------------

  test "GET /challenges returns 200" do
    get challenges_url
    assert_response :success
  end

  test "GET /challenges links to every seeded challenge via the preview endpoint" do
    get challenges_url
    Challenge.find_each do |challenge|
      assert_select "a[href=?]", preview_challenge_path(challenge.to_param)
    end
  end

  test "GET /challenges renders each challenge's English question" do
    get challenges_url
    Challenge.find_each do |challenge|
      assert_includes response.body, challenge.question_in(:en)
    end
  end

  test "GET /challenges groups challenges by category in the stable order material → design → system → business" do
    get challenges_url

    body = response.body
    positions = Challenge::CATEGORIES.map { |cat| [ cat, body.index(%r{data-category="#{cat}"}) ] }.to_h

    positions.each do |cat, pos|
      assert pos, "expected a section for category '#{cat}' on the index"
    end

    ordered = positions.sort_by { |_cat, pos| pos }.map(&:first)
    assert_equal Challenge::CATEGORIES, ordered,
                 "categories should render in the canonical order, got #{ordered.inspect}"
  end

  test "GET /challenges orders challenges within a category by numeric code" do
    get challenges_url
    body = response.body

    material_codes = Challenge.where(category: "material").by_code.pluck(:code)
    positions = material_codes.map { |code| body.index(code) }
    assert_equal positions, positions.sort,
                 "material challenges should render in numeric code order; got positions #{positions.inspect} for codes #{material_codes.inspect}"
  end

  test "card's main link targets the preview drawer (data-turbo-frame='preview')" do
    get challenges_url
    assert_select "a[href=?][data-turbo-frame='preview']", preview_challenge_path("c1")
  end

  test "there is no standalone challenge show route" do
    assert_raises(ActionController::UrlGenerationError) do
      url_for(controller: "challenges", action: "show", code: "c1")
    end
  end

  test "GET /challenges/:code returns 404 (no standalone show page)" do
    get "/challenges/c1"
    assert_response :not_found
  end

  # --- Preview (drawer) ----------------------------------------------------

  test "GET /challenges/:code/preview returns 200 for a known code" do
    get preview_challenge_url("c1")
    assert_response :success
  end

  test "GET /challenges/:code/preview is case-insensitive on code" do
    get preview_challenge_url("C1")
    assert_response :success
  end

  test "GET /challenges/:code/preview renders code, category label, and English question/description" do
    get preview_challenge_url("c1")
    c1 = Challenge.find_by!(code: "C1")
    assert_includes response.body, c1.code
    assert_includes response.body, c1.question_in(:en)
    assert_includes response.body, c1.description_in(:en).strip.split("\n").first
  end

  test "GET /challenges/:code/preview renders without the application layout" do
    get preview_challenge_url("c1")
    assert_no_match(/<html/i, response.body,
                    "preview should render bare, without the application layout")
  end

  test "GET /challenges/:code/preview uses a dialog role and is not modal" do
    get preview_challenge_url("c1")
    assert_select "[role='dialog'][aria-modal='false']"
  end

  test "GET /challenges/:code/preview renders the Spanish question under locale=es" do
    get preview_challenge_url("c1", locale: :es)
    c1 = Challenge.find_by!(code: "C1")
    assert_includes response.body, c1.question_in(:es)
  end

  test "GET /challenges/:code/preview returns 404 for unknown code" do
    get preview_challenge_url("c99")
    assert_response :not_found
  end

  test "GET /challenges/:code/preview returns 404 for malformed code" do
    get preview_challenge_url("not-a-code")
    assert_response :not_found
  end

  # --- Curator affordances -------------------------------------------------

  test "anonymous visitor does not see per-challenge Edit affordance on index" do
    get challenges_url
    assert_select "[data-role='edit-challenge']", count: 0
  end

  test "anonymous visitor does not see Edit affordance inside the preview drawer" do
    get preview_challenge_url("c1")
    assert_select "[data-role='edit-challenge']", count: 0
  end

  test "participant does not see Edit affordance" do
    sign_in(@participant)
    get challenges_url
    assert_select "[data-role='edit-challenge']", count: 0
    get preview_challenge_url("c1")
    assert_select "[data-role='edit-challenge']", count: 0
  end

  test "index never exposes an 'Add challenge' affordance (fixed set of ten)" do
    sign_in(@admin)
    get challenges_url
    assert_select "[data-role='add-challenge']", count: 0
  end

  test "admin sees Edit affordance on each card on index" do
    sign_in(@admin)
    get challenges_url
    Challenge.find_each do |challenge|
      assert_select "a[data-role='edit-challenge'][href=?]", edit_challenge_path(challenge.to_param)
    end
  end

  test "facilitator sees Edit affordance inside the preview drawer" do
    sign_in(@facilitator)
    get preview_challenge_url("c1")
    assert_select "a[data-role='edit-challenge'][href=?]", edit_challenge_path("c1")
  end

  # --- Role guards (write actions) -----------------------------------------

  test "anonymous visitor cannot GET edit" do
    get edit_challenge_url("c1")
    assert_redirected_to new_session_path
  end

  test "participant cannot GET edit" do
    sign_in(@participant)
    get edit_challenge_url("c1")
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "admin and facilitator can GET edit" do
    [ @admin, @facilitator ].each do |user|
      sign_in(user)
      get edit_challenge_url("c1")
      assert_response :success
      delete session_path
    end
  end

  test "anonymous visitor cannot PATCH update" do
    c1 = Challenge.find_by!(code: "C1")
    original = c1.question_in(:en)
    patch challenge_url("c1"), params: { challenge: { question_translations: { "en" => "Hacked" } } }
    assert_redirected_to new_session_path
    assert_equal original, c1.reload.question_in(:en)
  end

  test "participant cannot PATCH update" do
    sign_in(@participant)
    c1 = Challenge.find_by!(code: "C1")
    original = c1.question_in(:en)
    patch challenge_url("c1"), params: { challenge: { question_translations: { "en" => "Hacked" } } }
    assert_redirected_to root_path
    assert_equal original, c1.reload.question_in(:en)
  end

  test "no destroy route exists" do
    assert_raises(ActionController::UrlGenerationError) do
      url_for(controller: "challenges", action: "destroy", code: "c1")
    end
  end

  # --- Curator happy path --------------------------------------------------

  test "facilitator can update a challenge and is redirected to the index" do
    sign_in(@facilitator)
    c1 = Challenge.find_by!(code: "C1")
    patch challenge_url("c1"),
          params: { challenge: { question_translations: { "en" => "How might we rethink waste?", "es" => "¿Cómo repensar los residuos?" } } }
    assert_redirected_to challenges_path
    c1.reload
    assert_equal "How might we rethink waste?", c1.question_in(:en)
    assert_equal "¿Cómo repensar los residuos?", c1.question_in(:es)
  end

  test "update responds with turbo_stream replacing the card when requested" do
    sign_in(@admin)
    patch challenge_url("c1"),
          params: { challenge: { question_translations: { "en" => "Updated question", "es" => "", "it" => "", "el" => "" } } },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }
    assert_response :success
    assert_match(/turbo-stream/, response.content_type)
    assert_match(/action="replace"/, response.body)
  end

  test "update with invalid data re-renders edit with 422" do
    sign_in(@admin)
    patch challenge_url("c1"),
          params: { challenge: { question_translations: { "en" => "" } } }
    assert_response :unprocessable_entity
  end

  test "update cannot change code" do
    sign_in(@admin)
    c1 = Challenge.find_by!(code: "C1")
    patch challenge_url("c1"),
          params: { challenge: { code: "C99", question_translations: { "en" => c1.question_in(:en) } } }
    c1.reload
    assert_equal "C1", c1.code
  end
end
