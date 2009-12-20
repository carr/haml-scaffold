class HamlScaffoldGenerator < Rails::Generator::NamedBase
  default_options :skip_timestamps => false,
                  :skip_migration => false,
                  :skip_userstamps => false,
                  :skip_scope_everything => false,
                  :skip_positions => false,
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
                :application_name
  alias_method  :controller_file_name,  :controller_underscore_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    # add userstamp fields
    if defined?(ActiveRecord::Userstamp) && !options[:skip_userstamps]
      @args.push('created_by:integer')
      @args.push('updated_by:integer')
    end

    # add scope everything field
    if defined?(ActiveRecord::ScopeEverything) && !options[:skip_scope_everything]
      @args.push("#{ActiveRecord::ScopeEverything.field}:integer")
    end

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
      m.directory('public/stylesheets/sass')

      for action in scaffold_views
        filename = action
        m.template("views/#{action}.html.haml.erb", File.join('app/views', controller_class_path, controller_file_name, "#{filename}.html.haml"))
      end

      controller_type = defined?(InheritedResources) ? 'inherited_resources' : regular
      m.template("controller_#{controller_type}.rb.erb", File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb"))

      m.template('helper.rb.erb',          File.join('app/helpers',     controller_class_path, "#{controller_file_name}_helper.rb")) if options[:include_helper]
      m.template('helper_test.rb.erb',     File.join('test/unit/helpers',    controller_class_path, "#{controller_file_name}_helper_test.rb")) if options[:include_helper]

      m.template('functional_test.rb.erb', File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))

      m.template('layout.html.haml.erb', 'app/views/layouts/application.html.haml', :collision => :skip, :assigns => {:application_name => @application_name})
      m.template('stylesheet.sass', 'public/stylesheets/sass/application.sass', :collision => :skip)

      m.template('model.rb', File.join('app/models', class_path, "#{name.underscore}.rb"))

      routing_options = ''
      member_route_options = []
      member_route_options << ":move_lower => :put, :move_higher => :put" if options[:has_position]

      route_addon = ""
      unless member_route_options.blank?
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
             "Don't add scope everyhing fields to the migration file for this model") { |v| options[:skip_scope_everything] = v }
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
      %w[ index show new edit _form _list ]
    end

    def model_name
      class_name.demodulize
    end
end


#class InfinumScaffoldGenerator < Rails::Generator::NamedBase
#  default_options :skip_timestamps => false, :skip_migration => false

#  attr_reader   :controller_name,
#                :controller_class_path,
#                :controller_file_path,
#                :controller_class_nesting,
#                :controller_class_nesting_depth,
#                :controller_class_name,
#                :controller_underscore_name,
#                :controller_singular_name,
#                :controller_plural_name
#  alias_method  :controller_file_name,  :controller_underscore_name
#  alias_method  :controller_table_name, :controller_plural_name

#  def initialize(runtime_args, runtime_options = {})
#    super
#
#    unless options[:skip_stampable]
#      @args.push('created_by:integer')
#      @args.push('updated_by:integer')
#    end
#    # options for some extra actions
#    options[:has_position] = false
#    options[:is_toggable] = false
#    attributes.each do |attribute|
#      options[:has_position]=true if attribute.name == 'position' && attribute.type == :integer && !options[:ignore_position]
#      if attribute.type == :boolean && !options[:ignore_toggable]
#        puts "More than one boolean atribute. Last one will be affected by toggable action" if options[:is_toggable]
#        options[:toggable_attribute_name] = attribute.name
#        options[:is_toggable]=true
#      end
#    end

#    if options[:lang_croatian]
#      if options[:lang_gender_male]
#        options[:t_was_successfully_updated] = 'je uspiješno izmijenjen.'
#        options[:t_success_fully_createed] = 'je uspiješno kreiran.'
#        options[:t_save_and_add_new] = 'Spremi i dodaj novi'
#        options[:t_new] = 'Novi'
#      else
#        options[:t_was_successfully_updated] = 'je uspiješno izmijenjena.'
#        options[:t_success_fully_createed] = 'je uspiješno kreirana.'
#        options[:t_save_and_add_new] = 'Spremi i dodaj novu'
#        options[:t_new] = 'Nova'
#      end
#      options[:t_save] = '<em>S</em>premi'
#      options[:t_editing] = 'Izmjena'
#      options[:t_listing] = 'Prikaz'
#      options[:t_back] = 'Natrag'
#      options[:t_enable] = 'Omogući'
#      options[:t_disable] = 'Onemogući'
#      options[:t_up] = 'Gore'
#      options[:t_down] = 'Dolje'
#      options[:t_show] = 'Detaljnije'
#      options[:t_edit] = 'Izmijeni'
#      options[:t_destroy] = 'Obriši'
#      options[:t_are_you_sure] = 'Da li ste sigurni?'
#    else
#      options[:t_was_successfully_updated] = 'was successfully updated.'
#      options[:t_success_fully_createed] = 'was successfully created.'
#      options[:t_save] = '<em>S</em>ave'
#      options[:t_save_and_add_new] = 'Save and add new'
#      options[:t_editing] = 'Editing'
#      options[:t_new] = 'New'
#      options[:t_listing] = 'Listing'
#      options[:t_back] = 'Back'
#      options[:t_enable] = 'Enable'
#      options[:t_disable] = 'Disable'
#      options[:t_up] = 'Up'
#      options[:t_down] = 'Down'
#      options[:t_show] = 'Show'
#      options[:t_edit] = 'Edit'
#      options[:t_destroy] = 'Destroy'
#      options[:t_are_you_sure] = 'Are you sure?'
#    end

#    @controller_name = @name.pluralize

#    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
#    @controller_class_name_without_nesting, @controller_underscore_name, @controller_plural_name = inflect_names(base_name)
#    @controller_singular_name=base_name.singularize
#    if @controller_class_nesting.empty?
#      @controller_class_name = @controller_class_name_without_nesting
#    else
#      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
#    end
#  end

#  def manifest
#    record do |m|
#      # Check for class naming collisions.
#      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
#      m.class_collisions(class_path, "#{class_name}")

#      # Controller, helper, views, test and stylesheets directories.
#      m.directory(File.join('app/models', class_path))
#      m.directory(File.join('app/controllers', controller_class_path))
#      m.directory(File.join('app/helpers', controller_class_path)) if options[:with_helper]
#      m.directory(File.join('app/views', controller_class_path, controller_file_name))
#      m.directory(File.join('test/functional', controller_class_path))
#      m.directory(File.join('test/unit', class_path))

#      for action in scaffold_views
#        m.template(
#          "view_#{action}.html.erb",
#          File.join('app/views', controller_class_path, controller_file_name, "#{action}.html.erb")
#        )
#      end

#      m.template(
#        'controller.rb', File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb")
#      )

#      m.template('functional_test.rb',File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))
#      m.template('helper.rb', File.join('app/helpers', controller_class_path, "#{controller_file_name}_helper.rb")) if options[:with_helper]
#
#      m.template('model.rb', File.join('app/models', class_path, "#{name}.rb"))
#
#      routing_options = ''
#      if (!options[:skip_search])
#        routing_options = ', :collection => { :search => :get }'
#      end
#      if (options[:is_toggable] && options[:has_position])
#        routing_options += ", :member => { :toggle_#{options[:toggable_attribute_name]} => :get, :move_up => :get, :move_down => :get }"
#      elsif (options[:has_position])
#        routing_options += ', :member => { :move_up => :get, :move_down => :get }'
#      elsif (options[:is_toggable])
#        routing_options += ", :member => { :toggle_#{options[:toggable_attribute_name]} => :get }"
#      end

#      #m.route_resources controller_file_name + routing_options
#      m.infinum_route_resources  ':' + controller_file_name + routing_options
#
#      m.dependency 'model', [name] + @args , :collision => :skip
#      puts "----------------------------------------------------------------"
#      puts "You should run 'rake db:migrate && rake controllers:update' after scaffold is finished"
#    puts "----------------------------------------------------------------"
#    end
#  end
#


#  protected
#    # Override with your own usage banner.
#    def banner
#      "Usage: #{$0} infinum_scaffold ModelName [field:type, field:type]"
#    end

#    def add_options!(opt)
#      opt.separator ''
#      opt.separator 'Options:'
#      opt.on("--skip-timestamps",
#             "Don't add timestamps to the migration file for this model") { |v| options[:skip_timestamps] = v }
#      opt.on("--skip-stampable",
#             "Don't add userstamps to the migration file for this model") { |v| options[:skip_stampabel] = v }
#      opt.on("--skip-migration",
#             "Don't generate a migration file for this model") { |v| options[:skip_migration] = v }
#      opt.on("--skip-sorting",
#             "Don't generate a sorting for table columns") { |v| options[:skip_sorting] = v }
#      opt.on("--skip-search",
#             "Skip search action for the controller") { |v| options[:skip_search] = v }
#      opt.on("--ignore-position",
#             "By default models that have attribute named :position are treated as sortable using acts_as_list") { |v| options[:ignore_position] = v } #TODO
#      opt.on("--ignore-toggable",
#             "By default boolean fields are treated as toggable fields") { |v| options[:ignore_toggable] = v }
#      opt.on("--with-enumerate",
#             "Generate a row number for each row in table") { |v| options[:enumerate] = v }
#      opt.on("--with-helper",
#             "Generate a helper (by default helper is skipped)") { |v| options[:with_helper] = v }
#      opt.on("--lang-croatian",
#             "Set language to Croatian") { |v| options[:lang_croatian] = v }
#      opt.on("--lang-gender-male",
#             "Set gender to male for Croatian langauge") { |v| options[:lang_gender_male] = v }
#    end
#

#    def scaffold_views
#      %w[ index show new edit _input ]
#    end

#    def model_name
#      class_name.demodulize
#    end
#end

require 'fileutils'
module Rails
	module Generator
	  module Commands
	    class Create < Base
	      def infinum_route_resources(resource_list)
          sentinel = 'ActionController::Routing::Routes.draw do |map|'
          logger.route "map.resources :#{resource_list}"

          unless options[:pretend]
           gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
             "#{match}\n  map.resources :#{resource_list}\n"
            end
          end
        end
      end
    end
  end
end

