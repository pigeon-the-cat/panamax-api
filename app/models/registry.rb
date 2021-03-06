class Registry < ActiveRecord::Base
  validates :name, presence: true
  validates :endpoint_url, presence: true, is_valid_url: true

  def self.docker_hub
    self.find(0)
  end

  def self.enabled
    where(enabled: true)
  end

  def self.search(term, limit=nil)
    errors = []
    results = []
    self.enabled.each do |registry|
      response = registry.search(term)
      results += response[:remote_images] if response[:remote_images].present?
      errors << response[:error] if response[:error].present?
    end

    [
      limit ? results.first(limit) : results,
      errors
    ]
  end

  def search(term)
    response = registry_client.search(term)
    images = response["results"].map do |r|
      RemoteImage.new(
        id: r['name'],
        description: r['description'],
        is_official: r['is_official'],
        is_trusted: r['is_trusted'],
        star_count: r['star_count'],
        registry_id: id,
        registry_name: name
      )
    end
    {
      remote_images: images
    }
  rescue StandardError => e
    {
      error: {
        registry_id: id,
        summary: I18n.t('registry_search_error', name: name),
        details: "#{e.class.name}: #{e.message}"
      }
    }
  end

  def prefix
    "#{endpoint_url_without_scheme}/" unless id == 0
  end

  # At this time, find_by_name only populates the id and tags, getting
  # is_official, is_trusted and star_count would require another service call
  def find_image_by_name(name)
    tags = registry_client.list_repository_tags(name)
    RemoteImage.new(id: name, tags: coerce_tags(tags))
  end

  private

  def endpoint_url_without_scheme
    endpoint_url.gsub(/^#{parsed_endpoint_uri.scheme}:\/\//,'')
  end

  def parsed_endpoint_uri
    URI.parse(endpoint_url)
  end

  def coerce_tags(tags)
    tags.map { |k,v| k.try(:[], "name") || k }
  end

  def registry_client
    @registry_client ||= PanamaxAgent::Registry::Client.new(
      registry_api_url: endpoint_url
    )
  end
end
