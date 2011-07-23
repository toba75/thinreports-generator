# coding: utf-8

module ThinReports
  module Generator
    
    module Pdf::Graphics
      # @param [String] content
      # @param [Numeric, String] x
      # @param [Numeric, String] y
      # @param [Numeric, String] w
      # @param [Numeric, String] h
      # @param [Hash] attrs ({})
      # @option attrs [String] :font
      # @option attrs [Numeric, String] :size
      # @option attrs [String] :color
      # @option attrs [Array<:bold, :italic, :underline, :strikethrough>]
      #   :styles (nil)
      # @option attrs [:left, :center, :right] :align (:left)
      # @option attrs [:top, :center, :bottom] :valign (:top)
      # @option attrs [Numeric, String] :line_height The total height of an text line.
      # @option attrs [Numeric, String] :letter_spacing
      def text_box(content, x, y, w, h, attrs = {})
        w, h = s2f(w, h)
        with_text_styles(attrs) do |built_attrs, font_styles|
          pdf.formatted_text_box([{:text   => text_without_line_wrap(content),
                                   :styles => font_styles}],
                                 built_attrs.merge(:at     => pos(x, y),
                                                   :width  => w,
                                                   :height => h))
        end
      end
      
      # @see #text_box
      def text(content, x, y, w, h, attrs = {})
        # Set the :overflow property to :shirink_to_fit.
        text_box(content, x, y, w, h, attrs.merge(:overflow => :shrink_to_fit))
      end
      
    private
      
      # @param attrs (see #text)
      # @yield [built_attrs, font_styles]
      # @yieldparam [Hash] built_attrs The finalized attributes.
      # @yieldparam [Array] font_styles The finalized styles.
      def with_text_styles(attrs, &block)
        save_graphics_state
        
        fontinfo = {:name  => attrs.delete(:font).to_s, 
                    :color => parse_color(attrs.delete(:color)),
                    :size  => s2f(attrs.delete(:size))}
        
        # Add the specified value to :leading option.
        if line_height = attrs.delete(:line_height)
          attrs[:leading] = text_line_leading(s2f(line_height),
                                              :name => fontinfo[:name],
                                              :size => fontinfo[:size])
        end
        
        # Set the :character_spacing option.
        if space = attrs.delete(:letter_spacing)
          attrs[:character_spacing] = s2f(space)
        end
        
        # Or... with_font_styles(attrs, fontinfo, &block)
        with_font_styles(attrs, fontinfo) do |modified_attrs, styles|
          block.call(modified_attrs, styles)
        end
        
        restore_graphics_state
      end
      
      # @param [Numeric] line_height
      # @param [Hash] font
      # @option font [String] :name Name of font.
      # @option font [Numeric] :size Size of font.
      # @return [Numeric]
      def text_line_leading(line_height, font)
        line_height - pdf.font(font[:name], :size => font[:size]).height
      end
      
      # @param [String] content
      # @return [String]
      def text_without_line_wrap(content)
        content.gsub(/ /, Prawn::Text::NBSP)
      end
      
      # @param [Hash] attrs
      # @param [Hash] font
      # @option font [String] :color
      # @option font [Numeric] :size
      # @option font [String] :name
      # @yield [attributes, styles]
      # @yieldparam [Hash] modified_attrs
      # @yieldparam [Array] styles
      def with_font_styles(attrs, font, &block)
        # Building font styles.
        if styles = attrs.delete(:styles)
          manual, styles = styles.partition do |style|
            [:bold, :italic].include?(style) && !font_has_style?(font[:name], style)
          end
        end
        
        # Emulate bold style.
        if manual.include?(:bold)
          pdf.stroke_color(font[:color])
          pdf.line_width(font[:size] * 0.025)
          
          # Change rendering mode to :fill_stroke.
          attrs[:mode] = :fill_stroke
        end
        
        # Emulate italic style.
        if manual.include?(:italic)
          # FIXME
          # pdf.transformation_matrix(1, 0, 0.26, 1, 0, 0)
        end
        
        pdf.font(font[:name], :size => font[:size]) do
          pdf.fill_color(font[:color])
          block.call(attrs, styles || [])
        end
      end      
      
    end
    
  end
end