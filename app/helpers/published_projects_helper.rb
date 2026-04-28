module PublishedProjectsHelper
  def participant_profile_links(user)
    user.links.to_s.lines.map(&:strip).select { |url| url.match?(/\Ahttps?:\/\//) }
  end

  def participant_profile_link_label(url)
    uri = URI.parse(url)
    uri.host.to_s.delete_prefix("www.").presence || url
  rescue URI::InvalidURIError
    url
  end
end
