module Redcar
  class ApplicationSWT
    class Speedbar
      attr_reader :widget
      
      def initialize(window, parent, model)
        @window_model = window
        @parent = parent
        @model = model
        create_widgets
        attach_key_listeners
        disable_menu_items
        if widget = focussable_widgets.first
          widget.set_focus
        end
      end
      
      def close
        @composite.dispose
        @parent.layout
      end
      
      def disable_menu_items
        key_strings = []
        @model.__items.each do |i|
          if i.respond_to?(:key)
            key_strings << i.key
          end
        end
        key_strings.uniq.each do |key_string|
          ApplicationSWT::Menu.disable_items(key_string)
        end
      end
      
      def num_columns
        @model.__items.select {|i| !i.is_a?(Redcar::Speedbar::KeyItem) }.length
      end
      
      def key_items
        @model.__items.select {|i| i.respond_to?(:key) }
      end
      
      def keyable_widgets
        @keyable_widgets ||= []
      end
      
      def focussable_widgets
        @focussable_widgets ||= []
      end
      
      def create_widgets
        @composite = Swt::Widgets::Composite.new(@parent, Swt::SWT::NONE)
        grid_data = Swt::Layout::GridData.new
        grid_data.grabExcessHorizontalSpace = true
        grid_data.horizontalAlignment = Swt::Layout::GridData::FILL
      	@composite.setLayoutData(grid_data)
        layout = Swt::Layout::GridLayout.new(num_columns + 1, false)
        layout.verticalSpacing = 0
        layout.marginHeight = 0
        @composite.setLayout(layout)
        image = Swt::Graphics::Image.new(ApplicationSWT.display, Redcar::Speedbar.close_image_path)
        label = Swt::Widgets::Label.new(@composite, 0)
        label.set_image(image)
	
	    label.add_mouse_listener(MouseListener.new(self))
	
        @model.__items.each do |item|
          case item
          when Redcar::Speedbar::LabelItem
            label = Swt::Widgets::Label.new(@composite, 0)
            label.set_text(item.text)
          when Redcar::Speedbar::TextBoxItem
            edit_view = EditView.new
            edit_view_swt = EditViewSWT.new(edit_view, @composite, :single_line => true)
            mate_text = edit_view_swt.mate_text
            mate_text.set_font(EditView.font, EditView.font_size)
            mate_text.getControl.set_text(item.value)
            mate_text.set_grammar_by_name "Ruby"
            mate_text.set_theme_by_name(EditView.theme)
            mate_text.set_root_scope_by_content_name("Ruby", "string.regexp.classic.ruby")
            gridData = Swt::Layout::GridData.new
            gridData.grabExcessHorizontalSpace = true
            gridData.horizontalAlignment = Swt::Layout::GridData::FILL
            mate_text.getControl.set_layout_data(gridData)
            mate_text.getControl.add_modify_listener do
              item.value = mate_text.getControl.get_text
              if item.listener
                begin
                  @model.__context.instance_exec(item.value, &item.listener)
                rescue => err
                  error_in_listener(err)
                end
              end
            end
            keyable_widgets << mate_text.getControl
            focussable_widgets << mate_text.getControl
          when Redcar::Speedbar::ButtonItem
            button = Swt::Widgets::Button.new(@composite, 0)
            button.set_text(item.text)
            if item.listener
              button.add_selection_listener do
                begin
                  @model.__context.instance_exec(&item.listener)
                rescue => err
                  error_in_listener(err)
                end
              end
            end
            keyable_widgets << button
            focussable_widgets << button
          when Redcar::Speedbar::ToggleItem
            button = Swt::Widgets::Button.new(@composite, Swt::SWT::CHECK)
            button.set_text(item.text)
            button.add_selection_listener do
              item.value = button.get_selection
              if item.listener
                begin
                  @model.__context.instance_exec(item.value, &item.listener)
                rescue => err
                  error_in_listener(err)
                end
              end
            end
            keyable_widgets << button
            focussable_widgets << button
          end
        end
        @parent.layout
      end
      
      class KeyListener
        def initialize(speedbar)
          @speedbar = speedbar
        end
        
        def key_pressed(e)
        end
        
        def key_released(e)
          @speedbar.key_press(e)
        end
      end
      
      class MouseListener
        def initialize(speedbar)
          @speedbar = speedbar
        end
        
        def mouse_down(*_); end
        
        def mouse_up(*_)
          @speedbar.close_pressed
        end
        
        def mouse_double_click(*_); end
      end
      
      def attach_key_listeners
        keyable_widgets.each do |widget|
          widget.add_key_listener(KeyListener.new(self))
        end
      end
      
      def close_pressed
        @window_model.close_speedbar
      end
      
      def key_press(e)
        key_string = Menu::BindingTranslator.key_string(e)
        if key_string == "\e"
          @window_model.close_speedbar
          e.doit = false
        end
        key_items.each do |key_item|
          if Menu::BindingTranslator.matches?(key_string, key_item.key)
            e.doit = false
            begin
              @model.__context.instance_exec(&key_item.listener)
            rescue Object => err
              error_in_listener(err)
            end
          end
        end
      end
      
      def error_in_listener(e)
        puts "*** Error in speedbar listener: #{e.message}"
        puts e.backtrace.map {|l| "    " + l}
      end
    end
  end
end

