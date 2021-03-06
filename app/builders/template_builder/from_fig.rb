module TemplateBuilder
  class FromFig

    attr_reader :fig_yml, :options

    def initialize(options)
      @fig_yml = options.delete('fig_yml')
      @options = options
    end

    def create_template(persisted=true)
      Template.new(self.options) do |template|
        template.images = images_from_fig if fig_yml
        template.save if persisted
      end
    end

    private

    def images_from_fig
      fig_services = YAML.safe_load(fig_yml) || {}
      fig_services.map { |name, service_def| image_from_fig_service(name, service_def) }
    end

    def image_from_fig_service(name, service_def)
      Image.new(name: name) do |image|
        image.source = service_def['image']
        image.links = links(service_def['links'])
        image.ports = ports(service_def['ports'])
        image.expose = service_def['expose']
        image.volumes = volumes(service_def['volumes'])
        image.environment = service_def['environment']
        image.volumes_from = shared_volumes(service_def['volumes_from'])
      end
    end

    def links(links_array)
      Array(links_array).map do |link|
        service, prefix = link.split(':')
        # fig allows links without aliases, so we'll default the alias to the linked service name
        prefix ||= service
        ['service', 'alias'].zip([service, prefix]).to_h
      end
    end

    def ports(ports_array)
      Array(ports_array).map do |port|
        ['host_port', 'container_port'].zip(port.split(':')).to_h
      end
    end

    def volumes(volumes_array)
      Array(volumes_array).map do |volume|
        ['host_path', 'container_path'].zip(volume.split(':')).to_h
      end
    end

    def shared_volumes(vol_from_array)
      Array(vol_from_array).map do |vol_from|
        { 'service' => vol_from }
      end
    end

  end
end
