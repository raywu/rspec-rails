require 'rspec/rails/view_assigns'

module RSpec::Rails
  module ViewExampleGroup
    extend ActiveSupport::Concern
    include RSpec::Rails::RailsExampleGroup
    include ActionView::TestCase::Behavior
    include RSpec::Rails::ViewAssigns
    include RSpec::Rails::Matchers::RenderTemplate

    module ClassMethods
      def _default_helper
        base = metadata[:example_group][:description].split('/')[0..-2].join('/')
        (base.camelize + 'Helper').constantize if base
      rescue NameError
        nil
      end

      def _default_helpers
        helpers = [_default_helper].compact
        helpers << ApplicationHelper if Object.const_defined?('ApplicationHelper')
        helpers
      end
    end

    module ExampleMethods
      # @overload render
      # @overload render({:partial => path_to_file})
      # @overload render({:partial => path_to_file}, {... locals ...})
      # @overload render({:partial => path_to_file}, {... locals ...}) do ... end
      #
      # Delegates to ActionView::Base#render, so see documentation on that
      # for more info.
      #
      # The only addition is that you can call render with no arguments, and RSpec
      # will pass the top level description to render:
      #
      #     describe "widgets/new.html.erb" do
      #       it "shows all the widgets" do
      #         render # => view.render(:file => "widgets/new.html.erb")
      #         # ...
      #       end
      #     end
      def render(options={}, local_assigns={}, &block)
        options = {:template => _default_file_to_render} if Hash === options and options.empty?
        super(options, local_assigns, &block)
      end

      # The instance of `ActionView::Base` that is used to render the template.
      # Use this to stub methods _before_ calling `render`.
      #
      #     describe "widgets/new.html.erb" do
      #       it "shows all the widgets" do
      #         view.stub(:foo) { "foo" }
      #         render
      #         # ...
      #       end
      #     end
      def view
        _view
      end

      # Simulates the presence of a template on the file system by adding a
      # Rails' FixtureResolver to the front of the view_paths list. Designed to
      # help isolate view examples from partials rendered by the view template
      # that is the subject of the example.
      #
      # @example
      #
      #     stub_template("widgets/_widget.html.erb" => "This content.")
      def stub_template(hash)
        view.view_paths.unshift(ActionView::FixtureResolver.new(hash))
      end

      # Provides access to the params hash that will be available within the
      # view:
      #
      #     params[:foo] = 'bar'
      def params
        controller.params
      end

      # @deprecated Use `view` instead.
      def template
        RSpec.deprecate("template","view")
        view
      end

      # @deprecated Use `rendered` instead.
      def response
        RSpec.deprecate("response", "rendered")
        rendered
      end

    private

      def _default_file_to_render
        example.example_group.top_level_description
      end

      def _path_parts
        _default_file_to_render.split("/")
      end

      def _controller_path
        _path_parts[0..-2].join("/")
      end

      def _inferred_action
        _path_parts.last.split(".").first
      end

      def _include_controller_helpers
        helpers = controller._helpers
        view.singleton_class.class_eval do
          include helpers unless included_modules.include?(helpers)
        end
      end
    end

    included do
      include ExampleMethods

      metadata[:type] = :view
      helper(*_default_helpers)

      before do
        _include_controller_helpers
        if view.lookup_context.respond_to?(:prefixes)
          # rails 3.1
          view.lookup_context.prefixes << _controller_path
        else
          # rails 3.0
          controller.controller_path = _controller_path
        end
        controller.request.path_parameters["controller"] = _controller_path
        controller.request.path_parameters["action"]     = _inferred_action unless _inferred_action =~ /^_/
      end
    end
  end
end

