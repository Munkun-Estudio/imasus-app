module WorkshopsHelper
  # @param workshop [Workshop]
  # @return [String] human-readable date range in the current locale
  def workshop_date_range(workshop)
    return t("workshops.shared.date_tbd") if workshop.starts_on.blank? || workshop.ends_on.blank?

    return l(workshop.starts_on) if workshop.starts_on == workshop.ends_on

    "#{l(workshop.starts_on)} - #{l(workshop.ends_on)}"
  end

  # @param workshop [Workshop]
  # @return [String, nil] truncated locale-aware description excerpt
  def workshop_excerpt(workshop)
    workshop.description.to_s.squish.truncate(170, separator: " ")
  end

  # @param workshop [Workshop]
  # @return [Integer] number of public projects for the workshop
  def published_project_count(workshop)
    workshop.projects.count(&:published?)
  end

  # @param project [Project]
  # @return [String] display-ready project member names
  def project_member_names(project)
    project.members.map(&:name).to_sentence
  end

  # @param user [User]
  # @return [String] initials for compact project member avatars
  def member_initials(user)
    user.name.to_s.split.map { |word| word[0].upcase }.first(2).join
  end

  # @param workshop [Workshop]
  # @return [Boolean] whether the signed-in user participates in this workshop
  def attending_workshop?(workshop)
    return false unless current_user

    workshop.participations.any? { |participation| participation.user_id == current_user.id }
  end

  # @param workshop [Workshop]
  # @return [ActionText::RichText, nil] locale-appropriate agenda rich text
  def workshop_agenda(workshop)
    workshop.agenda_for(I18n.locale)
  end
end
