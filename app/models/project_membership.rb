# Join record linking a {User} to a {Project}.
#
# All members are equal editors — there is no owner or role hierarchy within
# a team. The last member leaving automatically destroys the project.
#
# @!attribute [rw] project
#   @return [Project]
# @!attribute [rw] user
#   @return [User]
class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  validates :user_id, uniqueness: { scope: :project_id }

  after_destroy :destroy_project_if_empty

  private

  def destroy_project_if_empty
    project.destroy! if project.memberships.empty?
  end
end
