class AppsController < ApplicationController

  def index
    respond_with App.all
  end

  def show
    respond_with App.find(params[:id])
  end

  def update
    app = App.find(params[:id])
    app.update(app_update_params)
    respond_with app
  end

  def destroy
    respond_with App.find(params[:id]).destroy
  end

  def create
    app = AppBuilder.create(app_params)

    if app.valid?
      app.run
    else
      logger.error("app validation failed: #{app.errors.to_hash}")
    end

    respond_with app
  rescue => ex
    app.try(:destroy)

    message =
      PanamaxAgent::ConnectionError === ex ? :fleet_connection_error : ex.message

    handle_exception(ex, message)
  end

  def journal
    respond_with App.find(params[:id]).journal(params[:cursor])
  rescue PanamaxAgent::ConnectionError => ex
    handle_exception(ex, :journal_connection_error)
  end

  def rebuild
    respond_with App.find(params[:id]).restart
  rescue PanamaxAgent::ConnectionError => ex
    handle_exception(ex, :fleet_connection_error)
  end

  def template
    template = TemplateBuilder.create(template_params, false)
    render json: { template: TemplateFileSerializer.new(template).to_yaml }
  end

  private

  def app_update_params
    params.permit(
      :id,
      :name,
      :from,
      :documentation
    )
  end

  def app_params
    params.permit(
      :template_id,
      :image,
      :type,
      :command,
      links: [[:service, :alias]],
      environment: [[:variable, :value, :required]],
      ports: [[:host_interface, :host_port, :container_port, :proto]],
      expose: [],
      volumes: [[:host_path, :container_path]]
    )
  end

  def template_params
    params[:app_id] = params[:id]
    params.permit(
      :app_id,
      :name,
      :description,
      :keywords,
      :authors,
      :type,
      :documentation
    )
  end
end
