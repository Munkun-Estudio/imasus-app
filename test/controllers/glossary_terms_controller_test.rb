require "test_helper"

class GlossaryTermsControllerTest < ActionDispatch::IntegrationTest
  setup do
    GlossaryTerm.seed_from_yaml!
    @password = "correct horse battery staple"
    @admin       = User.create!(name: "Admin",       email: "g-admin@example.com",       password: @password, role: :admin)
    @facilitator = User.create!(name: "Facilitator", email: "g-facilitator@example.com", password: @password, role: :facilitator)
    @participant = User.create!(name: "Participant", email: "g-participant@example.com", password: @password, role: :participant)
  end

  def sign_in(user)
    post session_path, params: { email: user.email, password: @password }
  end

  def valid_params(overrides = {})
    {
      glossary_term: {
        slug:     "test-term",
        category: "methodology",
        term_translations: { "en" => "Test Term" },
        definition_translations: { "en" => "A term used in tests." }
      }.deep_merge(overrides.fetch(:glossary_term, {}))
    }.merge(overrides.except(:glossary_term))
  end

  # --- Index --------------------------------------------------------------

  test "GET /glossary returns 200" do
    get glossary_terms_url
    assert_response :success
  end

  test "GET /glossary lists every seeded term (English)" do
    get glossary_terms_url
    GlossaryTerm.find_each do |term|
      assert_select "a[href=?]", glossary_term_path(term.slug)
      assert_includes response.body, term.term_in(:en)
    end
  end

  test "GET /glossary renders a category filter pill for every non-empty category" do
    get glossary_terms_url
    GlossaryTerm.distinct.pluck(:category).each do |category|
      assert_select "a[href=?]", glossary_terms_path(category: category)
    end
  end

  test "GET /glossary?category=methodology only lists methodology terms" do
    get glossary_terms_url(category: "methodology")
    GlossaryTerm.where(category: "methodology").find_each do |term|
      assert_select "a[href=?]", glossary_term_path(term.slug)
    end
    GlossaryTerm.where.not(category: "methodology").find_each do |term|
      assert_select "a[href=?]", glossary_term_path(term.slug), count: 0
    end
  end

  test "GET /glossary renders an A–Z jumpnav with every letter" do
    get glossary_terms_url
    ("A".."Z").each do |letter|
      assert_select "[data-glossary-letter=?]", letter
    end
  end

  test "GET /glossary with an unknown category renders the full list" do
    get glossary_terms_url(category: "nonsense")
    assert_response :success
    GlossaryTerm.find_each do |term|
      assert_select "a[href=?]", glossary_term_path(term.slug)
    end
  end

  # --- Show ---------------------------------------------------------------

  test "GET /glossary/:slug returns 200 for an existing term" do
    get glossary_term_url("framework")
    assert_response :success
  end

  test "GET /glossary/:slug renders term, definition, and category" do
    get glossary_term_url("framework")
    framework = GlossaryTerm.find_by!(slug: "framework")
    assert_select "h1", text: framework.term_in(:en)
    assert_select "[data-glossary-category]", text: /methodology/i
    assert_includes response.body, framework.definition_in(:en).strip
  end

  test "GET /glossary/:slug renders English examples when present" do
    get glossary_term_url("framework")
    GlossaryTerm.find_by!(slug: "framework").examples_in(:en).each do |example|
      assert_includes response.body, example
    end
  end

  test "GET /glossary/:slug links back to the index" do
    get glossary_term_url("framework")
    assert_select "a[href=?]", glossary_terms_path
  end

  test "GET /glossary/:slug returns 404 for unknown slug" do
    get glossary_term_url("does-not-exist")
    assert_response :not_found
  end

  # --- Locale swapping ----------------------------------------------------

  test "switching locale swaps term and definition on show" do
    get glossary_term_url("framework", locale: "es")
    assert_response :success
    assert_select "h1", text: "Marco"
  end

  # --- Popover (XHR fetch) ------------------------------------------------

  test "GET /glossary/:slug/popover returns 200 without layout" do
    get popover_glossary_term_url("framework")
    assert_response :success
    framework = GlossaryTerm.find_by!(slug: "framework")
    assert_includes response.body, framework.term_in(:en)
    assert_includes response.body, framework.definition_in(:en).strip
    assert_select "a[href=?]", glossary_term_path("framework")
    assert_no_match(/<html/i, response.body, "popover should render without the application layout")
  end

  test "GET /glossary/:slug/popover returns 404 for unknown slug" do
    get popover_glossary_term_url("does-not-exist")
    assert_response :not_found
  end

  test "GET /glossary/:slug/popover is open to anonymous visitors" do
    get popover_glossary_term_url("framework")
    assert_response :success
  end

  # --- Curator affordances ------------------------------------------------

  test "anonymous visitor does not see the 'Add term' affordance" do
    get glossary_terms_url
    assert_select "a[data-role='add-glossary-term']", count: 0
  end

  test "anonymous visitor does not see per-term Edit/Delete affordances" do
    get glossary_term_url("framework")
    assert_select "[data-role='edit-glossary-term']", count: 0
    assert_select "[data-role='delete-glossary-term']", count: 0
  end

  test "participant does not see curator affordances" do
    sign_in(@participant)
    get glossary_terms_url
    assert_select "a[data-role='add-glossary-term']", count: 0
    assert_select "[data-role='edit-glossary-term']", count: 0
    assert_select "[data-role='delete-glossary-term']", count: 0
  end

  test "admin sees 'Add term' affordance on index" do
    sign_in(@admin)
    get glossary_terms_url
    assert_select "a[data-role='add-glossary-term'][href=?]", new_glossary_term_path
  end

  test "facilitator sees per-term Edit/Delete affordances on index" do
    sign_in(@facilitator)
    get glossary_terms_url
    framework = GlossaryTerm.find_by!(slug: "framework")
    assert_select "a[data-role='edit-glossary-term'][href=?]", edit_glossary_term_path(framework.slug)
    assert_select "[data-role='delete-glossary-term']"
  end

  # --- Role guards (write actions) ----------------------------------------

  test "anonymous visitor cannot GET new" do
    get new_glossary_term_url
    assert_redirected_to new_session_path
  end

  test "participant cannot GET new" do
    sign_in(@participant)
    get new_glossary_term_url
    assert_redirected_to root_path
    assert_not_nil flash[:alert]
  end

  test "admin and facilitator can GET new" do
    [ @admin, @facilitator ].each do |user|
      sign_in(user)
      get new_glossary_term_url
      assert_response :success
      delete session_path
    end
  end

  test "participant cannot POST create" do
    sign_in(@participant)
    assert_no_difference -> { GlossaryTerm.count } do
      post glossary_terms_url, params: valid_params
    end
    assert_redirected_to root_path
  end

  test "participant cannot GET edit" do
    sign_in(@participant)
    get edit_glossary_term_url("framework")
    assert_redirected_to root_path
  end

  test "participant cannot PATCH update" do
    sign_in(@participant)
    framework = GlossaryTerm.find_by!(slug: "framework")
    patch glossary_term_url("framework"), params: { glossary_term: { term_translations: { "en" => "Hacked" } } }
    assert_redirected_to root_path
    assert_equal "Framework", framework.reload.term_in(:en)
  end

  test "participant cannot DELETE destroy" do
    sign_in(@participant)
    assert_no_difference -> { GlossaryTerm.count } do
      delete glossary_term_url("framework")
    end
    assert_redirected_to root_path
  end

  # --- Curator happy path -------------------------------------------------

  test "admin can create a new glossary term" do
    sign_in(@admin)
    assert_difference -> { GlossaryTerm.count }, +1 do
      post glossary_terms_url, params: valid_params
    end
    created = GlossaryTerm.last
    assert_equal "test-term", created.slug
    assert_equal "methodology", created.category
    assert_equal "Test Term", created.term_in(:en)
    assert_redirected_to glossary_term_path(created.slug)
    assert_not_nil flash[:notice]
  end

  test "create with invalid data re-renders new with status 422" do
    sign_in(@admin)
    assert_no_difference -> { GlossaryTerm.count } do
      post glossary_terms_url, params: valid_params(glossary_term: { term_translations: { "en" => "" } })
    end
    assert_response :unprocessable_entity
  end

  test "facilitator can update a term" do
    sign_in(@facilitator)
    framework = GlossaryTerm.find_by!(slug: "framework")
    patch glossary_term_url("framework"),
          params: { glossary_term: { term_translations: { "en" => "Framework", "es" => "Estructura" } } }
    assert_redirected_to glossary_term_path(framework.slug)
    assert_equal "Estructura", framework.reload.term_in(:es)
  end

  test "update with invalid data re-renders edit with status 422" do
    sign_in(@admin)
    patch glossary_term_url("framework"),
          params: { glossary_term: { term_translations: { "en" => "" } } }
    assert_response :unprocessable_entity
  end

  test "admin can destroy a term" do
    sign_in(@admin)
    assert_difference -> { GlossaryTerm.count }, -1 do
      delete glossary_term_url("framework")
    end
    assert_redirected_to glossary_terms_path
    assert_not_nil flash[:notice]
    assert_nil GlossaryTerm.find_by(slug: "framework")
  end
end
