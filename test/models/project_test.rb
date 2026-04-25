require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  def setup
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @admin       = User.create!(name: "Admin",    email: "admin@example.com",    role: :admin)
    @facilitator = User.create!(name: "Fac",      email: "fac@example.com",      role: :facilitator)
    @member      = User.create!(name: "Member",   email: "member@example.com",   role: :participant)
    @outsider    = User.create!(name: "Outsider", email: "outsider@example.com", role: :participant)

    WorkshopParticipation.create!(user: @member, workshop: @workshop)

    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: @project, user: @member)
  end

  # --- Validations ---

  test "valid with required attributes" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en", status: "draft")
    assert project.valid?
  end

  test "requires title" do
    project = Project.new(workshop: @workshop, language: "en", status: "draft")
    assert_not project.valid?
    assert_includes project.errors[:title], "can't be blank"
  end

  test "requires workshop" do
    project = Project.new(title: "Test", language: "en", status: "draft")
    assert_not project.valid?
    assert_includes project.errors[:workshop], "must exist"
  end

  test "rejects blank language when explicitly set" do
    project = Project.new(workshop: @workshop, title: "Test", status: "draft", language: "")
    assert_not project.valid?
    assert_includes project.errors[:language], "can't be blank"
  end

  test "rejects language outside allowed list" do
    project = Project.new(workshop: @workshop, title: "Test", language: "fr", status: "draft")
    assert_not project.valid?
    assert_includes project.errors[:language], "is not included in the list"
  end

  test "accepts all four allowed languages" do
    %w[en es it el].each do |lang|
      project = Project.new(workshop: @workshop, title: "Test", language: lang, status: "draft")
      assert project.valid?, "expected language '#{lang}' to be valid"
    end
  end

  test "rejects unknown status values" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en", status: "archived")
    assert_not project.valid?
    assert_includes project.errors[:status], "is not included in the list"
  end

  test "published is a valid status" do
    # Draft project can be saved without hero_image or process_summary; only
    # check that the status itself is in the allowed list.
    assert_includes Project::ALLOWED_STATUSES, "published"
  end

  test "status defaults to draft" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en")
    assert_equal "draft", project.status
  end

  # --- Language default from workshop ---

  test "language defaults from workshop communication_locale when not supplied" do
    project = Project.new(workshop: @workshop, title: "Test")
    assert_equal @workshop.communication_locale, project.language
  end

  # --- Associations ---

  test "belongs to challenge optionally" do
    project = Project.new(workshop: @workshop, title: "Test", language: "en", status: "draft")
    assert project.valid?
    assert_nil project.challenge
  end

  test "has many memberships and members through memberships" do
    assert_includes @project.members.reload, @member
  end

  test "destroying project cascades memberships" do
    membership_id = ProjectMembership.find_by(project: @project, user: @member).id
    @project.destroy!
    assert_nil ProjectMembership.find_by(id: membership_id)
  end

  # --- visible_to? ---

  test "visible_to? is true for a member" do
    assert @project.visible_to?(@member)
  end

  test "visible_to? is true for a facilitator" do
    assert @project.visible_to?(@facilitator)
  end

  test "visible_to? is true for an admin" do
    assert @project.visible_to?(@admin)
  end

  test "visible_to? is false for a non-member participant" do
    assert_not @project.visible_to?(@outsider)
  end

  test "visible_to? is false for nil (visitor)" do
    assert_not @project.visible_to?(nil)
  end

  # --- editable_by? ---

  test "editable_by? is true for a member" do
    assert @project.editable_by?(@member)
  end

  test "editable_by? is true for an admin" do
    assert @project.editable_by?(@admin)
  end

  test "editable_by? is false for a facilitator" do
    assert_not @project.editable_by?(@facilitator)
  end

  test "editable_by? is false for a non-member participant" do
    assert_not @project.editable_by?(@outsider)
  end

  test "editable_by? is false for nil" do
    assert_not @project.editable_by?(nil)
  end

  # --- Publication (spec 12) ---

  def attach_hero(project)
    project.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
  end

  test "published? predicate reflects status" do
    assert_not @project.published?
    @project.update_columns(status: "published")
    assert @project.reload.published?
  end

  test "publishable_by? is true for member on draft project" do
    assert @project.publishable_by?(@member)
  end

  test "publishable_by? is true for admin on draft project" do
    assert @project.publishable_by?(@admin)
  end

  test "publishable_by? is false for facilitator" do
    assert_not @project.publishable_by?(@facilitator)
  end

  test "publishable_by? is false for non-member participant" do
    assert_not @project.publishable_by?(@outsider)
  end

  test "publishable_by? is false for member on published project" do
    attach_hero(@project)
    @project.process_summary = "<p>Summary</p>"
    @project.status = "published"
    @project.save!
    assert_not @project.publishable_by?(@member)
  end

  test "republishable_by? is true for member on published project" do
    attach_hero(@project)
    @project.process_summary = "<p>Summary</p>"
    @project.status = "published"
    @project.save!
    assert @project.republishable_by?(@member)
  end

  test "republishable_by? is false for member on draft project" do
    assert_not @project.republishable_by?(@member)
  end

  test "republishable_by? is false for facilitator on published project" do
    attach_hero(@project)
    @project.process_summary = "<p>Summary</p>"
    @project.status = "published"
    @project.save!
    assert_not @project.republishable_by?(@facilitator)
  end

  test "publish requires hero_image and process_summary" do
    @project.status = "published"
    assert_not @project.valid?
    assert @project.errors[:hero_image].any?
    assert @project.errors[:process_summary].any?
  end

  test "publish succeeds when hero_image attached and process_summary present" do
    attach_hero(@project)
    @project.process_summary = "<p>How we got here</p>"
    @project.status = "published"
    assert @project.save, @project.errors.full_messages.join(", ")
  end

  test "publish rejects non-image hero attachment" do
    @project.hero_image.attach(
      io: StringIO.new("not an image"),
      filename: "notes.txt",
      content_type: "text/plain"
    )
    @project.process_summary = "<p>How we got here</p>"
    @project.status = "published"

    assert_not @project.valid?
    assert_includes @project.errors[:hero_image], "must be a JPEG or PNG image"
  end

  test "publish rejects hero image over 20 MB" do
    @project.hero_image.attach(
      io: StringIO.new("x" * (21.megabytes)),
      filename: "large.png",
      content_type: "image/png"
    )
    @project.process_summary = "<p>How we got here</p>"
    @project.status = "published"

    assert_not @project.valid?
    assert_includes @project.errors[:hero_image], "must be smaller than 20 MB"
  end

  test "draft save succeeds without hero_image or process_summary" do
    project = Project.new(workshop: @workshop, title: "Draft only", language: "en", status: "draft")
    assert project.valid?
  end

  test "slug generated from title on publish" do
    attach_hero(@project)
    @project.process_summary = "<p>S</p>"
    @project.status = "published"
    @project.save!
    assert_equal "kapok-project", @project.slug
  end

  test "slug collision is resolved with incrementing suffix" do
    attach_hero(@project)
    @project.process_summary = "<p>S</p>"
    @project.status = "published"
    @project.save!

    second = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: second, user: @member)
    second.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    second.process_summary = "<p>Second</p>"
    second.status = "published"
    second.save!
    assert_equal "kapok-project-2", second.slug

    third = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
    ProjectMembership.create!(project: third, user: @member)
    third.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    third.process_summary = "<p>Third</p>"
    third.status = "published"
    third.save!
    assert_equal "kapok-project-3", third.slug
  end

  test "slug not regenerated on re-save" do
    attach_hero(@project)
    @project.process_summary = "<p>S</p>"
    @project.status = "published"
    @project.save!
    original_slug = @project.slug

    @project.update!(title: "Completely Different Title")
    assert_equal original_slug, @project.reload.slug
  end

  test "slug max 100 chars" do
    long_title = "a" * 150
    project = Project.create!(workshop: @workshop, title: long_title, language: "en", status: "draft")
    ProjectMembership.create!(project: project, user: @member)
    project.hero_image.attach(
      io: Rails.root.join("test/fixtures/files/sample-image.png").open,
      filename: "sample-image.png",
      content_type: "image/png"
    )
    project.process_summary = "<p>S</p>"
    project.status = "published"
    project.save!
    assert project.slug.length <= 100
  end

  # --- Soft-disable (spec 13) ---

  test "disabled? is false on a fresh project" do
    assert_not @project.disabled?
    assert_nil @project.disabled_at
    assert_nil @project.disabled_by
  end

  test "disable! records timestamp and actor" do
    freeze_time do
      @project.disable!(by: @admin)
      assert @project.disabled?
      assert_equal Time.current, @project.disabled_at
      assert_equal @admin, @project.disabled_by
    end
  end

  test "disable! is idempotent" do
    @project.disable!(by: @admin)
    first = @project.disabled_at

    travel 5.minutes do
      @project.disable!(by: @facilitator)
    end

    assert_equal first, @project.reload.disabled_at
    assert_equal @admin, @project.disabled_by
  end

  test "enable! clears the disabled state" do
    @project.disable!(by: @admin)
    @project.enable!
    assert_not @project.disabled?
    assert_nil @project.disabled_at
    assert_nil @project.disabled_by
  end

  test "active scope excludes disabled projects" do
    @project.disable!(by: @admin)
    other = Project.create!(workshop: @workshop, title: "Other", language: "en", status: "draft")
    assert_includes Project.active, other
    assert_not_includes Project.active, @project
  end

  test "editable_by? returns false for members while disabled" do
    assert @project.editable_by?(@member), "sanity check: member can edit before disable"
    @project.disable!(by: @admin)
    assert_not @project.editable_by?(@member)
  end

  test "editable_by? returns false for admins while disabled" do
    assert @project.editable_by?(@admin), "sanity check: admin can edit before disable"
    @project.disable!(by: @admin)
    assert_not @project.editable_by?(@admin)
  end

  test "visible_to? still returns true for members while disabled" do
    @project.disable!(by: @admin)
    assert @project.visible_to?(@member)
    assert @project.visible_to?(@admin)
    assert @project.visible_to?(@facilitator)
    assert_not @project.visible_to?(@outsider)
  end

  test "publishable_by? returns false while disabled" do
    @project.disable!(by: @admin)
    assert_not @project.publishable_by?(@member)
  end

  test "republishable_by? returns false while disabled" do
    attach_hero(@project)
    @project.process_summary = "<p>S</p>"
    @project.status = "published"
    @project.save!

    @project.disable!(by: @admin)
    assert_not @project.republishable_by?(@member)
  end
end
