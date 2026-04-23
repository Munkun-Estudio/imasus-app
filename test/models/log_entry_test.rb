require "test_helper"

class LogEntryTest < ActiveSupport::TestCase
  def setup
    @workshop = Workshop.create!(
      slug: "spain-2026",
      title_translations: { "es" => "Taller IMASUS Espana" },
      description_translations: { "es" => "Un taller IMASUS en Zaragoza." },
      partner: "Munkun",
      location: "Zaragoza, Spain",
      starts_on: Date.new(2026, 4, 28),
      ends_on: Date.new(2026, 4, 28)
    )
    @member  = User.create!(name: "Member", email: "member@example.com", role: :participant)
    @project = Project.create!(workshop: @workshop, title: "Kapok Project", language: "es", status: "draft")
  end

  # --- Validations ---

  test "valid with project, author, and body" do
    entry = LogEntry.new(project: @project, author: @member, body: "We tried dyeing with indigo.")
    assert entry.valid?
  end

  test "requires body" do
    entry = LogEntry.new(project: @project, author: @member)
    assert_not entry.valid?
    assert_includes entry.errors[:body], "can't be blank"
  end

  test "requires project" do
    entry = LogEntry.new(author: @member, body: "Some observation.")
    assert_not entry.valid?
    assert_includes entry.errors[:project], "must exist"
  end

  test "requires author" do
    entry = LogEntry.new(project: @project, body: "Some observation.")
    assert_not entry.valid?
    assert_includes entry.errors[:author], "must exist"
  end

  # --- Associations ---

  test "belongs to project" do
    entry = LogEntry.create!(project: @project, author: @member, body: "Entry body")
    assert_equal @project, entry.project
  end

  test "belongs to author" do
    entry = LogEntry.create!(project: @project, author: @member, body: "Entry body")
    assert_equal @member, entry.author
  end

  test "destroying project cascades to log entries" do
    entry = LogEntry.create!(project: @project, author: @member, body: "Will be deleted")
    entry_id = entry.id
    @project.destroy!
    assert_nil LogEntry.find_by(id: entry_id)
  end

  # --- Ordering ---

  test "default scope orders newest first" do
    first  = LogEntry.create!(project: @project, author: @member, body: "First")
    second = LogEntry.create!(project: @project, author: @member, body: "Second")
    entries = @project.log_entries.reload
    assert_equal second, entries.first
    assert_equal first, entries.last
  end
end
