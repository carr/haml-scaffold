class HamlScaffoldGenerator < Rails::Generator::NamedBase
  default_options :skip_timestamps => false,
                  :skip_migration => false,
                  :skip_userstamps => false,
                  :skip_scope_everything => false,
                  :skip_positions => false,
                  :skip_inherited_resources => false,
                  :skip_formtastic => false,
                  :skip_toggles => false,
                  :include_helper => false

  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_underscore_name,
                :controller_singular_name,
                :controller_plural_name,
                :controller_type,
                :form_type

  alias_method  :controller_file_name,  :controller_underscore_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    # Add Userstamp fields if the UserStamp plugin is installed
    if defined?(ActiveRecord::Userstamp) && !options[:skip_userstamps]
      logger.info "Adding Userstamp fields"
      @args.push('created_by:integer')
      @args.push('updated_by:integer')
    end

    # Add a ScopeEverything field if the ScopeEverything plugin is installed
    if defined?(ActiveRecord::ScopeEverything) && !options[:skip_scope_everything]
      logger.info "Adding ScopeEverything field: #{ActiveRecord::ScopeEverything.field}"
      @args.push("#{ActiveRecord::ScopeEverything.field}:integer")
    end

    # Use InheritedResources type of controllers if the plugin is installed
    @controller_type = defined?(InheritedResources) && !options[:skip_inherited_resources] ? 'inherited_resources' : 'regular'
    logger.info "Using '#{@controller_type}' controller type"

    # Use Formtastic form type if the plugin is installed
    @form_type = defined?(Formtastic) && !options[:skip_formtastic] ? 'formtastic' : 'regular'
    logger.info "Using '#{@form_type}' form type"

    options[:has_position] = !attributes.select{|x| x.name=='position' && x.type==:integer}.blank? && !options[:skip_positions]

    if @name == @name.pluralize && !options[:force_plural]
      logger.warning "Plural version of the model detected, using singularized version.  Override with --force-plural."
      @name = @name.singularize
    end

    @controller_name = @name.pluralize
    @application_name = File.basename(Rails.root.to_s).humanize
    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_underscore_name, @controller_plural_name = inflect_names(base_name)
    @controller_singular_name = base_name.singularize

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
  end

  def manifest
    @rejected_attributes = ['created_by', 'updated_by', 'position']
    if defined?(ActiveRecord::ScopeEverything)
      @rejected_attributes << "#{ActiveRecord::ScopeEverything.field}"
    end
    @attributes.reject!{|x| @rejected_attributes.member?(x.name)}
    @attributes.sort!{|a, b| %w(name title).member?(a.name) ? -1 : 1 }

    record do |m|
      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, test and stylesheets directories.
      m.directory(File.join('app/models', class_path))
      m.directory(File.join('app/controllers', controller_class_path))
      m.directory(File.join('app/helpers', controller_class_path)) if options[:include_helper]
      m.directory(File.join('app/views', controller_class_path, controller_file_name))
      m.directory(File.join('test/functional', controller_class_path))
      m.directory(File.join('test/unit', class_path))
      m.directory('app/views/layouts')

      # scaffold all the basic views
      scaffold_views.each_pair do |action, filename|
        m.template( "views/#{filename}.html.haml.erb", 
                    File.join('app/views', controller_class_path, controller_file_name, "#{action}.html.haml"))
      end

      # scaffold the controller
      m.template("controllers/controller_#{controller_type}.rb.erb", File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb"))

      # scaffold the model
      m.template('model.rb', File.join('app/models', class_path, "#{name.underscore}.rb"))

      # everything else
      m.template('helper.rb.erb',          File.join('app/helpers',     controller_class_path, "#{controller_file_name}_helper.rb")) if options[:include_helper]
      m.template('helper_test.rb.erb',     File.join('test/unit/helpers',    controller_class_path, "#{controller_file_name}_helper_test.rb")) if options[:include_helper]
      m.template('functional_test.rb.erb', File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))
      m.template('layout.html.haml.erb', 'app/views/layouts/application.html.haml', :collision => :skip)

      # TODO fix this, ugly code
      routing_options = ''
      member_route_options = []
      member_route_options << ":move_lower => :put, :move_higher => :put" if options[:has_position]

      route_addon = ""
      if member_route_options.present?
        route_addon = ", :member => {#{member_route_options.join ', '}}"
      end

      m.infinum_route_resources  controller_file_name + route_addon

      m.dependency 'model', [name] + @args , :collision => :skip
    end

  end

  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} haml_scaffold ModelName [field:type, field:type]"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--skip-timestamps",
             "Don't add timestamps to the migration file for this model") { |v| options[:skip_timestamps] = v }
      opt.on("--skip-userstamps",
             "Don't add userstamps to the migration file for this model") { |v| options[:skip_userstamps] = v }
      opt.on("--skip-scope-everything",
             "Don't add a scope everything field to the migration file for this model") { |v| options[:skip_scope_everything] = v }
      opt.on("--skip-formtastic",
             "Don't add formtastic type of form") { |v| options[:skip_formtastic] = v }
      opt.on("--skip-inherited-resources",
             "Don't add inherited resources type of controller") { |v| options[:skip_inherited_resources] = v }
      opt.on("--skip-positions",
             "Don't add position related stuff") { |v| options[:skip_positions] = v }
      opt.on("--skip-migration",
             "Don't generate a migration file for this model") { |v| options[:skip_migration] = v }
      opt.on("--include-helper",
             "Generated helpers") { |v| options[:include_helper] = v }
      opt.on("--force-plural",
             "Forces the generation of a plural ModelName") { |v| options[:force_plural] = v }
    end

    def scaffold_views
      views = %w(index show new edit _list).inject({}) do |memo, view|
        memo[view] = view
        memo
      end
      views["_form"] = "_form_#{@form_type}"
      views
    end

    def model_name
      class_name.demodulize
    end
end

require 'fileutils'
module Rails
	module Generator
	  module Commands
	    class Create < Base
        # create routes
	      def infinum_route_resources(resource_list)
          look_for = 'ActionController::Routing::Routes.draw do |map|'
          logger.route "map.resources :#{resource_list}"

          unless options[:pretend]
            gsub_file 'config/routes.rb', /(#{Regexp.escape(look_for)})/mi do |match|
             "#{match}\n  map.resources :#{resource_list}\n"
            end
          end
        end
      end

      # destroy routes
      class Destroy < RewindBase
	      def infinum_route_resources(resource_list)
          look_for = "\n  map.resources :#{resource_list}\n"
          logger.route "map.resources :#{resource_list}"
          
          unless options[:pretend]
            gsub_file 'config/routes.rb', /(#{look_for})/mi, ''
          end
        end
      end
    end
  end
end

