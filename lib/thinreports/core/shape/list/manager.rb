# coding: utf-8

module ThinReports
  module Core::Shape
    
    # @private
    class List::Manager
      attr_reader :config
      
      # @return [ThinReports::Core::Shape:::List::Page]
      attr_reader :current_page
      
      # @return [ThinReports::Core::Shape::List::PageState]
      attr_reader :current_page_state
      
      # @param [ThinReports::Core::Shape::List::Page] page
      def initialize(page)
        switch_current!(page)

        @config    = init_config
        @finalized = false
      end
      
      # @param [ThinReports::Core::Shape::List::Page] page
      # @return [ThinReports::Core::Shape::List::Manager]
      def switch_current!(page)
        @current_page       = page
        @current_page_state = page.internal
        self
      end
      
      # @yield [new_list]
      # @yieldparam [ThinReports::Core::Shape::List::Page] new_list
      def change_new_page(&block)
        finalize_page
        new_page = report.internal.copy_page
        
        if block_given?
          block.call(new_page.list(current_page.id))
        end
      end
      
      # @see List::Page#header
      def header(values = {}, &block)
        unless format.has_header?
          raise ThinReports::Errors::DisabledListSection, 'header'
        end        
        current_page_state.header ||= init_section(:header)
        build_section(current_page_state.header, values, &block)
      end
      
      # @param (see #build_section)
      # @return [Boolean]
      def insert_new_detail(values = {}, &block)
        return false if current_page_state.finalized?
        
        successful = true
        
        if overflow_with?(:detail)
          if auto_page_break?
            change_new_page do |new_list|
              new_list.manager.insert_new_row(:detail, values, &block)
            end
          else
            finalize
            successful = false
          end
        else
          insert_new_row(:detail, values, &block)
        end
        successful
      end
      
      # @see #build_section
      def insert_new_row(section_name, values = {}, &block)
        row = build_section(init_section(section_name), values, &block)
        row.internal.move_top_to(current_page_state.height)
        
        current_page_state.rows << row
        current_page_state.height += row.height
        row
      end
      
      # @param [ThinReports::Core::Shape::List::SectionInterface] section
      # @param values (see ThinReports::Core::Shape::Manager::Target#values)
      # @yield [section,]
      # @yieldparam [ThinReports::Core::Shape::List::SectionInterface] section
      # @return [ThinReports::Core::Shape::List::SectionInterface]
      def build_section(section, values = {}, &block)
        section.values(values)
        block_exec_on(section, &block)
      end
      
      # @param [Symbol] section_name
      # @return [ThinReports::Core::Shape::List::SectionInterface]
      def init_section(section_name)
        List::SectionInterface.new(current_page,
                                   format.sections[section_name],
                                   section_name)
      end      
      
      # @param [Symbol] section_name
      # @return [Boolean]
      def overflow_with?(section_name = :detail)
        height = format.section_height(section_name)
        current_page_state.height + height > page_max_height
      end
      
      # @return [Numeric]
      def page_max_height
        unless @page_max_height
          h  = format.height
          h -= format.section_height(:page_footer)
          h -= format.section_height(:footer) unless auto_page_break?
          @page_max_height = h
        end
        @page_max_height
      end
      
      def store
        config.store
      end
      
      def events
        config.events
      end
      
      def auto_page_break?
        format.auto_page_break?
      end
      
      # @private
      def finalize_page        
        return if current_page_state.finalized?
        
        if format.has_header?
          current_page_state.header ||= init_section(:header)
        end
        
        if format.has_page_footer?
          footer = insert_new_row(:page_footer)
          # Dispatch event on footer insert.
          events.
            dispatch(List::Events::SectionEvent.new(:page_footer_insert,
                                                    footer, store))
        end
        current_page_state.finalized!
      end      
      
      # @private
      def finalize
        return if finalized?
        
        finalize_page
        
        if format.has_footer?
          footer = nil
          
          if auto_page_break? && overflow_with?(:footer)
            change_new_page do |new_list|
              footer = new_list.internal.insert_new_row(:footer)
            end
          else
            footer = insert_new_row(:footer)
          end
          # Dispatch event on footer insert.
          events.dispatch(List::Events::SectionEvent.new(:footer_insert,
                                                         footer, store))
        end
        @finalized = true
      end
      
      # @private
      def finalized?
        @finalized
      end      
      
    private
      
      # @return [ThinReports::Report::Base]
      # @private
      def report
        current_page_state.parent.report
      end
      
      # @return [ThinReports::Layout::Base]
      # @private
      def layout
        current_page_state.parent.layout
      end
      
      # @return [ThinReports::Core::Shape::List::Format]
      # @private
      def format
        current_page_state.format
      end
      
      # @private
      def init_config
        layout.config.activate(current_page.id) || List::Configuration.new
      end
    end
    
  end
end